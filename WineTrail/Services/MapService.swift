import Foundation
import Observation

/// Fetches map data (region pins and drinking location pins) from the backend.
@Observable
final class MapService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Fetches the full map dataset including explored regions and drinking locations.
    ///
    /// Calls `GET /api/v1/map` and returns the decoded `MapResponse` (alias for `Components.Schemas.MapData`).
    func getMapData() async throws -> MapResponse {
        let response = try await apiClient.client.getMapData()
        return try response.ok.body.json
    }
}
