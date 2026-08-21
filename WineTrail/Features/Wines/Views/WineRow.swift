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
