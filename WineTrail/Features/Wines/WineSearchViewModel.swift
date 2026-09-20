import Foundation
import Observation

/// ViewModel for the global wine-search sheet on the Wines tab.
///
/// Searches wines across the local database and the GenAI provider (v2 search).
/// Debounces as the user types: waits 500ms after the last keystroke and only searches
/// once the query is at least 3 characters.
@MainActor @Observable
final class WineSearchViewModel {
    private let wineService: WineService

    private static let minQueryLength = 3
    private static let debounce: Duration = .milliseconds(500)
    private var searchTask: Task<Void, Never>?
    private var lastSearchedQuery: String?

    var query: String = "" {
        didSet {
            guard oldValue != query else { return }
            scheduleSearch()
        }
    }

    private(set) var results: [WineSearch] = []
    private(set) var isSearching = false
    private(set) var hasSearched = false

    init(wineService: WineService) {
        self.wineService = wineService
    }

    /// Schedules a debounced search. Each keystroke cancels the pending task.
    private func scheduleSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != lastSearchedQuery else { return }

        searchTask?.cancel()

        guard trimmed.count >= Self.minQueryLength else {
            results = []
            isSearching = false
            hasSearched = false
            return
        }

        isSearching = true
        searchTask = Task {
            do {
                try await Task.sleep(for: Self.debounce)
                guard !Task.isCancelled else { return }

                lastSearchedQuery = trimmed
                let locale = Locale.current.language.languageCode?.identifier ?? "en"
                let found = try await wineService.search(query: trimmed, locale: locale)
                guard !Task.isCancelled else { return }
                results = found
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                Log.error("Wine search failed", error: error)
                results = []
            }
            isSearching = false
            hasSearched = true
        }
    }
}
