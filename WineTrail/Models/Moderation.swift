import Foundation

/// The kind of content a report targets.
enum ReportedContentType: String, CaseIterable, Sendable {
    case journalEntry = "JOURNAL_ENTRY"
    case comment = "COMMENT"
    case user = "USER"
}

/// Reason categories a user can choose when reporting content.
///
/// These map to the `reason` enum in the moderation API. The order here is the
/// order shown in the report sheet.
enum ReportReason: String, CaseIterable, Identifiable, Sendable {
    case harassment = "HARASSMENT"
    case hateSpeech = "HATE_SPEECH"
    case sexualContent = "SEXUAL_CONTENT"
    case violence = "VIOLENCE"
    case spam = "SPAM"
    case other = "OTHER"

    var id: String { rawValue }

    /// Human-readable label shown in the report UI.
    var label: String {
        switch self {
        case .harassment: return "Harassment or bullying"
        case .hateSpeech: return "Hate speech"
        case .sexualContent: return "Nudity or sexual content"
        case .violence: return "Violence or threats"
        case .spam: return "Spam or misleading"
        case .other: return "Something else"
        }
    }
}

/// A target the user has chosen to report, carrying the identifiers the
/// moderation API needs.
struct ReportTarget: Identifiable, Equatable {
    let contentType: ReportedContentType
    /// ID of the reported entity (journal entry id, comment id, or user id).
    let contentId: String
    /// ID of the user who authored the reported content, if known.
    let authorUserId: String?
    /// Display name / username shown to the reporter for confirmation.
    let authorName: String?

    var id: String { "\(contentType.rawValue):\(contentId)" }
}
