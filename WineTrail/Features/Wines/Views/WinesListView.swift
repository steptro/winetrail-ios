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
                        message: "Add your first wine to start building your collection."
                    )
                } else {
                    List {
                        ForEach(viewModel.wines) { wine in
                            NavigationLink(value: wine) {
                                WineRow(wine: wine)
                            }
                            .task { await viewModel.onWineAppear(wine) }
                        }
                        if viewModel.isLoading {
                            WineGlassLoadingView()
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .navigationDestination(for: WineStats.self) { wine in
                        WineDetailView(wine: wine)
                    }
                    .refreshable {
                        await Task {
                            await viewModel.loadInitial()
                        }.value
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            } else {
                WineGlassLoadingView()
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
        .searchable(
            text: searchBinding,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search your wines"
        )
        .onSubmit(of: .search) {
            Task { await viewModel?.submitSearch() }
        }
        .task {
            if viewModel == nil {
                viewModel = WinesViewModel(wineService: wineService)
            }
            await viewModel?.loadInitial()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tastingDidChange)) { _ in
            Task { await viewModel?.loadInitial() }
        }
    }

    // MARK: - Search

    /// Binding to the view model's search text. Editing schedules a debounced (300ms)
    /// search automatically; Return submits immediately.
    private var searchBinding: Binding<String> {
        Binding(
            get: { viewModel?.searchText ?? "" },
            set: { viewModel?.searchText = $0 }
        )
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

                Divider()

                Picker("Order", selection: $vm.selectedOrder) {
                    Label("Ascending", systemImage: "arrow.up").tag(Components.Schemas.SortOrder.ASC)
                    Label("Descending", systemImage: "arrow.down").tag(Components.Schemas.SortOrder.DESC)
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
        viewModel?.selectedColor != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease"
    }

    private var allWineColors: [Components.Schemas.WineColor] {
        [.RED, .WHITE, .ROSE, .ORANGE, .SPARKLING]
    }
}

#Preview {
    NavigationStack {
        WinesListView()
            .environment(WineService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
    }
}
