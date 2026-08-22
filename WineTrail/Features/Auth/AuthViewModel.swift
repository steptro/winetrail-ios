import Foundation
import Observation

/// ViewModel coordinating authentication actions for the Auth UI.
///
/// Wraps `AuthService` with loading/error state for the sign-in screen
/// and handles post-sign-in side effects (FCM token registration,
/// notification permissions, route determination).
@MainActor @Observable
final class AuthViewModel {
    private let authService: AuthService
    private let deviceService: DeviceService
    private let appState: AppState

    var isLoading = false
    var error: String?

    init(authService: AuthService, deviceService: DeviceService, appState: AppState) {
        self.authService = authService
        self.deviceService = deviceService
        self.appState = appState
    }

    // MARK: - Sign-In Actions

    /// Initiates Sign in with Apple and handles post-sign-in flow.
    func signInWithApple() async {
        isLoading = true
        error = nil
        do {
            try await authService.signInWithApple()
            await postSignIn()
        } catch {
            Log.error("Sign-in failed", error: error)
            self.error = "Sign-in failed. Please try again."
        }
        isLoading = false
    }

    /// Initiates Sign in with Google and handles post-sign-in flow.
    func signInWithGoogle() async {
        isLoading = true
        error = nil
        do {
            try await authService.signInWithGoogle()
            await postSignIn()
        } catch {
            Log.error("Sign-in failed", error: error)
            self.error = "Sign-in failed. Please try again."
        }
        isLoading = false
    }

    /// Signs in with email and password, then handles post-sign-in flow.
    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        error = nil
        do {
            try await authService.signInWithEmail(email: email, password: password)
            await postSignIn()
        } catch {
            Log.error("Sign-in failed", error: error)
            self.error = "Sign-in failed. Please try again."
        }
        isLoading = false
    }

    /// Creates a new account with email and password, then handles post-sign-in flow.
    func createAccount(email: String, password: String) async {
        isLoading = true
        error = nil
        do {
            try await authService.createAccount(email: email, password: password)
            await postSignIn()
        } catch {
            Log.error("Sign-in failed", error: error)
            self.error = "Sign-in failed. Please try again."
        }
        isLoading = false
    }

    /// Clears the current error message.
    func dismissError() {
        error = nil
    }

    // MARK: - Private

    /// Post-sign-in side effects: register FCM token, request notification
    /// permissions, and determine the initial navigation route.
    private func postSignIn() async {
        try? await deviceService.registerToken()
        _ = try? await deviceService.requestNotificationPermission()
        await appState.determineInitialRoute()
    }
}
