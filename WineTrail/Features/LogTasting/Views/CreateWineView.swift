import SwiftUI

/// Inline form for creating a user-defined wine when no search results match.
///
/// Name is required; producer, region, country, color, and vintage are optional.
/// On save, calls `WineService.createWine()` and converts the result to a
/// `WineSearch` for selection in the parent flow.
struct CreateWineView: View {
    @Environment(WineService.self) private var wineService
    @Environment(\.dismiss) private var dismiss

    /// Binding to the selected wine — set on successful creation.
    @Binding var selectedWine: WineSearch?

    // MARK: - Form State

    @State private var name = ""
    @State private var producer = ""
    @State private var region = ""
    @State private var country = ""
    @State private var color: Components.Schemas.WineColor = .RED
    @State private var vintageText = ""
    @State private var isSaving = false
    @State private var error: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        Form {
            Section("Wine Details") {
                TextField("Name *", text: $name)
                    .accessibilityLabel("Wine name, required")

                TextField("Producer", text: $producer)

                TextField("Region", text: $region)

                TextField("Country", text: $country)
            }

            Section("Classification") {
                Picker("Color", selection: $color) {
                    Text("Red").tag(Components.Schemas.WineColor.RED)
                    Text("White").tag(Components.Schemas.WineColor.WHITE)
                    Text("Rosé").tag(Components.Schemas.WineColor.ROSE)
                    Text("Orange").tag(Components.Schemas.WineColor.ORANGE)
                    Text("Sparkling").tag(Components.Schemas.WineColor.SPARKLING)
                }
                .pickerStyle(.menu)

                TextField("Vintage (year)", text: $vintageText)
                    .keyboardType(.numberPad)
            }

            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(Theme.captionFont)
                }
            }
        }
        .navigationTitle("Create Wine")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await createWine() }
                }
                .disabled(!canSave)
            }
        }
    }

    // MARK: - Save Logic

    private func createWine() async {
        guard canSave else { return }
        isSaving = true
        error = nil

        let vintage: Int32? = Int32(vintageText)

        let request = Components.Schemas.CreateWineRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            producer: producer.isEmpty ? nil : producer,
            regionName: region.isEmpty ? nil : region,
            country: country.isEmpty ? nil : country,
            color: color,
            vintage: vintage,
            grapeVarieties: nil
        )

        do {
            let wine = try await wineService.createWine(request)

            // Convert the created WineDto to a WineSearch for compatibility with the LogTasting flow
            let wineSearch = Components.Schemas.WineSearchDto(
                externalSource: wine.externalSource,
                externalId: wine.externalId,
                name: wine.name,
                producer: wine.producer,
                region: wine.regionName,
                country: wine.country,
                color: wine.color,
                vintage: wine.vintage
            )
            selectedWine = wineSearch
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

#Preview {
    NavigationStack {
        CreateWineView(selectedWine: .constant(nil))
            .environment(WineService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
