import Foundation
import UIKit
import Observation
import OpenAPIRuntime
import HTTPTypes

/// Handles photo compression, multipart upload, and deletion for tastings.
///
/// Photos are compressed to JPEG ≤500KB using iterative quality reduction before
/// being uploaded as multipart/form-data to the backend.
@Observable
final class PhotoService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Uploads a single photo to a tasting as multipart/form-data.
    ///
    /// - Parameters:
    ///   - tastingId: The UUID string of the tasting to attach the photo to.
    ///   - imageData: JPEG image data (should be pre-compressed via `compressImage`).
    /// - Returns: The uploaded photo metadata from the server.
    /// - Throws: Network or server errors mapped through the API client.
    func uploadPhoto(tastingId: String, imageData: Data) async throws -> Components.Schemas.PhotoUploadDto {
        let body: Operations.uploadPhoto.Input.Body = .multipartForm([
            .file(.init(
                payload: .init(body: .init(imageData)),
                filename: "photo.jpg",
            ))
        ])
        let response = try await apiClient.client.uploadPhoto(
            path: .init(tastingId: tastingId),
            body: body
        )
        return try response.created.body.json
    }

    /// Deletes a photo by its ID.
    ///
    /// - Parameter id: The UUID string of the photo to delete.
    /// - Throws: Network or server errors mapped through the API client.
    func deletePhoto(id: String) async throws {
        _ = try await apiClient.client.deletePhoto(path: .init(photoId: id))
    }

    /// Iteratively compresses a UIImage to JPEG until it's under the target size.
    ///
    /// Starts at 0.8 quality and decreases by 0.1 each iteration until the data
    /// is within the limit or the minimum quality (0.1) is reached.
    ///
    /// - Parameters:
    ///   - image: The source image to compress.
    ///   - maxSizeKB: Maximum file size in kilobytes (default: 500).
    /// - Returns: JPEG data at the largest quality that fits within the size limit.
    func compressImage(_ image: UIImage, maxSizeKB: Int = 500) -> Data {
        var quality: CGFloat = 0.8
        var data = image.jpegData(compressionQuality: quality) ?? Data()

        while data.count > maxSizeKB * 1024, quality > 0.1 {
            quality -= 0.1
            data = image.jpegData(compressionQuality: quality) ?? Data()
        }

        return data
    }

    /// Compresses and uploads multiple photos for a tasting.
    ///
    /// Processes up to 5 images (the backend limit), compressing each before upload.
    ///
    /// - Parameters:
    ///   - tastingId: The UUID string of the tasting to attach photos to.
    ///   - images: Array of images to upload (only the first 5 are processed).
    ///   - maxSizeKB: Maximum JPEG file size in kilobytes (default: 500).
    /// - Returns: Array of uploaded photo metadata in upload order.
    /// - Throws: Network or server errors. Stops on first failure.
    func uploadPhotos(tastingId: String, images: [UIImage], maxSizeKB: Int = 500) async throws -> [Components.Schemas.PhotoUploadDto] {
        var uploaded: [Components.Schemas.PhotoUploadDto] = []
        for image in images.prefix(5) {
            let compressed = compressImage(image, maxSizeKB: maxSizeKB)
            let photo = try await uploadPhoto(tastingId: tastingId, imageData: compressed)
            uploaded.append(photo)
        }
        return uploaded
    }
}
