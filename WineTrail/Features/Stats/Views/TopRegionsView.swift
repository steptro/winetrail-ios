import SwiftUI

/// A ranked list of the user's top wine regions by tasting count.
///
/// Displays up to 10 regions with their rank number and tasting count,
/// providing a quick overview of geographic preferences.
struct TopRegionsView: View {
    let regions: [Components.Schemas.RegionCount]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Text("Top Regions")
                .font(Theme.headlineFont)
                .foregroundStyle(.wineText)

            if regions.isEmpty {
                Text("No region data available")
                    .font(Theme.captionFont)
                    .foregroundStyle(.wineSecondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(regions.enumerated()), id: \.offset) { index, region in
                        regionRow(rank: index + 1, region: region)
                        if index < regions.count - 1 {
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
    private func regionRow(rank: Int, region: Components.Schemas.RegionCount) -> some View {
        HStack(spacing: Theme.smallSpacing) {
            Text("\(rank)")
                .font(Theme.captionFont)
                .fontWeight(.bold)
                .foregroundStyle(.wineAccent)
                .frame(width: 24)

            Text(region.regionName ?? "")
                .font(Theme.bodyFont)
                .foregroundStyle(.wineText)
                .lineLimit(1)

            Spacer()

            Text("\(region.count ?? 0)")
                .font(Theme.subheadlineFont)
                .fontWeight(.medium)
                .foregroundStyle(.wineSecondaryText)

            Text((region.count ?? 0) == 1 ? "tasting" : "tastings")
                .font(Theme.captionFont)
                .foregroundStyle(.wineSecondaryText)
        }
        .padding(.vertical, Theme.smallSpacing)
    }
}

#Preview {
    TopRegionsView(regions: [])
    .padding()
}
