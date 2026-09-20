import SwiftUI

/// Global wine-search sheet presented from the Wines tab.
///
/// Lets the user look up any wine (local DB + GenAI provider) and drill into a detail
/// view. Search is debounced (500ms, min 3 characters).
struct WineSearchView: View {
    @Environment(WineService.self) private var wineService
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: WineSearchViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    Color.clear
                }
            }
            .navigationTitle("Search Wines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .navigationDestination(for: WineSearch.self) { wine in
                WineSearchDetailView(wine: wine)
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
            if viewModel.isSearching {
                WineGlassLoadingView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            } else if viewModel.results.isEmpty, viewModel.hasSearched {
                ContentUnavailableView.search
            } else {
                ForEach(viewModel.results, id: \.self) { wine in
                    NavigationLink(value: wine) {
                        WineSearchRow(wine: wine)
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if !viewModel.hasSearched, !viewModel.isSearching, viewModel.results.isEmpty {
                ContentUnavailableView(
                    "Find a Wine",
                    systemImage: "magnifyingglass",
                    description: Text("Search by name or producer to see details.")
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

/// Compact row for a wine search result.
private struct WineSearchRow: View {
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
