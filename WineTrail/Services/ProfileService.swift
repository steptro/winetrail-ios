import Foundation
import UIKit
import Observation
import OpenAPIRuntime

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

    /// Uploads (or replaces) the current user's avatar and returns the updated profile.
    ///
    /// The image is JPEG-compressed before upload; the server replaces any previous
    /// avatar object, so avatars never accumulate.
    /// - Parameter image: The new avatar image.
    /// - Returns: The updated `UserProfile`, including its fresh presigned `avatarUrl`.
    @discardableResult
    func uploadAvatar(_ image: UIImage) async throws -> Components.Schemas.UserProfile {
        let data = compressAvatar(image)
        let body: Operations.uploadAvatar.Input.Body = .multipartForm([
            .file(.init(
                payload: .init(body: .init(data)),
                filename: "avatar.jpg"
            ))
        ])

        let response = try await apiClient.client.uploadAvatar(body: body)
        return try response.ok.body.json
    }

    /// Removes the current user's avatar.
    func deleteAvatar() async throws {
        _ = try await apiClient.client.deleteAvatar()
    }

    /// Compresses an avatar image to a small JPEG (avatars display at ~88pt, so a
    /// modest cap keeps uploads fast while staying under the server's 10MB limit).
    private func compressAvatar(_ image: UIImage, maxSizeKB: Int = 400) -> Data {
        var quality: CGFloat = 0.8
        var data = image.jpegData(compressionQuality: quality) ?? Data()

        while data.count > maxSizeKB * 1024, quality > 0.1 {
            quality -= 0.1
            data = image.jpegData(compressionQuality: quality) ?? Data()
        }

        return data
    }
}
