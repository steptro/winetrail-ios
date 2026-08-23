import Foundation
import Observation

/// Shared observable that tracks social state across the app (e.g. pending request count).
/// Injected into the environment so all views stay in sync without independent API calls.
@MainActor @Observable
final class SocialState {
    private let socialService: SocialService

    private(set) var pendingRequestCount: Int = 0

    init(socialService: SocialService) {
        self.socialService = socialService
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
}
