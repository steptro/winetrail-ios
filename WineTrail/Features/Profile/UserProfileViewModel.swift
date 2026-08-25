import Foundation
import UIKit
import Observation

/// ViewModel for viewing another user's public profile with stats and tastings.
@MainActor @Observable
final class UserProfileViewModel {
    private let socialService: SocialService
    let userId: String

    private(set) var profile: Components.Schemas.PublicUserProfileDto?
    private(set) var tastings: [Components.Schemas.FeedJournalEntryDto] = []
    private(set) var isLoadingProfile = false
    private(set) var isLoadingTastings = false
    private(set) var hasMoreTastings = true
    private(set) var error: String?
    private(set) var isSendingRequest = false
    private var currentPage = 0
    private let pageSize = 20

    init(userId: String, socialService: SocialService) {
        self.userId = userId
        self.socialService = socialService
    }

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
        } catch {
            Log.error("Failed to load user profile", error: error)
            self.error = "Could not load profile."
        }

        isLoadingProfile = false
    }

    func loadTastings() async {
        guard isFriend, !isLoadingTastings, hasMoreTastings else { return }
        isLoadingTastings = true

        do {
            let page = try await socialService.getUserTastings(userId: userId, page: currentPage, size: pageSize)
            tastings.append(contentsOf: page.content)
            hasMoreTastings = !page.isLast
            currentPage += 1
        } catch {
            Log.error("Failed to load user tastings", error: error)
            hasMoreTastings = false
        }

        isLoadingTastings = false
    }

    func onTastingAppear(_ tasting: Components.Schemas.FeedJournalEntryDto) async {
        guard let index = tastings.firstIndex(where: { $0.id == tasting.id }) else { return }
        let threshold = max(tastings.count - 5, 0)
        if index >= threshold {
            await loadTastings()
        }
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
            tastings = []
            currentPage = 0
            hasMoreTastings = true
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
        guard let index = tastings.firstIndex(where: { $0.id == post.id }) else { return }

        let wasLiked = post.likedByMe
        let previousCount = post.likeCount

        // Optimistic update
        tastings[index].likedByMe.toggle()
        tastings[index].likeCount += wasLiked ? -1 : 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        do {
            if wasLiked {
                try await socialService.unlikeTasting(tastingId: post.id)
            } else {
                try await socialService.likeTasting(tastingId: post.id)
            }
        } catch {
            // Rollback
            tastings[index].likedByMe = wasLiked
            tastings[index].likeCount = previousCount
            Log.error("Failed to toggle like", error: error)
        }
    }

    /// Resets tastings for pull-to-refresh
    func resetTastings() {
        tastings = []
        currentPage = 0
        hasMoreTastings = true
    }
}
