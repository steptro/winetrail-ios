import SwiftUI

/// Wines list screen showing all unique wines the user has tried.
///
/// Features sort picker (last tasted, rating, times drunk, name), color filter menu,
/// infinite scroll pagination, pull-to-refresh, and an empty state prompting the
/// user to log their first tasting.
struct WinesListView: View {
    @Environment(WineService.self) private var wineService
    @State private var viewModel: WinesViewModel?
    @State private var showWineSearch = false

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.error != nil, viewModel.wines.isEmpty {
                    ErrorStateView {
                        Task { await viewModel.loadInitial() }
                    }
                } else if viewModel.wines.isEmpty && !viewModel.isLoading {
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
                    }
                }
            } else {
                WineGlassLoadingView()
            }
        }
        .navigationTitle("Your Wines")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                sortAndFilterMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    StatsView()
                } label: {
                    Label("Stats", systemImage: "chart.bar")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showWineSearch = true
                } label: {
                    Label("Search Wines", systemImage: "magnifyingglass")
                }
            }
        }
        .sheet(isPresented: $showWineSearch) {
            WineSearchView()
                .environment(wineService)
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

    // MARK: - Sort & Filter Menu

    private var sortAndFilterMenu: some View {
        Menu {
            if let viewModel {
                @Bindable var vm = viewModel

                Section("Sort") {
                    Picker("Sort", selection: $vm.selectedSort) {
                        ForEach(WineSort.allCases) { sort in
                            Text(sort.displayName).tag(sort)
                        }
                    }
                    Picker("Order", selection: $vm.selectedOrder) {
                        Label("Ascending", systemImage: "arrow.up").tag(Components.Schemas.SortOrder.ASC)
                        Label("Descending", systemImage: "arrow.down").tag(Components.Schemas.SortOrder.DESC)
                    }
                }

                Section("Filter") {
                    Picker("Color", selection: $vm.selectedColor) {
                        Text("All Colors").tag(nil as Components.Schemas.WineColor?)
                        ForEach(allWineColors, id: \.self) { color in
                            Label(color.displayName, systemImage: "circle.fill")
                                .tint(color.accentColor)
                                .tag(color as Components.Schemas.WineColor?)
                        }
                    }
                }
            }
        } label: {
            Label("Sort & Filter", systemImage: menuIcon)
        }
    }

    /// Reflects an active color filter so the grouped menu signals when a filter is applied.
    private var menuIcon: String {
        viewModel?.selectedColor != nil
            ? "line.3.horizontal.decrease.circle.fill"
            : "arrow.up.arrow.down"
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
