import Foundation
import Vision
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The structured result of scanning a wine label.
struct WineLabelExtraction: Sendable {
    var producer: String?
    var name: String?
    var vintage: Int?

    /// Raw OCR lines, most prominent first — used as an editable fallback query
    /// and shown to the user when confident extraction fails.
    var rawLines: [String]

    /// False when neither a producer nor a wine name could be identified with
    /// reasonable confidence. Drives the "couldn't identify" warning in the UI.
    var isConfident: Bool

    /// A search query built from the best available fields, falling back to the
    /// joined raw OCR text.
    var searchQuery: String {
        let parts = [producer, name].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }
        return rawLines.prefix(2).joined(separator: " ")
    }
}

/// Scans a wine-bottle photo: on-device OCR (Vision) followed by an on-device
/// parse (Foundation Models on iOS 26+, heuristic otherwise). Fully offline,
/// no network, no third-party API.
enum WineLabelScanner {

    enum ScanError: Error {
        case invalidImage
        case noTextFound
    }

    /// Runs the full pipeline: OCR then parse.
    static func scan(_ image: UIImage) async throws -> WineLabelExtraction {
        let lines = try await recognizeText(in: image)
        guard !lines.isEmpty else { throw ScanError.noTextFound }
        return await parse(lines: lines)
    }

    // MARK: - OCR (Vision, iOS 18+)

    /// Extracts text lines from the image, ordered by prominence
    /// (larger + higher-confidence lines first).
    static func recognizeText(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw ScanError.invalidImage }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = recognitionLanguages()

        let observations = try await request.perform(on: cgImage)

        // Sort by a prominence score: taller boxes (bigger text) first, then
        // by vertical position (top of label first), then confidence.
        let scored = observations.compactMap { obs -> (text: String, score: Double)? in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 2 else { return nil }
            let box = obs.boundingBox.cgRect
            let height = Double(box.height)
            let top = Double(box.origin.y) // normalized; higher y = higher on label
            let score = height * 2.0 + top + Double(candidate.confidence) * 0.1
            return (text, score)
        }
        return scored.sorted { $0.score > $1.score }.map(\.text)
    }

    private static func recognitionLanguages() -> [Locale.Language] {
        var langs = ["en-US", "fr-FR", "it-IT", "es-ES", "de-DE", "pt-PT"]
        if let device = Locale.current.language.languageCode?.identifier,
           !langs.contains(where: { $0.hasPrefix(device) }) {
            langs.insert(device, at: 0)
        }
        return langs.map { Locale.Language(identifier: $0) }
    }

    // MARK: - Parse

    static func parse(lines: [String]) async -> WineLabelExtraction {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), SystemLanguageModel.default.isAvailable {
            if let llm = try? await parseWithModel(lines: lines) {
                return llm
            }
            // Model available but generation failed — fall through to heuristic.
        }
        #endif
        return heuristicParse(lines: lines)
    }

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private static func parseWithModel(lines: [String]) async throws -> WineLabelExtraction {
        let model = SystemLanguageModel(useCase: .contentTagging, guardrails: .default)
        let session = LanguageModelSession(model: model) {
            "You extract structured wine information from OCR text read off a wine bottle label."
            "The lines may be noisy, out of order, and in multiple languages."
            "Identify the producer (winery/estate/maison), the wine name or cuvée, and the vintage year if present."
            "Return null for any field you cannot determine with confidence. Do not guess."
        }

        let prompt = "OCR lines from a wine label, most prominent first:\n" +
            lines.prefix(20).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let response = try await session.respond(to: prompt, generating: LabelFields.self)
        let f = response.content

        let producer = f.producer?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let name = f.wineName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let vintage = f.vintage.flatMap { ($0 >= 1900 && $0 <= 2100) ? $0 : nil }

        return WineLabelExtraction(
            producer: producer,
            name: name,
            vintage: vintage,
            rawLines: lines,
            isConfident: producer != nil || name != nil
        )
    }

    @available(iOS 26, *)
    @Generable
    struct LabelFields {
        @Guide(description: "The producer: winery, estate, domaine, or maison name. Null if unknown.")
        var producer: String?

        @Guide(description: "The wine name or cuvée (not the producer, region, or grape). Null if unknown.")
        var wineName: String?

        @Guide(description: "The 4-digit vintage year printed on the label, if any. Null if unknown.")
        var vintage: Int?
    }
    #endif

    // MARK: - Heuristic fallback (iOS 18–25 / Apple Intelligence unavailable)

    private static let vintageRegex = try! NSRegularExpression(pattern: "\\b(19|20)\\d{2}\\b")

    /// Lines that are almost never the producer or wine name.
    private static let noisePatterns: [NSRegularExpression] = [
        "\\b\\d{1,2}([.,]\\d)?\\s?%",          // alcohol %
        "\\b\\d{2,4}\\s?(ml|cl|l)\\b",          // volume
        "mis en bouteille",                      // bottled at…
        "produce of|product of|produit",         // origin boilerplate
        "contains sulfites|contient des sulfites",
        "appellation.*contr",                     // AOC line
    ].map { try! NSRegularExpression(pattern: $0, options: .caseInsensitive) }

    static func heuristicParse(lines: [String]) -> WineLabelExtraction {
        var vintage: Int?
        for line in lines {
            if let m = vintageRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let r = Range(m.range, in: line), let y = Int(line[r]) {
                vintage = y
                break
            }
        }

        // Candidate name/producer lines = prominent lines that aren't noise and
        // aren't a bare vintage.
        let candidates = lines.filter { line in
            let range = NSRange(line.startIndex..., in: line)
            if noisePatterns.contains(where: { $0.firstMatch(in: line, range: range) != nil }) {
                return false
            }
            let stripped = vintageRegex.stringByReplacingMatches(in: line, range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
            return stripped.count >= 3
        }

        let name = candidates.first
        let producer = candidates.dropFirst().first

        return WineLabelExtraction(
            producer: producer,
            name: name,
            vintage: vintage,
            rawLines: lines,
            isConfident: name != nil  // heuristic is never highly confident about the split
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
