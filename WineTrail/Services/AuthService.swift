import Foundation
import Observation
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import UIKit

/// Errors specific to the authentication layer.
enum AuthenticationError: LocalizedError {
    case missingIdentityToken
    case invalidIdentityToken
    case missingPresentingViewController
    case missingGoogleIDToken
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Apple Sign-In failed: missing identity token."
        case .invalidIdentityToken:
            return "Apple Sign-In failed: identity token is not valid UTF-8."
        case .missingPresentingViewController:
            return "Google Sign-In failed: unable to find a presenting view controller."
        case .missingGoogleIDToken:
            return "Google Sign-In failed: missing ID token from Google."
        case .notAuthenticated:
            return "No authenticated user. Please sign in first."
        }
    }
}

@Observable
final class AuthService: @unchecked Sendable {
    private(set) var currentUser: FirebaseAuth.User?
    private(set) var isAuthenticated: Bool = false
    private(set) var isLoading: Bool = true

    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    init() {}

    /// Start observing Firebase auth state changes.
    /// Call once at app startup. The listener fires immediately with the current
    /// auth state (setting `isLoading` to false) and again on every sign-in/sign-out.
    func startListening() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.currentUser = user
            self.isAuthenticated = user != nil
            self.isLoading = false
        }
    }

    // MARK: - Sign in with Apple

    /// Presents the Apple Sign-In flow and authenticates with Firebase.
    ///
    /// 1. Generates a random nonce for replay protection.
    /// 2. Creates an ASAuthorizationAppleIDRequest with email + fullName scopes.
    /// 3. Presents ASAuthorizationController via async/await continuation.
    /// 4. Extracts the identity token and creates a Firebase OAuthProvider credential.
    /// 5. Signs in to Firebase with the credential.
    func signInWithApple() async throws {
        let nonce = Self.randomNonceString()
        let hashedNonce = Self.sha256(nonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let authorization = try await performAppleSignIn(request: request)

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken else {
            throw AuthenticationError.missingIdentityToken
        }

        guard let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthenticationError.invalidIdentityToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: identityToken,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Email/Password Authentication

    /// Signs in an existing user with their email address and password.
    /// The auth state listener will automatically update `currentUser` and `isAuthenticated`.
    func signInWithEmail(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    /// Creates a new user account with the given email address and password.
    /// The auth state listener will automatically update `currentUser` and `isAuthenticated`.
    func createAccount(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    // MARK: - Sign in with Google

    /// Presents the Google Sign-In flow and authenticates with Firebase.
    ///
    /// 1. Obtains the root view controller from the active window scene.
    /// 2. Triggers Google Sign-In SDK's sign-in flow (presents consent screen).
    /// 3. Extracts the ID token and access token from the result.
    /// 4. Creates a Firebase GoogleAuthProvider credential.
    /// 5. Signs in to Firebase with the credential.
    @MainActor
    func signInWithGoogle() async throws {
        // Configure GIDSignIn on demand with the Firebase client ID
        if GIDSignIn.sharedInstance.configuration == nil,
           let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthenticationError.missingPresentingViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthenticationError.missingGoogleIDToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Sign Out

    /// Signs out the current user and resets local auth state.
    /// The auth state listener will also fire, but we update immediately for responsive UI.
    func signOut() throws {
        try Auth.auth().signOut()
        // State will be updated by the auth state listener, but reset immediately for UI responsiveness
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Token

    /// Returns the current Firebase ID token for API authorization.
    /// Firebase automatically caches and refreshes tokens (~1 hour lifetime).
    /// - Parameter forceRefresh: If true, forces a token refresh regardless of expiry.
    /// - Returns: The current ID token string.
    func getIDToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = currentUser else {
            throw AuthenticationError.notAuthenticated
        }
        return try await user.getIDToken(forcingRefresh: forceRefresh)
    }

    // MARK: - Account Deletion

    /// Deletes the user's account: first removes backend data, then deletes Firebase auth.
    ///
    /// The closure-based approach avoids a circular dependency between AuthService and APIClient,
    /// since APIClient depends on AuthService for tokens.
    ///
    /// - Parameter deleteBackendData: Closure that calls `DELETE /api/v1/users/me` on the backend.
    func deleteAccount(deleteBackendData: () async throws -> Void) async throws {
        // 1. Delete user data on the backend first
        try await deleteBackendData()

        // 2. Delete the Firebase auth account
        guard let user = currentUser else {
            throw AuthenticationError.notAuthenticated
        }
        try await user.delete()

        // 3. Reset local state
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Private helpers

    /// Presents ASAuthorizationController and bridges the delegate callbacks to async/await.
    private func performAppleSignIn(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            controller.delegate = delegate
            // Retain delegate for the lifetime of the controller using associated objects.
            objc_setAssociatedObject(controller, &AssociatedKeys.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
            controller.performRequests()
        }
    }

    /// Generates a cryptographically secure random string for the nonce.
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(errorCode == errSecSuccess, "Unable to generate random bytes")
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    /// SHA-256 hash of the input string, returned as a hex-encoded string.
    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

// MARK: - Associated object key for retaining the delegate

private enum AssociatedKeys {
    static var delegateKey: UInt8 = 0
}

// MARK: - Apple Sign-In Delegate

/// Bridges ASAuthorizationControllerDelegate callbacks to a Swift Concurrency continuation.
private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, Sendable {
    private let continuation: CheckedContinuation<ASAuthorization, Error>

    nonisolated init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}
