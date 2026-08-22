import SwiftUI

/// A compact row view displaying a wine's key stats for the wines list.
///
/// Shows wine glass icon, name, producer, region, times drunk, last tasted,
/// and average rating.
struct WineRow: View {
    let wine: WineStats

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wineglass.fill")
                .font(.title3)
                .foregroundStyle(wine.wine.color?.accentColor ?? .wineAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(wine.wine.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let country = wine.wine.country, !country.isEmpty {
                        Text(Self.flag(for: country))
                    }
                    if let producer = wine.wine.producer {
                        Text(producer)
                            .lineLimit(1)
                    }
                    if let region = wine.wine.regionName {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(region)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.wineAccent)
                Text(String(format: "%.1f", wine.averageRating))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private func formatRelativeDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateString) else { return dateString }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            let weekday = DateFormatter()
            weekday.dateFormat = "EEEE"
            return weekday.string(from: date)
        } else {
            let short = DateFormatter()
            short.dateFormat = "dd MMM"
            return short.string(from: date)
        }
    }

    private static func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }

    private var accessibilityDescription: String {
        var parts = [wine.wine.name]
        if let producer = wine.wine.producer { parts.append(producer) }
        if let color = wine.wine.color { parts.append("\(color.displayName) wine") }
        parts.append("tasted \(wine.timesDrunk) times")
        parts.append("average rating \(String(format: "%.1f", wine.averageRating)) out of 5")
        return parts.joined(separator: ", ")
    }
}


#Preview {
    List {
        WineRow(wine: Components.Schemas.UserWineStats(
            wine: Components.Schemas.WineSummary(id: "wine-1", name: "Barolo DOCG 2018", producer: "Marchesi di Barolo", regionName: "Barolo", country: "IT", color: .RED),
            timesDrunk: 5,
            averageRating: 4.2,
            firstTasted: "2025-03-15",
            lastTasted: "2026-08-10"
        ))
        WineRow(wine: Components.Schemas.UserWineStats(
            wine: Components.Schemas.WineSummary(id: "wine-2", name: "Sancerre 2022", producer: "Domaine Vacheron", regionName: "Loire", country: "FR", color: .WHITE),
            timesDrunk: 2,
            averageRating: 3.5,
            firstTasted: "2026-06-01",
            lastTasted: "2026-07-20"
        ))
        WineRow(wine: Components.Schemas.UserWineStats(
            wine: Components.Schemas.WineSummary(id: "wine-3", name: "Whispering Angel 2023", producer: "Château d'Esclans", regionName: "Provence", country: "FR", color: .ROSE),
            timesDrunk: 8,
            averageRating: 3.0,
            firstTasted: "2024-06-15",
            lastTasted: "2026-08-18"
        ))
    }
}
