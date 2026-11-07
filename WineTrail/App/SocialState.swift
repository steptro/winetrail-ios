import Foundation
import Observation

/// Shared observable that tracks social state across the app: pending friend requests and
/// wines the user has been tagged in. Injected into the environment so all views stay in
/// sync without independent API calls.
@MainActor @Observable
final class SocialState {
    private let socialService: SocialService

    /// Number of incoming pending friend requests.
    private(set) var pendingRequestCount: Int = 0

    /// Number of tagged wines the user has not yet rated.
    private(set) var taggedCount: Int = 0

    /// Number of friends' requests to join the user's posts that are waiting for a decision.
    private(set) var joinRequestCount: Int = 0

    /// Combined count shown on the Social tab badge and the social menu: friend requests,
    /// unrated tagged wines and pending join requests.
    var socialBadgeCount: Int { pendingRequestCount + taggedCount + joinRequestCount }

    init(socialService: SocialService) {
        self.socialService = socialService
    }

    /// Refreshes the friend request, tagged-wines and join request counts.
    func refresh() async {
        await refreshPendingCount()
        await refreshTaggedCount()
        await refreshJoinRequestCount()
    }

    /// Refreshes the number of pending requests to join the user's posts.
    func refreshJoinRequestCount() async {
        do {
            joinRequestCount = try await socialService.getPendingJoinRequests(page: 0, size: 1).totalElements
        } catch {
            // Non-critical, don't surface errors
        }
    }

    /// Refreshes the pending friend request count from the API.
    func refreshPendingCount() async {
        do {
            let requests = try await socialService.getFriendRequests()
            pendingRequestCount = requests.count
        } catch {
            // Non-critical, don't surface errors
        }
    }

    /// Refreshes the count of unrated tagged wines.
    func refreshTaggedCount() async {
        do {
            taggedCount = try await socialService.getUnratedTaggedCount()
        } catch {
            // Non-critical, don't surface errors
        }
    }
}
