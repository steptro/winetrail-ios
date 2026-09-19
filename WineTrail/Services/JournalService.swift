import Foundation
import Observation
import HTTPTypes
import OpenAPIRuntime

/// Business logic layer for journal entry CRUD operations.
///
/// Wraps the generated OpenAPI client methods and maps paginated responses
/// into the app-level `PagedResult` type for consumption by ViewModels.
@Observable
final class JournalService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Fetches the user's journal with pagination, sorting, color filtering, and search.
    func getTimeline(page: Int, size: Int = 20, sort: String = "createdAt", direction: String = "desc", color: Components.Schemas.WineColor? = nil, query: String? = nil) async throws -> PagedResult<JournalEntry> {
        let response = try await apiClient.client.getJournal(
            query: .init(page: Int32(page), size: Int32(size), sort: sort, direction: direction, color: color, q: query)
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

    /// Fetches a single journal entry by its ID.
    func getTasting(id: String) async throws -> JournalEntry {
        let response = try await apiClient.client.getJournalEntry(
            path: .init(entryId: id)
        )
        return try response.ok.body.json
    }

    /// Creates a new journal entry (v2).
    ///
    /// Accepts a `searchRef` (from a v2 wine search) to log a tasting against an external
    /// (GenAI) result. Throws `WineTrailError.validationFailed` on a 422 — e.g. when the
    /// `searchRef` has expired and the user must search again.
    func createTasting(_ request: CreateJournalEntryBodyV2) async throws -> JournalEntry {
        let response = try await apiClient.client.createJournalEntryV2(
            body: .json(request)
        )
        switch response {
        case .created(let created):
            return try created.body.json
        case .undocumented(let statusCode, let payload):
            let message = await Self.errorMessage(from: payload)
            if statusCode == 422 {
                throw WineTrailError.validationFailed(
                    message: message ?? "This wine is no longer available. Please search again.")
            }
            throw WineTrailError.from(httpStatus: .init(code: statusCode), message: message)
        }
    }

    /// Best-effort decode of the backend's `ErrorDto.message` from an undocumented response body.
    private static func errorMessage(from payload: OpenAPIRuntime.UndocumentedPayload) async -> String? {
        guard let body = payload.body else { return nil }
        guard let data = try? await Data(collecting: body, upTo: 8 * 1024) else { return nil }
        struct ErrorDto: Decodable { let message: String? }
        return (try? JSONDecoder().decode(ErrorDto.self, from: data))?.message
    }

    /// Updates an existing journal entry.
    func updateTasting(id: String, _ request: Components.Schemas.UpdateJournalEntryRequest) async throws -> JournalEntry {
        let response = try await apiClient.client.updateJournalEntry(
            path: .init(entryId: id),
            body: .json(request)
        )
        return try response.ok.body.json
    }

    /// Deletes a journal entry and its associated photos.
    func deleteTasting(id: String) async throws {
        _ = try await apiClient.client.deleteJournalEntry(
            path: .init(entryId: id)
        )
    }

    /// Fetches the user's tasting stats for a specific wine.
    func getWineStats(wineId: String) async throws -> Components.Schemas.UserWineStats {
        let response = try await apiClient.client.getUserWineStats(
            path: .init(wineId: wineId)
        )
        return try response.ok.body.json
    }

    /// Fetches all journal entries for a specific wine (paginated).
    func getTastingsForWine(wineId: String, page: Int = 0, size: Int = 20) async throws -> PagedResult<JournalEntry> {
        let response = try await apiClient.client.getJournalEntriesForWine(
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
