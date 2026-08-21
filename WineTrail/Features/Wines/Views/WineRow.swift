import SwiftUI

/// A compact row view displaying a wine's key stats for the wines list.
///
/// Shows the wine color indicator, name, producer, vintage, times drunk count,
/// and average rating in a layout designed for List rows.
struct WineRow: View {
    let wine: WineStats

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wineglass.fill")
                .font(.title3)
                .foregroundStyle(wine.color?.accentColor ?? .wineAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(wine.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let producer = wine.producer {
                        Text(producer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                RatingView(rating: wine.averageRating)

                HStack(spacing: 2) {
                    Image(systemName: "wineglass")
                    Text("\(wine.timesDrunk)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [wine.name]
        if let producer = wine.producer { parts.append(producer) }
        if let color = wine.color { parts.append("\(color.displayName) wine") }
        parts.append("tasted \(wine.timesDrunk) times")
        parts.append("average rating \(Int(wine.averageRating.rounded())) out of 10")
        return parts.joined(separator: ", ")
    }
}


#Preview {
    List {
        WineRow(wine: Components.Schemas.WineWithStats(
            id: "wine-1",
            name: "Barolo DOCG 2018",
            producer: "Marchesi di Barolo",
            regionName: "Barolo",
            color: .RED,
            timesDrunk: 5,
            averageRating: 4.2,
            firstTasted: "2025-03-15",
            lastTasted: "2026-08-10"
        ))
        WineRow(wine: Components.Schemas.WineWithStats(
            id: "wine-2",
            name: "Sancerre 2022",
            producer: "Domaine Vacheron",
            regionName: "Loire",
            color: .WHITE,
            timesDrunk: 2,
            averageRating: 3.5,
            firstTasted: "2026-06-01",
            lastTasted: "2026-07-20"
        ))
        WineRow(wine: Components.Schemas.WineWithStats(
            id: "wine-3",
            name: "Whispering Angel 2023",
            producer: "Château d'Esclans",
            regionName: "Provence",
            color: .ROSE,
            timesDrunk: 8,
            averageRating: 3.0,
            firstTasted: "2024-06-15",
            lastTasted: "2026-08-18"
        ))
    }
}
