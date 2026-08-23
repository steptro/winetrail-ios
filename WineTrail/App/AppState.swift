import Foundation
import Observation

/// Central app state that determines which root-level view is displayed.
///
/// The `currentRoute` property drives `RootView` to show the auth screen,
/// onboarding flow, or main tab interface.
@MainActor @Observable
final class AppState {
    enum Route: Equatable {
        case loading
        case auth
        case onboarding
        case main
    }

    var currentRoute: Route = .loading
    var pendingDeepLink: DeepLink?

    private let authService: AuthService
    private let tastingService: TastingService
    private let profileService: ProfileService

    init(authService: AuthService, tastingService: TastingService, profileService: ProfileService) {
        self.authService = authService
        self.tastingService = tastingService
        self.profileService = profileService
    }

    /// Determines the initial route based on authentication state and user data.
    ///
    /// - If not authenticated → show auth screen
    /// - If authenticated with no tastings → show onboarding
    /// - If authenticated with tastings → show main tab view
    func determineInitialRoute() async {
        guard authService.isAuthenticated else {
            currentRoute = .auth
            return
        }

        do {
            let profile = try await profileService.getProfile()
            // Show onboarding only for brand new accounts (auto-generated username from email)
            // Once a user has gone through onboarding, they'll have a custom username
            let timeline = try await tastingService.getTimeline(page: 0, size: 1)
            if timeline.totalElements == 0 && profile.username == profile.email.components(separatedBy: "@").first {
                currentRoute = .onboarding
            } else {
                currentRoute = .main
            }
        } catch {
            Log.error("Failed to determine initial route", error: error)
            currentRoute = .main
        }
    }
}
