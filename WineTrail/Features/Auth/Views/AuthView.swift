import SwiftUI
import AuthenticationServices

/// Sign-in screen presenting Apple, Google, and Email authentication options.
/// Uses wine-themed branding and accent colors for a warm, minimal aesthetic.
///
/// Delegates sign-in actions to `AuthViewModel` which handles post-sign-in
/// side effects (FCM token registration, notification permissions, route determination).
struct AuthView: View {
    @State private var showEmailSignIn = false
    @Environment(AuthService.self) private var authService
    @Environment(DeviceService.self) private var deviceService
    @Environment(AppState.self) private var appState
    @State private var viewModel: AuthViewModel?

    var body: some View {
        VStack(spacing: Theme.largeSpacing) {
            Spacer()

            // MARK: - App Branding
            VStack(spacing: Theme.smallSpacing) {
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.wineAccent)

                Text("WineTrail")
                    .font(Theme.titleFont)

                Text("Your personal wine diary")
                    .font(Theme.subheadlineFont)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // MARK: - Sign-In Options
            VStack(spacing: Theme.spacing) {
                // Sign in with Apple
                Button {
                    signInWithApple()
                } label: {
                    HStack(spacing: Theme.smallSpacing) {
                        Image(systemName: "apple.logo")
                        Text("Sign in with Apple")
                    }
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                }
                .buttonStyle(.plain)

                // Sign in with Google
                Button {
                    signInWithGoogle()
                } label: {
                    HStack {
                        Image(systemName: "globe")
                        Text("Sign in with Google")
                    }
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.primary)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                }
                .buttonStyle(.plain)

                // Sign in with Email
                Button("Sign in with Email") {
                    showEmailSignIn = true
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.wineAccent)
                .padding(.top, Theme.smallSpacing)
            }
            .padding(.horizontal, Theme.largeSpacing)
            .disabled(viewModel?.isLoading ?? false)

            // Error message
            if let error = viewModel?.error {
                Text(error)
                    .font(Theme.captionFont)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.largeSpacing)
            }

            Spacer()
        }
        .overlay {
            if viewModel?.isLoading == true {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                ProgressView()
                    .controlSize(.large)
            }
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignInView()
        }
        .task {
            if viewModel == nil {
                viewModel = AuthViewModel(
                    authService: authService,
                    deviceService: deviceService,
                    appState: appState
                )
            }
        }
    }

    // MARK: - Actions

    private func signInWithApple() {
        guard let vm = viewModel else { return }
        Task { await vm.signInWithApple() }
    }

    private func signInWithGoogle() {
        guard let vm = viewModel else { return }
        Task { await vm.signInWithGoogle() }
    }
}


#Preview {
    AuthView()
        .environment(AuthService())
        .environment(DeviceService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
        .environment(AppState(
            authService: AuthService(),
            journalService: JournalService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )),
            profileService: ProfileService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            ))
        ))
}
