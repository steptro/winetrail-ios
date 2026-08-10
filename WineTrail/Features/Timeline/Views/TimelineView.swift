import SwiftUI

/// Timeline screen showing a chronological diary of logged tastings.
///
/// Displays tasting cards in a scrollable list with infinite scroll pagination,
/// pull-to-refresh, a loading indicator for page fetches, and an empty state
/// prompting the user to log their first wine.
struct TimelineView: View {
    @Environment(TastingService.self) private var tastingService
    @State private var viewModel: TimelineViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.tastings.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "wineglass",
                        title: "No Tastings Yet",
                        message: "Log your first wine to start your diary.",
                        actionTitle: "Log Tasting"
                    )
                } else {
                    List {
                        ForEach(viewModel.tastings) { tasting in
                            NavigationLink(value: tasting) {
                                TastingCard(tasting: tasting)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .task { await viewModel.onTastingAppear(tasting) }
                        }
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.loadInitial() }
                    .navigationDestination(for: Tasting.self) { tasting in
                        TastingDetailView(tasting: tasting, viewModel: viewModel)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Timeline")
        .task {
            if viewModel == nil {
                viewModel = TimelineViewModel(tastingService: tastingService)
            }
            await viewModel?.loadInitial()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tastingDidChange)) { _ in
            Task { await viewModel?.loadInitial() }
        }
    }
}

#Preview {
    NavigationStack {
        TimelineView()
            .environment(TastingService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
