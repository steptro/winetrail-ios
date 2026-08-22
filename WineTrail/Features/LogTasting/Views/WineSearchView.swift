import SwiftUI

/// Standalone wine search view that can be used as a navigation destination
/// or embedded within the Log Tasting flow.
///
/// Shows a search field, displays results with wine color indicators, and
/// offers a "Create New Wine" option when results are empty or when the
/// user wants to add a wine not found in the database.
struct WineSearchView: View {
    @Environment(WineService.self) private var wineService
    @Environment(\.dismiss) private var dismiss

    /// Binding to the selected wine in the parent view model.
    @Binding var selectedWine: WineSearch?

    /// Callback when the user wants to create a new wine.
    var onCreateWine: (() -> Void)?

    @State private var searchQuery = ""
    @State private var searchResults: [WineSearch] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        List {
            Section {
                TextField("Search wines...", text: $searchQuery)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Wine search field")
            }

            if isSearching {
                Section {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching...")
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !searchResults.isEmpty {
                Section("Results") {
                    ForEach(searchResults, id: \.name) { wine in
                        Button {
                            selectedWine = wine
                            dismiss()
                        } label: {
                            wineResultRow(wine: wine)
                        }
                    }
                }
            }

            if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty && !isSearching && searchResults.isEmpty {
                Section {
                    noResultsView
                }
            }

            Section {
                Button {
                    onCreateWine?()
                } label: {
                    Label("Create New Wine", systemImage: "plus.circle")
                        .foregroundStyle(.wineAccent)
                }
            }
        }
        .navigationTitle("Search Wines")
        .onChange(of: searchQuery) { _, newValue in
            performSearch(query: newValue)
        }
    }

    // MARK: - Search Logic

    private func performSearch(query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                let locale = Locale.current.language.languageCode?.identifier ?? "en"
                let results = try await wineService.search(query: trimmed, locale: locale)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                guard !Task.isCancelled else { return }
                Log.error("Wine search failed", error: error)
                searchResults = []
            }
            isSearching = false
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func wineResultRow(wine: WineSearch) -> some View {
        HStack(spacing: Theme.smallSpacing) {
            if let color = wine.color {
                WineColorIndicator(color: color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(wine.name)
                    .font(Theme.bodyFont)
                    .foregroundStyle(.primary)
                if let producer = wine.producer {
                    Text(producer)
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
                if let region = wine.region {
                    Text(region)
                        .font(Theme.captionFont)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(wine.name), \(wine.color?.displayName ?? "wine")")
    }

    @ViewBuilder
    private var noResultsView: some View {
        VStack(spacing: Theme.smallSpacing) {
            Image(systemName: "wineglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No wines found for \"\(searchQuery)\"")
                .font(Theme.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Try a different search or create a new wine.")
                .font(Theme.captionFont)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing)
    }
}

#Preview {
    NavigationStack {
        WineSearchView(selectedWine: .constant(nil))
            .environment(WineService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
