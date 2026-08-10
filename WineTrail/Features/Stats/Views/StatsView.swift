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
                        message: "Log more tastings to see meaningful stats about your wine journey."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: Theme.largeSpacing) {
                            highlightCards(viewModel: viewModel)
                            ColorSplitChart(colorSplit: viewModel.colorSplit)
                            TopRegionsView(regions: viewModel.topRegions)
                            ActivityChart(timeline: viewModel.activityTimeline)
                        }
                        .padding(Theme.spacing)
                    }
                    .refreshable { await viewModel.loadStats() }
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
            Text(value)
                .font(Theme.titleFont)
                .foregroundStyle(.wineText)
            Text(title)
                .font(Theme.captionFont)
                .foregroundStyle(.wineSecondaryText)
        }
        .frame(maxWidth: .infinity)
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
