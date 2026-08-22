import Foundation
import Observation

/// Business logic layer for tasting CRUD operations.
///
/// Wraps the generated OpenAPI client methods and maps paginated responses
/// into the app-level `PagedResult` type for consumption by ViewModels.
@Observable
final class TastingService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Fetches the user's tasting timeline with pagination.
    /// - Parameters:
    ///   - page: Zero-based page index.
    ///   - size: Number of items per page (defaults to 20).
    /// - Returns: A paginated result containing tastings for the requested page.
    func getTimeline(page: Int, size: Int = 20) async throws -> PagedResult<Tasting> {
        let response = try await apiClient.client.getTimeline(
            query: .init(page: Int32(page), size: Int32(size))
        )
        let dto = try response.ok.body.json
        return PagedResult(
            content: dto.content ?? [],
            totalPages: Int(dto.page?.totalPages ?? 0),
            totalElements: Int(dto.page?.totalElements ?? 0),
            currentPage: Int(dto.page?.number ?? 0),
            isLast: Int(dto.page?.number ?? 0) >= Int(dto.page?.totalPages ?? 1) - 1
        )
    }

    /// Fetches a single tasting by its ID.
    /// - Parameter id: The UUID string of the tasting.
    /// - Returns: The full tasting detail.
    func getTasting(id: String) async throws -> Tasting {
        let response = try await apiClient.client.getTasting(
            path: .init(tastingId: id)
        )
        return try response.ok.body.json
    }

    /// Creates a new tasting on the backend.
    /// - Parameter request: The create tasting request body (wine reference, rating, optional fields).
    /// - Returns: The newly created tasting with server-assigned ID.
    func createTasting(_ request: CreateTastingBody) async throws -> Tasting {
        let response = try await apiClient.client.createTasting(
            body: .json(request)
        )
        return try response.created.body.json
    }

    /// Updates an existing tasting.
    /// - Parameters:
    ///   - id: The UUID string of the tasting to update.
    ///   - request: The update request body with modified fields.
    /// - Returns: The updated tasting.
    func updateTasting(id: String, _ request: Components.Schemas.UpdateTastingRequest) async throws -> Tasting {
        let response = try await apiClient.client.updateTasting(
            path: .init(tastingId: id),
            body: .json(request)
        )
        return try response.ok.body.json
    }

    /// Deletes a tasting and its associated photos.
    /// - Parameter id: The UUID string of the tasting to delete.
    func deleteTasting(id: String) async throws {
        _ = try await apiClient.client.deleteTasting(
            path: .init(tastingId: id)
        )
    }

    /// Fetches the user's tasting stats for a specific wine.
    /// - Parameter wineId: The UUID string of the wine.
    /// - Returns: Stats including times drunk, average rating, first/last tasted dates.
    func getWineStats(wineId: String) async throws -> Components.Schemas.UserWineStats {
        let response = try await apiClient.client.getUserWineStats(
            path: .init(wineId: wineId)
        )
        return try response.ok.body.json
    }

    /// Fetches all tastings for a specific wine (paginated).
    /// - Parameters:
    ///   - wineId: The UUID string of the wine.
    ///   - page: Zero-based page index.
    ///   - size: Number of items per page.
    /// - Returns: A paginated result containing tastings for the requested wine.
    func getTastingsForWine(wineId: String, page: Int = 0, size: Int = 20) async throws -> PagedResult<Tasting> {
        let response = try await apiClient.client.getTastingsForWine(
            path: .init(wineId: wineId),
            query: .init(page: Int32(page), size: Int32(size))
        )
        let dto = try response.ok.body.json
        return PagedResult(
            content: dto.content ?? [],
            totalPages: Int(dto.page?.totalPages ?? 0),
            totalElements: Int(dto.page?.totalElements ?? 0),
            currentPage: Int(dto.page?.number ?? 0),
            isLast: Int(dto.page?.number ?? 0) >= Int(dto.page?.totalPages ?? 1) - 1
        )
    }
}
