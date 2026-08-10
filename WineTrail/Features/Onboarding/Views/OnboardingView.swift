import SwiftUI

/// Onboarding screen shown to new users who have no tastings yet.
///
/// Displays a minimal welcome message and immediately presents LogTastingView
/// in a sheet. Once the sheet is dismissed (tasting saved or cancelled),
/// AppState navigates to the main TabView.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var showLogTasting = true

    var body: some View {
        VStack(spacing: Theme.largeSpacing) {
            Spacer()

            Image(systemName: "wineglass.fill")
                .font(.system(size: 80))
                .foregroundStyle(.wineAccent)
                .accessibilityHidden(true)

            Text("Welcome to WineTrail")
                .font(Theme.titleFont)
                .multilineTextAlignment(.center)

            Text("Let's log your first wine!")
                .font(Theme.subheadlineFont)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Log Your First Wine") {
                showLogTasting = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.wineAccent)
            .accessibilityLabel("Log your first wine tasting")

            Spacer()
        }
        .padding(Theme.spacing)
        .sheet(isPresented: $showLogTasting, onDismiss: {
            // After dismissing the log tasting sheet, navigate to main.
            // Whether the user saved a tasting or cancelled, we move them
            // to the main timeline — it will show the new entry or empty state.
            appState.currentRoute = .main
        }) {
            LogTastingView()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState(
            authService: AuthService(),
            tastingService: TastingService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            ))
        ))
        .environment(WineService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
        .environment(TastingService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
        .environment(PhotoService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
        .environment(LocationService())
}
