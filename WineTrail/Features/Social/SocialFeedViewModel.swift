import Foundation
import UIKit
import Observation

/// ViewModel for the social feed — friends' tastings with likes and comments.
@MainActor @Observable
final class SocialFeedViewModel {
    private let socialService: SocialService

    private(set) var posts: [Components.Schemas.FeedJournalEntryDto] = []
    private(set) var isLoading = false
    private(set) var hasMorePages = true
    private(set) var error: Error?
    private var currentPage = 0
    private let pageSize = 20

    init(socialService: SocialService) {
        self.socialService = socialService
    }

    /// Loads the first page of the feed.
    func loadInitial() async {
        currentPage = 0
        posts = []
        hasMorePages = true
        error = nil
        await loadNextPage()
    }

    /// Loads the next page.
    func loadNextPage() async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        error = nil

        do {
            let page = try await socialService.getFeed(page: currentPage, size: pageSize)
            posts.append(contentsOf: page.content)
            hasMorePages = !page.isLast
            currentPage += 1
        } catch where error.isCancellation {
            // Task cancelled, ignore
        } catch {
            Log.error("Failed to load social feed", error: error)
            self.error = error
            hasMorePages = false // Stop retrying on error
        }

        isLoading = false
    }

    /// Triggers pagination near end of list.
    func onPostAppear(_ post: Components.Schemas.FeedJournalEntryDto) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let threshold = max(posts.count - 5, 0)
        if index >= threshold {
            await loadNextPage()
        }
    }

    /// Toggles like on a post.
    func toggleLike(on post: Components.Schemas.FeedJournalEntryDto) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }

        let wasLiked = post.likedByMe
        let previousCount = post.likeCount

        // Optimistic update + haptic
        posts[index].likedByMe.toggle()
        posts[index].likeCount += wasLiked ? -1 : 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        do {
            if wasLiked {
                try await socialService.unlikeTasting(tastingId: post.id)
            } else {
                try await socialService.likeTasting(tastingId: post.id)
                WineAnalytics.logLike(tastingId: post.id)
            }
        } catch {
            // Rollback
            posts[index].likedByMe = wasLiked
            posts[index].likeCount = previousCount
            Log.error("Failed to toggle like", error: error)
        }
    }
}
