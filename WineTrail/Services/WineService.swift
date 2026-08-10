import Foundation
import Observation

/// Wine search and user-created wine management.
///
/// Wraps the generated OpenAPI client methods for wine search, creation,
/// and fetching the user's wine collection with tasting stats.
@Observable
final class WineService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Searches wines across local DB and external providers.
    /// - Parameters:
    ///   - query: The search query string (e.g. wine name, producer).
    ///   - locale: BCP 47 locale for result localization (defaults to "en").
    /// - Returns: An array of wine search results (may be empty).
    func search(query: String, locale: String = "en") async throws -> [WineSearch] {
        let response = try await apiClient.client.searchWines(
            query: .init(q: query, locale: locale)
        )
        return try response.ok.body.json
    }

    /// Creates a user-defined wine on the backend.
    /// - Parameter request: The create wine request body (name required, other fields optional).
    /// - Returns: The newly created wine DTO with server-assigned data.
    func createWine(_ request: Components.Schemas.CreateWineRequest) async throws -> Components.Schemas.WineDto {
        let response = try await apiClient.client.createWine(
            body: .json(request)
        )
        return try response.created.body.json
    }

    /// Fetches the authenticated user's wines with tasting stats (paginated).
    /// - Parameters:
    ///   - page: Zero-based page index.
    ///   - size: Number of items per page (defaults to 20).
    ///   - sort: Optional sort option (times drunk, average rating, last tasted).
    ///   - color: Optional wine color filter.
    /// - Returns: A paginated result containing wine stats for the requested page.
    func getMyWines(
        page: Int,
        size: Int = 20,
        sort: Components.Schemas.WineSortOption? = nil,
        color: Components.Schemas.WineColor? = nil
    ) async throws -> PagedResult<WineStats> {
        let response = try await apiClient.client.getUserWines(
            query: .init(color: color, sort: sort, page: Int32(page), size: Int32(size))
        )
        let dto = try response.ok.body.json
        return PagedResult(
            content: dto.content ?? [],
            totalPages: Int(dto.totalPages ?? 0),
            totalElements: Int(dto.totalElements ?? 0),
            currentPage: Int(dto.number ?? 0),
            isLast: dto.last ?? true
        )
    }
}
