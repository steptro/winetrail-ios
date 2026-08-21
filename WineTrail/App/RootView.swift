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
            tastingService: TastingService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            ))
        ))
        .environment(AuthService())
        .environment(APIClient(serverURL: URL(string: "https://api.winetrail.app")!, authService: AuthService()))
        .environment(DeviceService(apiClient: APIClient(serverURL: URL(string: "https://api.winetrail.app")!, authService: AuthService())))
        .environment(TastingService(apiClient: APIClient(serverURL: URL(string: "https://api.winetrail.app")!, authService: AuthService())))
        .environment(WineService(apiClient: APIClient(serverURL: URL(string: "https://api.winetrail.app")!, authService: AuthService())))
        .environment(PhotoService(apiClient: APIClient(serverURL: URL(string: "https://api.winetrail.app")!, authService: AuthService())))
        .environment(StatsService(apiClient: APIClient(serverURL: URL(string: "https://api.winetrail.app")!, authService: AuthService())))
        .environment(MapService(apiClient: APIClient(serverURL: URL(string: "https://api.winetrail.app")!, authService: AuthService())))
        .environment(LocationService())
        .environment(ProfileService(apiClient: APIClient(serverURL: URL(string: "https://api.winetrail.app")!, authService: AuthService())))
}
