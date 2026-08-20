import SwiftUI
import OpenAPIRuntime

/// Edit an existing tasting entry.
///
/// Presents a form pre-filled with the tasting's current data. On save, sends an
/// `UpdateTastingRequest` via `TastingService.updateTasting()` and dismisses.
struct EditTastingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TastingService.self) private var tastingService

    let tasting: Tasting

    // MARK: - Form State

    @State private var rating: Int
    @State private var notes: String
    @State private var foodPairing: String
    @State private var occasion: String
    @State private var price: String
    @State private var locationName: String
    @State private var tastingDate: Date

    @State private var isSaving = false
    @State private var error: String?

    // MARK: - Initialization

    init(tasting: Tasting) {
        self.tasting = tasting
        _rating = State(initialValue: Int(tasting.rating))
        _notes = State(initialValue: tasting.notes ?? "")
        _foodPairing = State(initialValue: tasting.foodPairing ?? "")
        _occasion = State(initialValue: tasting.occasion ?? "")
        _price = State(initialValue: tasting.price ?? "")
        _locationName = State(initialValue: tasting.location?.locationName ?? "")
        _tastingDate = State(initialValue: Self.parseDate(tasting.tastingDate) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                wineSection
                ratingSection
                detailsSection
                locationSection
                errorSection
            }
            .navigationTitle("Edit Tasting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    // MARK: - Wine Section (Read-Only)

    @ViewBuilder
    private var wineSection: some View {
        Section("Wine") {
            HStack(spacing: Theme.smallSpacing) {
                if let color = tasting.wine.color {
                    WineColorIndicator(color: color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(tasting.wine.name)
                        .font(Theme.headlineFont)
                    if let producer = tasting.wine.producer, !producer.isEmpty {
                        Text(producer)
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Rating Section

    @ViewBuilder
    private var ratingSection: some View {
        Section("Rating") {
            HStack {
                Text("\(rating)")
                    .font(Theme.titleFont)
                    .foregroundStyle(.wineAccent)
                    .frame(minWidth: 30)
                Slider(
                    value: Binding(
                        get: { Double(rating) },
                        set: { rating = Int($0) }
                    ),
                    in: 1...10,
                    step: 1
                )
                .tint(.wineAccent)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Rating: \(rating) out of 10")
            .accessibilityValue("\(rating)")
        }
    }

    // MARK: - Details Section

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            TextField("Tasting notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
            TextField("Food pairing", text: $foodPairing)
            TextField("Occasion", text: $occasion)
            TextField("Price", text: $price)
                .keyboardType(.decimalPad)
            DatePicker("Date", selection: $tastingDate, displayedComponents: .date)
        }
    }

    // MARK: - Location Section

    @ViewBuilder
    private var locationSection: some View {
        Section("Location") {
            TextField("Location name", text: $locationName)
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let error {
            Section {
                Text(error)
                    .foregroundStyle(.red)
                    .font(Theme.captionFont)
            }
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        error = nil

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let request = Components.Schemas.UpdateTastingRequest(
            rating: Int32(rating),
            notes: notes.isEmpty ? nil : notes,
            foodPairing: foodPairing.isEmpty ? nil : foodPairing,
            occasion: occasion.isEmpty ? nil : occasion,
            price: price.isEmpty ? nil : price,
            latitude: tasting.location?.latitude,
            longitude: tasting.location?.longitude,
            locationName: locationName.isEmpty ? nil : locationName,
            tastingDate: dateFormatter.string(from: tastingDate)
        )

        do {
            _ = try await tastingService.updateTasting(id: tasting.id, request)
            dismiss()
        } catch {
            print("[EditTasting] Failed to update tasting: \(error)")
            self.error = "Something went wrong. Please try again."
        }

        isSaving = false
    }

    // MARK: - Helpers

    private static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }
}
