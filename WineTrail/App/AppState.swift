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

    private let authService: AuthService
    private let tastingService: TastingService

    init(authService: AuthService, tastingService: TastingService) {
        self.authService = authService
        self.tastingService = tastingService
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
            let timeline = try await tastingService.getTimeline(page: 0, size: 1)
            if timeline.totalElements == 0 {
                currentRoute = .onboarding
            } else {
                currentRoute = .main
            }
        } catch {
            // Fallback to main on error — timeline will show empty state
            currentRoute = .main
        }
    }
}
