import SwiftUI
import Charts

/// A donut chart showing the distribution of wine colors in the user's tastings.
///
/// Maps the color split dictionary (e.g. `["RED": 10, "WHITE": 5]`) to a
/// sectored chart using Swift Charts, with each sector colored to match the wine type.
struct ColorSplitChart: View {
    let colorSplit: [String: Int]

    private var chartData: [ColorEntry] {
        colorSplit
            .filter { $0.value > 0 }
            .map { ColorEntry(color: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Text("Wine Colors")
                .font(Theme.headlineFont)
                .foregroundStyle(.wineText)

            if chartData.isEmpty {
                Text("No color data available")
                    .font(Theme.captionFont)
                    .foregroundStyle(.wineSecondaryText)
            } else {
                Chart(chartData) { entry in
                    SectorMark(
                        angle: .value("Count", entry.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(entry.chartColor)
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .chartBackground { _ in
                    VStack {
                        Text("\(totalCount)")
                            .font(Theme.headlineFont)
                            .foregroundStyle(.wineText)
                        Text("Tastings")
                            .font(Theme.captionFont)
                            .foregroundStyle(.wineSecondaryText)
                    }
                }

                // Legend
                legendView
            }
        }
        .padding(Theme.spacing)
        .background(.wineSecondaryBackground, in: .rect(cornerRadius: Theme.cornerRadius))
    }

    private var totalCount: Int {
        chartData.reduce(0) { $0 + $1.count }
    }

    @ViewBuilder
    private var legendView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: Theme.smallSpacing) {
            ForEach(chartData) { entry in
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.chartColor)
                        .frame(width: 10, height: 10)
                    Text(entry.displayName)
                        .font(Theme.captionFont)
                        .foregroundStyle(.wineText)
                    Spacer()
                    Text("\(entry.count)")
                        .font(Theme.captionFont)
                        .foregroundStyle(.wineSecondaryText)
                }
            }
        }
    }
}

// MARK: - Data Model

private struct ColorEntry: Identifiable {
    let color: String
    let count: Int

    var id: String { color }

    var displayName: String {
        switch color.uppercased() {
        case "RED": return "Red"
        case "WHITE": return "White"
        case "ROSE": return "Rosé"
        case "ORANGE": return "Orange"
        case "SPARKLING": return "Sparkling"
        default: return color.capitalized
        }
    }

    var chartColor: Color {
        switch color.uppercased() {
        case "RED": return .wineRed
        case "WHITE": return .wineGold
        case "ROSE": return .wineRose
        case "ORANGE": return .wineOrange
        case "SPARKLING": return .wineSparkling
        default: return .gray
        }
    }
}

#Preview {
    ColorSplitChart(colorSplit: [
        "RED": 15,
        "WHITE": 8,
        "ROSE": 5,
        "SPARKLING": 3,
        "ORANGE": 1
    ])
    .padding()
}
