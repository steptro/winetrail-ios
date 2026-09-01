import Foundation
import UIKit
import Observation

/// ViewModel for viewing another user's public profile with stats and tastings.
@MainActor @Observable
final class UserProfileViewModel {
    private let socialService: SocialService
    let userId: String
    @ObservationIgnored private let tastingsPaginator: Paginator<Components.Schemas.FeedJournalEntryDto>

    private(set) var profile: Components.Schemas.PublicUserProfileDto?
    private(set) var isLoadingProfile = false
    private(set) var isSendingRequest = false
    private(set) var notifyOnNewWine = false
    private(set) var isUpdatingNotifications = false
    private(set) var error: String?

    init(userId: String, socialService: SocialService) {
        self.userId = userId
        self.socialService = socialService
        self.tastingsPaginator = Paginator(logContext: "user tastings") { [weak socialService] page, size in
            guard let socialService else { return PagedResult(content: [], totalPages: 0, totalElements: 0, currentPage: page, isLast: true) }
            return try await socialService.getUserTastings(userId: userId, page: page, size: size)
        }
    }

    // MARK: - Tastings passthrough

    var tastings: [Components.Schemas.FeedJournalEntryDto] { tastingsPaginator.items }
    var isLoadingTastings: Bool { tastingsPaginator.isLoading }
    var hasMoreTastings: Bool { tastingsPaginator.hasMorePages }

    var isFriend: Bool {
        profile?.friendshipStatus == .FRIENDS
    }

    var isPendingSent: Bool {
        profile?.friendshipStatus == .PENDING_SENT
    }

    var isPendingReceived: Bool {
        profile?.friendshipStatus == .PENDING_RECEIVED
    }

    // MARK: - Loading

    func loadProfile() async {
        isLoadingProfile = true
        error = nil

        do {
            profile = try await socialService.getUserProfile(userId: userId)
            await loadNotificationPreference()
        } catch {
            Log.error("Failed to load user profile", error: error)
            self.error = "Could not load profile."
        }

        isLoadingProfile = false
    }

    /// Loads the per-friend new-wine notification preference. Only meaningful when friends.
    private func loadNotificationPreference() async {
        guard isFriend, let friendshipId = profile?.friendshipId else { return }
        do {
            notifyOnNewWine = try await socialService.getFriendWineNotifications(friendshipId: friendshipId)
        } catch {
            Log.error("Failed to load friend notification preference", error: error)
        }
    }

    /// Toggles whether the current user is notified when this friend posts a new wine.
    func setNotifyOnNewWine(_ enabled: Bool) async {
        guard let friendshipId = profile?.friendshipId else { return }
        let previous = notifyOnNewWine
        notifyOnNewWine = enabled // optimistic
        isUpdatingNotifications = true
        do {
            let confirmed = try await socialService.setFriendWineNotifications(
                friendshipId: friendshipId, notifyOnNewWine: enabled)
            notifyOnNewWine = confirmed
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            notifyOnNewWine = previous // rollback
            Log.error("Failed to update friend notification preference", error: error)
            self.error = "Could not update notifications."
        }
        isUpdatingNotifications = false
    }

    func loadTastings() async {
        guard isFriend else { return }
        await tastingsPaginator.loadNextPage()
    }

    func onTastingAppear(_ tasting: Components.Schemas.FeedJournalEntryDto) async {
        guard isFriend else { return }
        await tastingsPaginator.loadMoreIfNeeded(currentItem: tasting)
    }

    // MARK: - Friendship Actions

    func sendFriendRequest() async {
        isSendingRequest = true
        do {
            try await socialService.sendFriendRequest(receiverId: userId)
            // Refresh profile to get updated status
            await loadProfile()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            Log.error("Failed to send friend request", error: error)
            self.error = "Could not send friend request."
        }
        isSendingRequest = false
    }

    func acceptFriendRequest() async {
        guard let friendshipId = profile?.friendshipId else { return }
        isSendingRequest = true
        do {
            try await socialService.acceptFriendRequest(friendshipId: friendshipId)
            await loadProfile()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Now load tastings since we're friends
            await loadTastings()
        } catch {
            Log.error("Failed to accept friend request", error: error)
            self.error = "Could not accept request."
        }
        isSendingRequest = false
    }

    func removeFriend() async {
        guard let friendshipId = profile?.friendshipId else { return }
        isSendingRequest = true
        do {
            try await socialService.removeFriend(friendshipId: friendshipId)
            await tastingsPaginator.loadInitial()
            await loadProfile()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            Log.error("Failed to remove friend", error: error)
            self.error = "Could not remove friend."
        }
        isSendingRequest = false
    }

    /// Toggle like on a tasting in this profile's feed.
    func toggleLike(on post: Components.Schemas.FeedJournalEntryDto) async {
        let wasLiked = post.likedByMe
        let previousCount = post.likeCount

        // Optimistic update
        tastingsPaginator.mutate(id: post.id) { p in
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
            // Rollback
            tastingsPaginator.mutate(id: post.id) { p in
                p.likedByMe = wasLiked
                p.likeCount = previousCount
            }
            Log.error("Failed to toggle like", error: error)
        }
    }

    /// Resets tastings for pull-to-refresh
    func resetTastings() async {
        await tastingsPaginator.loadInitial()
    }
}
