import SwiftUI

/// A ranked list of the user's top wine countries by tasting count.
///
/// Displays up to 10 countries with their flag, name, rank, and tasting count.
struct TopCountriesView: View {
    let countries: [Components.Schemas.CountryCount]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Text("Top Countries")
                .font(Theme.headlineFont)
                .foregroundStyle(.wineText)

            if countries.isEmpty {
                Text("No country data available")
                    .font(Theme.captionFont)
                    .foregroundStyle(.wineSecondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(countries.enumerated()), id: \.offset) { index, country in
                        countryRow(rank: index + 1, country: country)
                        if index < countries.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(Theme.spacing)
        .background(.wineSecondaryBackground, in: .rect(cornerRadius: Theme.cornerRadius))
    }

    @ViewBuilder
    private func countryRow(rank: Int, country: Components.Schemas.CountryCount) -> some View {
        HStack(spacing: Theme.smallSpacing) {
            Text("\(rank)")
                .font(Theme.captionFont)
                .fontWeight(.bold)
                .foregroundStyle(.wineAccent)
                .frame(width: 24)

            if let code = country.country {
                Text(flag(for: code))
                    .font(.title3)
            }

            Text(countryName(for: country.country))
                .font(Theme.bodyFont)
                .foregroundStyle(.wineText)
                .lineLimit(1)

            Spacer()

            Text("\(country.count ?? 0)")
                .font(Theme.subheadlineFont)
                .fontWeight(.medium)
                .foregroundStyle(.wineSecondaryText)

            Text((country.count ?? 0) == 1 ? "wine" : "wines")
                .font(Theme.captionFont)
                .foregroundStyle(.wineSecondaryText)
        }
        .padding(.vertical, Theme.smallSpacing)
    }

    private func countryName(for code: String?) -> String {
        guard let code else { return "Unknown" }
        return Locale.current.localizedString(forRegionCode: code) ?? code
    }

    private func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}

#Preview {
    TopCountriesView(countries: [])
        .padding()
}
