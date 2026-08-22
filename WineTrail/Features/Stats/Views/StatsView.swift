import SwiftUI

/// Stats dashboard showing personal wine journey statistics.
///
/// Displays unique wines count, average rating, color split chart,
/// top regions list, and weekly activity timeline. Shows an empty state
/// when the user has insufficient data.
struct StatsView: View {
    @Environment(StatsService.self) private var statsService
    @State private var viewModel: StatsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.stats == nil {
                    ProgressView()
                } else if !viewModel.hasData {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: "Not Enough Data",
                        message: "Add more wines to see meaningful stats about your wine journey."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: Theme.largeSpacing) {
                            highlightCards(viewModel: viewModel)
                            if let priceStats = viewModel.priceStats {
                                priceStatsCard(stats: priceStats)
                            }
                            ColorSplitChart(colorSplit: viewModel.colorSplit)
                            TopCountriesView(countries: viewModel.topCountries)
                            TopRegionsView(regions: viewModel.topRegions)
                            ActivityChart(timeline: viewModel.activityTimeline)
                        }
                        .padding(Theme.spacing)
                    }
                    .refreshable {
                        await viewModel.loadStats()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Stats")
        .task {
            if viewModel == nil {
                viewModel = StatsViewModel(statsService: statsService)
            }
            await viewModel?.loadStats()
        }
    }

    /// Top highlight cards showing unique wines and average rating.
    @ViewBuilder
    private func highlightCards(viewModel: StatsViewModel) -> some View {
        HStack(spacing: Theme.spacing) {
            StatCard(
                title: "Unique Wines",
                value: "\(viewModel.stats?.uniqueWines ?? 0)",
                icon: "wineglass"
            )
            StatCard(
                title: "Avg. Rating",
                value: String(format: "%.1f", viewModel.stats?.averageRating ?? 0),
                icon: "star.fill"
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Price statistics card showing total spent, average, and highest price.
    @ViewBuilder
    private func priceStatsCard(stats: Components.Schemas.PriceStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Text("Spending")
                .font(Theme.headlineFont)
                .foregroundStyle(.wineText)

            HStack(spacing: Theme.spacing) {
                StatCard(
                    title: "Total Spent",
                    value: formatPrice(stats.totalSpent ?? 0),
                    icon: "creditcard"
                )
                StatCard(
                    title: "Avg. Price",
                    value: formatPrice(stats.averagePrice ?? 0),
                    icon: "tag"
                )
                StatCard(
                    title: "Highest",
                    value: formatPrice(stats.highestPrice ?? 0),
                    icon: "arrow.up"
                )
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

// MARK: - Stat Card

/// A compact card displaying a single metric with icon, value, and label.
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: Theme.smallSpacing) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.wineAccent)
                .frame(height: 28)
            Text(value)
                .font(Theme.titleFont)
                .foregroundStyle(.wineText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 28)
            Text(title)
                .font(Theme.captionFont)
                .foregroundStyle(.wineSecondaryText)
                .lineLimit(1)
                .frame(height: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.spacing)
        .background(.wineSecondaryBackground, in: .rect(cornerRadius: Theme.cornerRadius))
    }
}

#Preview {
    NavigationStack {
        StatsView()
            .environment(StatsService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
