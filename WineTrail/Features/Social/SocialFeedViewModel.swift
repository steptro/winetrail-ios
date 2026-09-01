import Foundation
import UIKit
import Observation

/// ViewModel for the social feed — friends' tastings with likes and comments.
@MainActor @Observable
final class SocialFeedViewModel {
    private let socialService: SocialService
    @ObservationIgnored private let paginator: Paginator<Components.Schemas.FeedJournalEntryDto>

    init(socialService: SocialService) {
        self.socialService = socialService
        self.paginator = Paginator(logContext: "social feed") { page, size in
            try await socialService.getFeed(page: page, size: size)
        }
    }

    // MARK: - Paginator passthrough

    var posts: [Components.Schemas.FeedJournalEntryDto] { paginator.items }
    var isLoading: Bool { paginator.isLoading }
    var hasMorePages: Bool { paginator.hasMorePages }
    var error: Error? { paginator.error }

    /// Loads the first page of the feed.
    func loadInitial() async {
        await paginator.loadInitial()
    }

    /// Triggers pagination near end of list.
    func onPostAppear(_ post: Components.Schemas.FeedJournalEntryDto) async {
        await paginator.loadMoreIfNeeded(currentItem: post)
    }

    /// Toggles like on a post (optimistic update + rollback on failure).
    func toggleLike(on post: Components.Schemas.FeedJournalEntryDto) async {
        let wasLiked = post.likedByMe
        let previousCount = post.likeCount

        // Optimistic update + haptic
        paginator.mutate(id: post.id) { p in
            p.likedByMe.toggle()
            p.likeCount += wasLiked ? -1 : 1
        }
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
            paginator.mutate(id: post.id) { p in
                p.likedByMe = wasLiked
                p.likeCount = previousCount
            }
            Log.error("Failed to toggle like", error: error)
        }
    }
}
