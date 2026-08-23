import Foundation
import Observation

/// Sort options for the journal timeline.
enum TimelineSort: String, CaseIterable {
    case createdAt = "createdAt"
    case tastingDate = "tastingDate"
    case rating = "rating"
    case updatedAt = "updatedAt"

    var displayName: String {
        switch self {
        case .createdAt: return "Date Added"
        case .tastingDate: return "Tasting Date"
        case .rating: return "Rating"
        case .updatedAt: return "Last Updated"
        }
    }

    var defaultDirection: String {
        switch self {
        case .rating: return "desc"
        default: return "desc"
        }
    }
}

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
    var sort: TimelineSort = .createdAt
    var sortDirection: String = "desc"
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

    /// Changes sort and reloads.
    func changeSort(_ newSort: TimelineSort) async {
        sort = newSort
        sortDirection = newSort.defaultDirection
        await loadInitial()
    }

    /// Loads the next page of tastings if not already loading and more pages exist.
    func loadNextPage() async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        error = nil

        do {
            let page = try await tastingService.getTimeline(
                page: currentPage,
                size: pageSize,
                sort: sort.rawValue,
                direction: sortDirection
            )
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
