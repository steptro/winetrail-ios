import SwiftUI
import Charts

/// Detail page for a wine from the "Your Wines" collection.
///
/// Shows wine identity, colour badge, stats, rating trend chart, price history,
/// tasting history list, and a "Log again" quick action.
struct WineDetailView: View {
    @Environment(JournalService.self) private var journalService

    let wine: WineStats

    @State private var tastings: [Tasting] = []
    @State private var stats: WineStats?
    @State private var isLoading = false
    @State private var showLogAgain = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Full-width photo header
                colourHeader

                VStack(alignment: .leading, spacing: Theme.largeSpacing) {
                    // Wine identity + colour badge
                    wineIdentity

                    // Stats row
                    statsSection

                    // Rating trend chart
                    if tastings.count >= 2 {
                        ratingTrendSection
                    }

                    // Price history
                    if tastings.contains(where: { $0.price != nil }) {
                        priceSection
                    }

                    // Tasting history
                    tastingHistorySection
                }
                .padding(.horizontal, Theme.spacing)
                .padding(.top, Theme.spacing)
                .padding(.bottom, 40)
            }
        }
        .refreshable {
            await Task {
                await loadTastings()
            }.value
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showLogAgain = true
                    } label: {
                        Label("Log Again", systemImage: "plus.circle")
                    }
                } label: {
                    Label("Contextual", systemImage: "ellipsis")
                }
            }
        }
        .task {
            await loadTastings()
        }
        .sheet(isPresented: $showLogAgain) {
            LogTastingView(preselectedWine: Components.Schemas.WineSearchDto(
                wineId: wine.wine.id,
                name: wine.wine.name,
                producer: wine.wine.producer,
                region: wine.wine.regionName,
                country: wine.wine.country,
                color: wine.wine.color
            ))
        }
        .onChange(of: showLogAgain) { _, isPresented in
            if !isPresented {
                Task { await loadTastings() }
            }
        }
        .errorAlert($errorMessage)
    }

    // MARK: - Load Data

    private func loadTastings() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await journalService.getTastingsForWine(wineId: wine.wine.id, page: 0, size: 50)
            tastings = result.content
        } catch {
            if !error.isCancellation {
                Log.error("Failed to load wine tastings", error: error)
                errorMessage = "Something went wrong. Pull to refresh to try again."
            }
        }

        do {
            stats = try await journalService.getWineStats(wineId: wine.wine.id)
        } catch {
            if !error.isCancellation {
                Log.error("Failed to load wine stats", error: error)
                if errorMessage == nil {
                    errorMessage = "Something went wrong. Pull to refresh to try again."
                }
            }
        }

        isLoading = false
    }

    // MARK: - Colour Header

    @ViewBuilder
    private var colourHeader: some View {
        let allPhotos = tastings.flatMap(\.photos)

        if !allPhotos.isEmpty {
            TabView {
                ForEach(allPhotos, id: \.id) { photo in
                    CachedAsyncImage(url: URL(string: photo.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.quaternary)
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: allPhotos.count > 1 ? .automatic : .never))
            .frame(height: 320)
        } else {
            WinePlaceholderView(color: wine.wine.color)
        }
    }

    // MARK: - Wine Identity

    @ViewBuilder
    private var wineIdentity: some View {
        HStack(spacing: 12) {
            Image(systemName: "wineglass.fill")
                .font(.title)
                .foregroundStyle(wine.wine.color?.accentColor ?? .wineAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text(wine.wine.name)
                    .font(.title3.weight(.bold))

                HStack(spacing: 6) {
                    if let country = wine.wine.country, !country.isEmpty {
                        Text(Self.flag(for: country))
                    }
                    if let producer = wine.wine.producer, !producer.isEmpty {
                        Text(producer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let region = wine.wine.regionName, !region.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(region)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        let data = stats ?? wine
        let times = tastings.isEmpty ? Int(data.timesDrunk) : tastings.count
        let avgRating = tastings.isEmpty ? data.averageRating : tastings.map { Double($0.rating) }.reduce(0, +) / Double(tastings.count)
        let firstDate = data.firstTasted

        HStack(spacing: Theme.spacing) {
            statItem(title: "Times", value: "\(times)", icon: "wineglass")
            statItem(title: "Avg Rating", value: String(format: "%.1f", avgRating), icon: "star.fill")
            if let first = firstDate, !first.isEmpty {
                statItem(title: "First", value: formatDateShort(first), icon: "calendar")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.wineAccent)
                .frame(height: 24)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 20)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.smallSpacing)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
    }

    // MARK: - Rating Trend

    @ViewBuilder
    private var ratingTrendSection: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Text("Rating Trend")
                .font(Theme.headlineFont)

            let entries = tastings.reversed().enumerated().map { index, tasting in
                RatingEntry(index: index, rating: Double(tasting.rating), date: tasting.tastingDate)
            }

            Chart(entries) { entry in
                LineMark(
                    x: .value("Tasting", entry.index),
                    y: .value("Rating", entry.rating)
                )
                .foregroundStyle(.wineAccent)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Tasting", entry.index),
                    y: .value("Rating", entry.rating)
                )
                .foregroundStyle(.wineAccent)
            }
            .chartYScale(domain: 0...5)
            .chartXAxis(.hidden)
            .frame(height: 120)
        }
        .padding(Theme.spacing)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Price Section

    @ViewBuilder
    private var priceSection: some View {
        let prices = tastings.compactMap(\.price)

        if !prices.isEmpty {
            let minPrice = prices.min() ?? 0
            let maxPrice = prices.max() ?? 0
            let avgPrice = prices.reduce(0, +) / Double(prices.count)

            VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                Text("Price History")
                    .font(Theme.headlineFont)

                HStack(spacing: Theme.spacing) {
                    priceItem(title: "Lowest", value: formatPrice(minPrice))
                    priceItem(title: "Average", value: formatPrice(avgPrice))
                    priceItem(title: "Highest", value: formatPrice(maxPrice))
                }
            }
            .padding(Theme.spacing)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    @ViewBuilder
    private func priceItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tasting History

    @ViewBuilder
    private var tastingHistorySection: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Text("History")
                .font(Theme.headlineFont)

            if isLoading {
                WineGlassLoadingView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if tastings.isEmpty {
                Text("No tastings yet")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tastings, id: \.id) { tasting in
                    tastingRow(tasting)
                    if tasting.id != tastings.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tastingRow(_ tasting: Tasting) -> some View {
        HStack(spacing: 10) {
            // Thumbnail
            if let photo = tasting.photos.first {
                CachedAsyncImage(url: URL(string: photo.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(wine.wine.color?.accentColor.opacity(0.15) ?? .wineAccent.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "wineglass")
                            .font(.caption)
                            .foregroundStyle(wine.wine.color?.accentColor.opacity(0.5) ?? .wineAccent.opacity(0.5))
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    RatingView(rating: Double(tasting.rating), starSize: .caption)
                    Spacer()
                    Text(formatDateShort(tasting.tastingDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let location = tasting.location, let name = location.locationName, !name.isEmpty {
                    Label(name, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let notes = tasting.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func formatDateShort(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateString) else { return dateString }

        let output = DateFormatter()
        output.dateFormat = "dd MMM yy"
        output.locale = Locale.current
        return output.string(from: date)
    }

    private func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    private static func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}

// MARK: - Chart Data

private struct RatingEntry: Identifiable {
    let index: Int
    let rating: Double
    let date: String
    var id: Int { index }
}

#Preview {
    NavigationStack {
        WineDetailView(wine: Components.Schemas.UserWineStats(
            wine: Components.Schemas.WineSummary(
                id: "wine-1",
                name: "Barolo DOCG 2018",
                producer: "Marchesi di Barolo",
                regionName: "Barolo",
                country: "IT",
                color: .RED
            ),
            timesDrunk: 5,
            averageRating: 4.2,
            firstTasted: "2025-03-15",
            lastTasted: "2026-08-10"
        ))
        .environment(JournalService(apiClient: APIClient(
            serverURL: AppConfig.serverURL,
            authService: AuthService()
        )))
    }
}
