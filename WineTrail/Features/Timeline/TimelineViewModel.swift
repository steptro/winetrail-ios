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
    private let journalService: JournalService

    private(set) var tastings: [Tasting] = []
    private(set) var isLoading = false
    private(set) var hasMorePages = true
    private(set) var error: Error?
    var sort: TimelineSort = .createdAt
    var sortDirection: String = "desc"
    var colorFilter: Components.Schemas.WineColor? = nil
    var searchQuery: String = ""
    private var currentPage = 0
    private let pageSize = 20
    private var searchTask: Task<Void, Never>?

    init(journalService: JournalService) {
        self.journalService = journalService
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

    /// Changes color filter and reloads.
    func changeColor(_ newColor: Components.Schemas.WineColor?) async {
        colorFilter = newColor
        await loadInitial()
    }

    /// Debounced search — waits 300ms after typing stops, then reloads.
    func search(_ query: String) {
        searchQuery = query
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await loadInitial()
        }
    }

    /// Loads the next page of tastings if not already loading and more pages exist.
    func loadNextPage() async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        error = nil

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespaces)

        do {
            let page = try await journalService.getTimeline(
                page: currentPage,
                size: pageSize,
                sort: sort.rawValue,
                direction: sortDirection,
                color: colorFilter,
                query: trimmedQuery.isEmpty ? nil : trimmedQuery
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

        // Prefetch photos for the next few tastings
        let prefetchRange = (index + 1)..<min(index + 4, tastings.count)
        let urls = tastings[prefetchRange]
            .flatMap(\.photos)
            .compactMap { URL(string: $0.url) }
        if !urls.isEmpty {
            await ImagePrefetcher.shared.prefetch(urls: urls)
        }
    }

    /// Optimistically removes a tasting from the local list, then deletes on the backend.
    ///
    /// If the backend call fails, the timeline is reloaded to restore consistent state.
    func deleteTasting(id: String) async {
        tastings.removeAll { $0.id == id }
        do {
            try await journalService.deleteTasting(id: id)
        } catch {
            Log.error("Failed to delete tasting", error: error)
            await loadInitial()
        }
    }
}
