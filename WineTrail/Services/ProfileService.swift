import Foundation
import Observation

/// Handles user profile operations against the backend.
@Observable
final class ProfileService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Fetches the current user's profile from the backend.
    func getProfile() async throws -> Components.Schemas.UserProfile {
        let response = try await apiClient.client.getProfile()
        return try response.ok.body.json
    }

    /// Updates the current user's profile (display name and/or username).
    @discardableResult
    func updateProfile(displayName: String? = nil, username: String? = nil) async throws -> Components.Schemas.UserProfile {
        let response = try await apiClient.client.updateProfile(
            body: .json(.init(displayName: displayName, username: username))
        )
        return try response.ok.body.json
    }

    /// Updates the current user's display name on the backend.
    ///
    /// - Parameter displayName: The new display name (1–100 characters).
    /// - Returns: The updated `UserProfile` from the server.
    /// - Throws: Network or validation errors propagated from the generated client.
    @discardableResult
    func updateDisplayName(_ displayName: String) async throws -> Components.Schemas.UserProfile {
        let response = try await apiClient.client.updateProfile(
            body: .json(.init(displayName: displayName))
        )
        return try response.ok.body.json
    }
}
