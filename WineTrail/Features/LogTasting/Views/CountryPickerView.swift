import SwiftUI

/// A searchable country picker that presents ISO 3166-1 countries in a list.
/// Displays localized country names with flag emoji.
struct CountryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: String?
    @State private var searchText = ""

    private var countries: [(code: String, name: String)] {
        Locale.Region.isoRegions
            .map(\.identifier)
            .filter { $0.count == 2 }
            .compactMap { code in
                guard let name = Locale.current.localizedString(forRegionCode: code) else {
                    return nil
                }
                return (code: code, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredCountries: [(code: String, name: String)] {
        if searchText.isEmpty {
            return countries
        }
        return countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if selected != nil {
                    Button {
                        selected = nil
                        dismiss()
                    } label: {
                        Text("None")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(filteredCountries, id: \.code) { country in
                    Button {
                        selected = country.code
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(flag(for: country.code))
                                .font(.title2)
                            Text(country.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selected == country.code {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.wineAccent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search countries")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// Converts an ISO 3166-1 alpha-2 code to its flag emoji.
    private func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}

#Preview {
    CountryPickerView(selected: .constant("FR"))
}
