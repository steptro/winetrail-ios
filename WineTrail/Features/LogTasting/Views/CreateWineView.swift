import SwiftUI

/// Inline form for creating a user-defined wine when no search results match.
///
/// Name is required; producer, region, country, and color are optional.
/// On save, calls `WineService.createWine()` and converts the result to a
/// `WineSearch` for selection in the parent flow.
struct CreateWineView: View {
    @Environment(WineService.self) private var wineService
    @Environment(\.dismiss) private var dismiss

    /// Binding to the selected wine — set on successful creation.
    @Binding var selectedWine: WineSearch?

    /// Binding to the wine ID for user-created wines.
    @Binding var selectedWineId: String?

    // MARK: - Form State

    @State private var name = ""
    @State private var producer = ""
    @State private var region = ""
    @State private var country: String? = nil
    @State private var color: Components.Schemas.WineColor? = nil
    @State private var isSaving = false
    @State private var error: String?
    @State private var showCountryPicker = false

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

                Button {
                    showCountryPicker = true
                } label: {
                    HStack {
                        Text("Country")
                            .foregroundStyle(.primary)
                        Spacer()
                        if let country {
                            Text(Locale.current.localizedString(forRegionCode: country) ?? country)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Select")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Section("Classification") {
                WineColorPills(selected: $color)
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
                Button {
                    Task { await createWine() }
                } label: {
                    Image(systemName: "checkmark")
                }
                .disabled(!canSave)
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selected: $country)
        }
    }

    // MARK: - Save Logic

    private func createWine() async {
        guard canSave else { return }
        isSaving = true
        error = nil

        let request = Components.Schemas.CreateWineRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            producer: producer.isEmpty ? nil : producer,
            regionName: region.isEmpty ? nil : region,
            country: country,
            color: color,
            grapeVarieties: nil
        )

        do {
            let wine = try await wineService.createWine(request)

            // Convert the created WineDto to a WineSearch for compatibility with the LogTasting flow.
            // Store the wine ID so it can be used as wineId when creating a tasting.
            // For user-created wines, externalSource is nil; we store the wine UUID in wineId.
            let wineSearch = Components.Schemas.WineSearchDto(
                wineId: wine.id,
                externalSource: wine.externalSource,
                externalId: wine.externalId,
                name: wine.name,
                producer: wine.producer,
                region: wine.regionName,
                country: wine.country,
                color: wine.color
            )
            selectedWine = wineSearch
            selectedWineId = wine.id
            dismiss()
        } catch {
            print("[CreateWineView] Failed to create wine: \(error)")
            self.error = "Something went wrong. Please try again."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        isSaving = false
    }
}

#Preview {
    NavigationStack {
        CreateWineView(selectedWine: .constant(nil), selectedWineId: .constant(nil))
            .environment(WineService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
