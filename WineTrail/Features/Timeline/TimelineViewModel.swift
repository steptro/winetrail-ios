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
    @ObservationIgnored private let paginator = Paginator<Tasting>(logContext: "timeline")

    var sort: TimelineSort = .createdAt
    var sortDirection: String = "desc"
    var colorFilter: Components.Schemas.WineColor? = nil
    var searchQuery: String = ""
    private var searchTask: Task<Void, Never>?

    init(journalService: JournalService) {
        self.journalService = journalService
        paginator.setFetch { [weak self] page, size in
            guard let self else { return PagedResult(content: [], totalPages: 0, totalElements: 0, currentPage: page, isLast: true) }
            let trimmed = self.searchQuery.trimmingCharacters(in: .whitespaces)
            return try await self.journalService.getTimeline(
                page: page,
                size: size,
                sort: self.sort.rawValue,
                direction: self.sortDirection,
                color: self.colorFilter,
                query: trimmed.isEmpty ? nil : trimmed
            )
        }
    }

    // MARK: - Paginator passthrough

    var tastings: [Tasting] { paginator.items }
    var isLoading: Bool { paginator.isLoading }
    var hasMorePages: Bool { paginator.hasMorePages }
    var error: Error? { paginator.error }

    /// Resets state and loads the first page of tastings.
    func loadInitial() async {
        await paginator.loadInitial()
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

    /// Triggers pagination when a tasting appears near the end of the list,
    /// and prefetches photos for the next few tastings.
    func onTastingAppear(_ tasting: Tasting) async {
        await paginator.loadMoreIfNeeded(currentItem: tasting)

        // Prefetch photos for the next few tastings
        let all = paginator.items
        guard let index = all.firstIndex(where: { $0.id == tasting.id }) else { return }
        let prefetchRange = (index + 1)..<min(index + 4, all.count)
        guard prefetchRange.lowerBound < prefetchRange.upperBound else { return }
        let urls = all[prefetchRange]
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
        paginator.remove(id: id)
        do {
            try await journalService.deleteTasting(id: id)
        } catch {
            Log.error("Failed to delete tasting", error: error)
            await loadInitial()
        }
    }
}
