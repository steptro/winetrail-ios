import Foundation
import Observation

/// ViewModel for the Timeline (home) screen.
///
/// Manages infinite-scroll pagination of tastings, prefetching the next page
/// when the user scrolls within 5 items of the end. Also handles optimistic
/// deletion with rollback on failure.
@MainActor @Observable
final class TimelineViewModel {
    private let tastingService: TastingService

    private(set) var tastings: [Tasting] = []
    private(set) var isLoading = false
    private(set) var hasMorePages = true
    private(set) var error: Error?
    private var currentPage = 0
    private let pageSize = 20

    init(tastingService: TastingService) {
        self.tastingService = tastingService
    }

    /// Resets state and loads the first page of tastings.
    func loadInitial() async {
        currentPage = 0
        tastings = []
        hasMorePages = true
        error = nil
        await loadNextPage()
    }

    /// Loads the next page of tastings if not already loading and more pages exist.
    ///
    /// - Preconditions: `isLoading == false`, `hasMorePages == true`
    /// - Postconditions: `tastings` extended with new content, `currentPage` incremented,
    ///   `isLoading` reset to false. On error, existing data is preserved.
    func loadNextPage() async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        error = nil

        do {
            let page = try await tastingService.getTimeline(page: currentPage, size: pageSize)
            tastings.append(contentsOf: page.content)
            hasMorePages = !page.isLast
            currentPage += 1
        } catch {
            Log.error("Failed to load timeline", error: error)
            self.error = error
        }

        isLoading = false
    }

    /// Triggers pagination when a tasting appears near the end of the list.
    ///
    /// Prefetches the next page when the user scrolls within 5 items of the end,
    /// preventing the user from seeing a loading indicator in most cases.
    func onTastingAppear(_ tasting: Tasting) async {
        guard let index = tastings.firstIndex(where: { $0.id == tasting.id }) else { return }
        let thresholdIndex = max(tastings.count - 5, 0)
        if index >= thresholdIndex {
            await loadNextPage()
        }
    }

    /// Optimistically removes a tasting from the local list, then deletes on the backend.
    ///
    /// If the backend call fails, the timeline is reloaded to restore consistent state.
    func deleteTasting(id: String) async {
        tastings.removeAll { $0.id == id }
        do {
            try await tastingService.deleteTasting(id: id)
        } catch {
            Log.error("Failed to delete tasting", error: error)
            await loadInitial()
        }
    }
}
