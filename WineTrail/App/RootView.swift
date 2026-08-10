import SwiftUI

/// The app's root view that switches between auth, onboarding, and main flows
/// based on the current route in AppState.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.currentRoute {
            case .loading:
                ProgressView()
            case .auth:
                AuthView()
            case .onboarding:
                OnboardingView()
            case .main:
                MainTabView()
            }
        }
        .animation(.default, value: appState.currentRoute)
    }
}
