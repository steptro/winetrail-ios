import Foundation
import UIKit
import Observation

/// ViewModel for the social feed — friends' tastings with likes and comments.
@MainActor @Observable
final class SocialFeedViewModel {
    private let socialService: SocialService
    private let moderationService: ModerationService?
    private let blockStore: BlockStore?
    @ObservationIgnored private let paginator: Paginator<Components.Schemas.FeedJournalEntryDto>

    init(socialService: SocialService, moderationService: ModerationService? = nil, blockStore: BlockStore? = nil) {
        self.socialService = socialService
        self.moderationService = moderationService
        self.blockStore = blockStore
        self.paginator = Paginator(logContext: "social feed") { page, size in
            try await socialService.getFeed(page: page, size: size)
        }
    }

    // MARK: - Paginator passthrough

    /// Posts to display, with any content from locally-blocked users filtered out
    /// so a block takes effect instantly (before the next server refresh).
    var posts: [Components.Schemas.FeedJournalEntryDto] {
        guard let blockStore else { return paginator.items }
        return paginator.items.filter { !blockStore.isBlocked($0.user.id) }
    }
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

    // MARK: - Moderation

    /// Reports a feed post for objectionable content.
    func report(post: Components.Schemas.FeedJournalEntryDto, reason: ReportReason, details: String?) async throws {
        guard let moderationService else { return }
        try await moderationService.report(
            target: ReportTarget(
                contentType: .journalEntry,
                contentId: post.id,
                authorUserId: post.user.id,
                authorName: post.user.username
            ),
            reason: reason,
            details: details
        )
    }

    /// Blocks the author of a post. The block is recorded locally first (so their posts
    /// disappear from the feed immediately) and forwarded to the backend + moderation team.
    func blockAuthor(of post: Components.Schemas.FeedJournalEntryDto) async throws {
        guard let moderationService else { return }
        try await moderationService.blockUser(userId: post.user.id)
        // `posts` already filters blocked authors via BlockStore, so the UI updates instantly.
    }

}
