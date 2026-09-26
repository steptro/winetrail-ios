import Foundation
import UIKit
import Observation

/// Loads the current user's OWN tastings as feed posts (`FeedJournalEntryDto`), so the profile can
/// render them with the same `SocialFeedPostView` card the social feed uses — including like and
/// comment affordances. Backed by the same `getUserTastings` endpoint, passed the current user's id.
@MainActor @Observable
final class ProfileFeedViewModel {
    private let socialService: SocialService
    @ObservationIgnored private let paginator: Paginator<Components.Schemas.FeedJournalEntryDto>

    init(userId: String, socialService: SocialService) {
        self.socialService = socialService
        self.paginator = Paginator(logContext: "profile tastings") { [weak socialService] page, size in
            guard let socialService else {
                return PagedResult(content: [], totalPages: 0, totalElements: 0, currentPage: page, isLast: true)
            }
            return try await socialService.getUserTastings(userId: userId, page: page, size: size)
        }
    }

    var posts: [Components.Schemas.FeedJournalEntryDto] { paginator.items }
    var isLoading: Bool { paginator.isLoading }

    func loadInitial() async {
        await paginator.loadInitial()
    }

    func onPostAppear(_ post: Components.Schemas.FeedJournalEntryDto) async {
        await paginator.loadMoreIfNeeded(currentItem: post)
    }

    /// Optimistic like toggle, matching the social feed's behaviour.
    func toggleLike(on post: Components.Schemas.FeedJournalEntryDto) async {
        let wasLiked = post.likedByMe
        let previousCount = post.likeCount

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
            }
        } catch {
            paginator.mutate(id: post.id) { p in
                p.likedByMe = wasLiked
                p.likeCount = previousCount
            }
            Log.error("Failed to toggle like", error: error)
        }
    }
}
