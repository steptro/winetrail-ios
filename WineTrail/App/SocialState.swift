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

    /// Combined count shown on the Social tab badge (friend requests + unrated tagged wines).
    var socialBadgeCount: Int { pendingRequestCount + taggedCount }

    init(socialService: SocialService) {
        self.socialService = socialService
    }

    /// Refreshes both the pending friend request count and the tagged-wines count.
    func refresh() async {
        await refreshPendingCount()
        await refreshTaggedCount()
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
