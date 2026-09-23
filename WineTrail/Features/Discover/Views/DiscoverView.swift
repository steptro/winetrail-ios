import SwiftUI
import RevenueCatUI

/// Discover tab — a browse/search surface for finding any wine
/// (local DB + GenAI provider) and drilling into its details.
///
/// Unlike the modal `WineSearchView` presented from the Wines tab, this is a
/// root tab screen: it lives inside the tab's own `NavigationStack` and has no
/// dismiss chrome. Search is debounced by `WineSearchViewModel`.
struct DiscoverView: View {
    @Environment(WineService.self) private var wineService
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var viewModel: WineSearchViewModel?
    @State private var openSommelier = false
    @State private var showPaywall = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                Color.clear
            }
        }
        .navigationTitle("Discover")
        .navigationDestination(for: WineSearch.self) { wine in
            WineSearchDetailView(wine: wine)
        }
        .navigationDestination(isPresented: $openSommelier) {
            SommelierView()
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(displayCloseButton: true)
                .onPurchaseCompleted { _ in
                    Task {
                        await subscriptions.refresh()
                        showPaywall = false
                        if subscriptions.isPro { openSommelier = true }
                    }
                }
                .onRestoreCompleted { _ in
                    Task {
                        await subscriptions.refresh()
                        showPaywall = false
                        if subscriptions.isPro { openSommelier = true }
                    }
                }
        }
        .task {
            if viewModel == nil {
                viewModel = WineSearchViewModel(wineService: wineService)
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: WineSearchViewModel) -> some View {
        @Bindable var vm = viewModel

        List {
            Button {
                // Gate before navigating: subscribers open the sommelier;
                // everyone else gets the paywall instead of the screen.
                if subscriptions.isPro {
                    openSommelier = true
                } else {
                    showPaywall = true
                }
            } label: {
                SommelierEntryRow()
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)

            if viewModel.isSearching {
                WineGlassLoadingView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            } else if viewModel.results.isEmpty, viewModel.hasSearched {
                ContentUnavailableView.search
            } else {
                ForEach(viewModel.results, id: \.self) { wine in
                    NavigationLink(value: wine) {
                        DiscoverWineRow(wine: wine)
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if !viewModel.hasSearched, !viewModel.isSearching, viewModel.results.isEmpty {
                ContentUnavailableView(
                    "Discover Wines",
                    systemImage: "sparkle.magnifyingglass",
                    description: Text("Search by name or producer to explore wines and see their details.")
                )
            }
        }
        .searchable(
            text: $vm.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search by name or producer"
        )
        .autocorrectionDisabled()
    }
}

/// Entry banner for the AI Sommelier feature, shown at the top of Discover.
private struct SommelierEntryRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.wineAccent)
                .frame(width: 44, height: 44)
                .background(.wineAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Sommelier")
                    .font(.body.weight(.semibold))
                Text("Recommendations from the wines you've rated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

/// Compact row for a discovered wine result.
private struct DiscoverWineRow: View {
    let wine: WineSearch

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
                    if let country = wine.country, !country.isEmpty {
                        Text(WineFlag.flag(for: country))
                    }
                    if let producer = wine.producer, !producer.isEmpty {
                        Text(producer)
                            .lineLimit(1)
                    }
                    if let region = wine.region, !region.isEmpty {
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
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        DiscoverView()
            .environment(WineService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
    }
}
