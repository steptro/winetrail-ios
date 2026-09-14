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
        case agreement
        case auth
        case onboarding
        case main
    }

    var currentRoute: Route = .loading
    var pendingDeepLink: DeepLink?

    private let authService: AuthService
    private let journalService: JournalService
    private let profileService: ProfileService
    private let agreementStore: AgreementStore

    init(authService: AuthService, journalService: JournalService, profileService: ProfileService, agreementStore: AgreementStore) {
        self.authService = authService
        self.journalService = journalService
        self.profileService = profileService
        self.agreementStore = agreementStore
    }

    /// Determines the initial route based on terms acceptance, authentication state, and user data.
    ///
    /// - If the user has not accepted the current Terms/EULA → show the agreement gate
    /// - If not authenticated → show auth screen
    /// - If authenticated with no tastings → show onboarding
    /// - If authenticated with tastings → show main tab view
    func determineInitialRoute() async {
        // The Terms/EULA (including the zero-tolerance policy) must be accepted before
        // registering or logging in — required by App Store Guideline 1.2.
        guard agreementStore.hasAcceptedCurrentTerms else {
            currentRoute = .agreement
            return
        }

        guard authService.isAuthenticated else {
            currentRoute = .auth
            return
        }

        do {
            let profile = try await profileService.getProfile()
            // Show onboarding only for brand new accounts (auto-generated username from email)
            // Once a user has gone through onboarding, they'll have a custom username
            let timeline = try await journalService.getTimeline(page: 0, size: 1)
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
