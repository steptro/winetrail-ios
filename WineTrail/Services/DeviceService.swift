import Foundation
import Observation
import UIKit
import UserNotifications

/// Manages FCM device token lifecycle — registers tokens with the backend
/// for push notifications on sign-in/token refresh, and unregisters on sign-out.
@Observable
final class DeviceService {
    private let apiClient: APIClient
    private(set) var currentFCMToken: String?
    private var isRegistered = false

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Register the current FCM token with the backend.
    ///
    /// Called on: successful sign-in, token refresh (when authenticated).
    /// No-ops if no token is available or already registered.
    func registerToken() async throws {
        guard let token = currentFCMToken, !isRegistered else { return }

        let body = Components.Schemas.DeviceTokenRequest(
            token: token,
            platform: "IOS"
        )
        _ = try await apiClient.client.registerDeviceToken(
            .init(body: .json(body))
        )
        isRegistered = true
    }

    /// Unregister the current FCM token from the backend.
    ///
    /// Called on: sign-out, account deletion.
    /// No-ops if no token is stored.
    func unregisterToken() async throws {
        guard let token = currentFCMToken else { return }

        _ = try await apiClient.client.unregisterDeviceToken(
            path: .init(token: token)
        )
        isRegistered = false
    }

    /// Called when Firebase Messaging provides a new or refreshed FCM token.
    ///
    /// Stores the token locally and attempts registration if the user is authenticated.
    /// If registration fails (e.g. user not yet signed in), the token is stored
    /// and will be registered on the next successful sign-in via `registerToken()`.
    func onTokenRefresh(_ newToken: String) async {
        currentFCMToken = newToken
        isRegistered = false

        // Attempt immediate registration — silently ignore failures
        // (token will be registered after sign-in if user isn't authenticated yet)
        do {
            try await registerToken()
        } catch {
            // Token stored locally; will be registered on next sign-in
        }
    }

    /// Requests notification authorization from the user.
    ///
    /// Call this after sign-in or at an appropriate point in the user journey.
    /// If granted, registers for remote notifications to trigger APNs token delivery.
    @discardableResult
    func requestNotificationPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        if granted {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        return granted
    }
}
