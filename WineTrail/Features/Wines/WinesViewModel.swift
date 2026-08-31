import Foundation
import Observation

/// ViewModel for the Wines list screen.
///
/// Manages infinite-scroll pagination of the user's wine collection with
/// support for sorting (by last tasted, rating, times drunk, name) and
/// filtering by wine color. Prefetches the next page when the user scrolls
/// within 5 items of the end.
@MainActor @Observable
final class WinesViewModel {
    private let wineService: WineService

    private(set) var wines: [WineStats] = []
    private(set) var isLoading = false
    private(set) var hasMorePages = true
    private(set) var error: Error?
    private var currentPage = 0
    private let pageSize = 20

    /// Debounce interval for search-as-you-type on the My Wines list.
    private static let searchDebounce: Duration = .milliseconds(300)
    private var searchDebounceTask: Task<Void, Never>?

    /// The text bound to the search field. Editing this schedules a debounced search
    /// (300ms) — results update automatically as the user types.
    var searchText: String = "" {
        didSet {
            guard oldValue != searchText else { return }
            scheduleDebouncedSearch()
        }
    }

    /// The query currently applied to the loaded results.
    private(set) var activeQuery: String = ""

    /// Currently selected sort option. Changing this reloads the list.
    var selectedSort: WineSort = .lastTasted {
        didSet {
            guard oldValue != selectedSort else { return }
            Task { await loadInitial() }
        }
    }

    /// Currently selected sort order. Changing this reloads the list.
    var selectedOrder: Components.Schemas.SortOrder = .DESC {
        didSet {
            guard oldValue != selectedOrder else { return }
            Task { await loadInitial() }
        }
    }

    /// Currently selected color filter. Nil means no filter (show all colors).
    /// Changing this reloads the list.
    var selectedColor: Components.Schemas.WineColor? = nil {
        didSet {
            guard oldValue != selectedColor else { return }
            Task { await loadInitial() }
        }
    }

    init(wineService: WineService) {
        self.wineService = wineService
    }

    /// Resets state and loads the first page of wines with current sort/filter.
    func loadInitial() async {
        currentPage = 0
        wines = []
        hasMorePages = true
        error = nil
        await loadNextPage()
    }

    /// Schedules a debounced search after `searchDebounce`. Each keystroke cancels the
    /// pending task and starts a new one, so the query only applies once typing pauses.
    private func scheduleDebouncedSearch() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDebounce)
            guard !Task.isCancelled else { return }
            await self?.applySearch()
        }
    }

    /// Applies the current `searchText` as the active query and reloads from page 0
    /// if it changed. Invoked by the debounce task (and immediately on submit).
    func applySearch() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != activeQuery else { return }
        activeQuery = trimmed
        await loadInitial()
    }

    /// Submits the search immediately (Return key), bypassing the debounce delay.
    func submitSearch() async {
        searchDebounceTask?.cancel()
        await applySearch()
    }

    /// Loads the next page of wines if not already loading and more pages exist.
    ///
    /// - Preconditions: `isLoading == false`, `hasMorePages == true`
    /// - Postconditions: `wines` extended with new content, `currentPage` incremented,
    ///   `isLoading` reset to false. On error, existing data is preserved.
    func loadNextPage() async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        error = nil

        do {
            let page = try await wineService.getMyWines(
                page: currentPage,
                size: pageSize,
                query: activeQuery.isEmpty ? nil : activeQuery,
                sort: selectedSort.apiSortOption,
                order: selectedOrder,
                color: selectedColor
            )
            wines.append(contentsOf: page.content)
            hasMorePages = !page.isLast
            currentPage += 1
        } catch {
            Log.error("Failed to load wines", error: error)
            self.error = error
        }

        isLoading = false
    }

    /// Triggers pagination when a wine appears near the end of the list.
    ///
    /// Prefetches the next page when the user scrolls within 5 items of the end,
    /// preventing the user from seeing a loading indicator in most cases.
    func onWineAppear(_ wine: WineStats) async {
        guard let index = wines.firstIndex(where: { $0.id == wine.id }) else { return }
        let thresholdIndex = max(wines.count - 5, 0)
        if index >= thresholdIndex {
            await loadNextPage()
        }
    }
}
