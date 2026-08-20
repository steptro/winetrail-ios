import SwiftUI

/// Wines list screen showing all unique wines the user has tried.
///
/// Features sort picker (last tasted, rating, times drunk, name), color filter menu,
/// infinite scroll pagination, pull-to-refresh, and an empty state prompting the
/// user to log their first tasting.
struct WinesListView: View {
    @Environment(WineService.self) private var wineService
    @State private var viewModel: WinesViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.wines.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "wineglass",
                        title: "No Wines Yet",
                        message: "Log your first tasting to start building your collection."
                    )
                } else {
                    List {
                        ForEach(viewModel.wines) { wine in
                            WineRow(wine: wine)
                                .task { await viewModel.onWineAppear(wine) }
                        }
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.loadInitial() }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Your Wines")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                sortPicker
            }
            ToolbarItem(placement: .topBarTrailing) {
                colorFilterMenu
            }
        }
        .task {
            if viewModel == nil {
                viewModel = WinesViewModel(wineService: wineService)
            }
            await viewModel?.loadInitial()
        }
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        Menu {
            if let viewModel {
                @Bindable var vm = viewModel
                Picker("Sort", selection: $vm.selectedSort) {
                    ForEach(WineSort.allCases) { sort in
                        Text(sort.displayName).tag(sort)
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - Color Filter Menu

    private var colorFilterMenu: some View {
        Menu {
            if let viewModel {
                @Bindable var vm = viewModel
                Picker("Color", selection: $vm.selectedColor) {
                    Text("All Colors").tag(nil as Components.Schemas.WineColor?)
                    Divider()
                    ForEach(allWineColors, id: \.self) { color in
                        Label(color.displayName, systemImage: "circle.fill")
                            .tint(color.accentColor)
                            .tag(color as Components.Schemas.WineColor?)
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: filterIcon)
        }
    }

    private var filterIcon: String {
        viewModel?.selectedColor != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
    }

    private var allWineColors: [Components.Schemas.WineColor] {
        [.RED, .WHITE, .ROSE, .ORANGE, .SPARKLING]
    }
}

#Preview {
    NavigationStack {
        WinesListView()
            .environment(WineService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
