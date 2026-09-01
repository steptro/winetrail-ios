import Foundation
import Observation

/// Generic infinite-scroll paginator over a Spring-style `PagedResult` source.
///
/// Owns the paging mechanics shared by every list screen — page cursor, `isLoading`
/// guard, `hasMorePages`, error capture, and the "load more when near the end" trigger —
/// so view models only supply a `fetch(page:size:)` closure and their own domain logic
/// (filters, optimistic mutations).
///
/// Cancellation is swallowed silently; other errors are captured in ``error`` and stop
/// further auto-paging until the next ``loadInitial()``.
@MainActor
@Observable
final class Paginator<Element: Identifiable> {

    /// The accumulated items across all loaded pages.
    private(set) var items: [Element] = []
    /// True while a page request is in flight.
    private(set) var isLoading = false
    /// True until the backend reports the last page (or an error stops paging).
    private(set) var hasMorePages = true
    /// The most recent non-cancellation error, if any.
    private(set) var error: Error?

    private var currentPage = 0
    private let pageSize: Int
    private let prefetchDistance: Int
    private let logContext: String
    private var fetch: ((_ page: Int, _ size: Int) async throws -> PagedResult<Element>)?

    /// - Parameters:
    ///   - pageSize: items requested per page (default 20).
    ///   - prefetchDistance: how many items from the end triggers the next load (default 5).
    ///   - logContext: label used in error logs, e.g. "social feed".
    ///   - fetch: loads one page from the backend. May be supplied later via ``setFetch(_:)``
    ///            when the owner needs a fully-initialized `self` to build the closure.
    init(
        pageSize: Int = 20,
        prefetchDistance: Int = 5,
        logContext: String,
        fetch: ((_ page: Int, _ size: Int) async throws -> PagedResult<Element>)? = nil
    ) {
        self.pageSize = pageSize
        self.prefetchDistance = prefetchDistance
        self.logContext = logContext
        self.fetch = fetch
    }

    /// Supplies (or replaces) the page-fetch closure after construction. Call once from the
    /// owner's `init` after all stored properties are set, so the closure may capture `self`.
    func setFetch(_ fetch: @escaping (_ page: Int, _ size: Int) async throws -> PagedResult<Element>) {
        self.fetch = fetch
    }

    /// Resets to page 0 and loads the first page. Call on appear, refresh, or filter change.
    func loadInitial() async {
        currentPage = 0
        items = []
        hasMorePages = true
        error = nil
        await loadNextPage()
    }

    /// Loads the next page if not already loading and more pages remain.
    func loadNextPage() async {
        guard !isLoading, hasMorePages, let fetch else { return }
        isLoading = true
        error = nil

        do {
            let page = try await fetch(currentPage, pageSize)
            items.append(contentsOf: page.content)
            hasMorePages = !page.isLast
            currentPage += 1
        } catch where error.isCancellation {
            // Task cancelled — leave state intact.
        } catch {
            Log.error("Failed to load \(logContext)", error: error)
            self.error = error
            hasMorePages = false // stop auto-retrying until next loadInitial()
        }

        isLoading = false
    }

    /// Triggers the next page when `item` is within `prefetchDistance` of the end.
    func loadMoreIfNeeded(currentItem item: Element) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if index >= max(items.count - prefetchDistance, 0) {
            await loadNextPage()
        }
    }

    // MARK: - In-place mutation helpers (for optimistic updates)

    /// Replaces the element with the same id, if present.
    func replace(_ element: Element) {
        guard let index = items.firstIndex(where: { $0.id == element.id }) else { return }
        items[index] = element
    }

    /// Removes the element with the given id.
    func remove(id: Element.ID) {
        items.removeAll { $0.id == id }
    }

    /// Mutates the element with the given id in place, if present.
    func mutate(id: Element.ID, _ transform: (inout Element) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        transform(&items[index])
    }
}
