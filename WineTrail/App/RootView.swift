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


#Preview {
    RootView()
        .environment(AppState(
            authService: AuthService(),
            journalService: JournalService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )),
            profileService: ProfileService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            ))
        ))
        .environment(AuthService())
        .environment(APIClient(serverURL: AppConfig.serverURL, authService: AuthService()))
        .environment(DeviceService(apiClient: APIClient(serverURL: AppConfig.serverURL, authService: AuthService())))
        .environment(JournalService(apiClient: APIClient(serverURL: AppConfig.serverURL, authService: AuthService())))
        .environment(WineService(apiClient: APIClient(serverURL: AppConfig.serverURL, authService: AuthService())))
        .environment(PhotoService(apiClient: APIClient(serverURL: AppConfig.serverURL, authService: AuthService())))
        .environment(StatsService(apiClient: APIClient(serverURL: AppConfig.serverURL, authService: AuthService())))
        .environment(MapService(apiClient: APIClient(serverURL: AppConfig.serverURL, authService: AuthService())))
        .environment(LocationService())
        .environment(ProfileService(apiClient: APIClient(serverURL: AppConfig.serverURL, authService: AuthService())))
}
