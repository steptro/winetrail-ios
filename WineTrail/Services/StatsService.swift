import Foundation
import Observation

/// Fetches personal wine statistics from the backend.
@Observable
final class StatsService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Retrieves the current user's aggregated wine statistics.
    ///
    /// - Returns: A `Stats` (alias for `Components.Schemas.UserStats`) containing
    ///   unique wines count, average rating, color breakdown, top regions, and activity data.
    /// - Throws: Network or decoding errors propagated from the generated client.
    func getStats() async throws -> Stats {
        let response = try await apiClient.client.getUserStats()
        return try response.ok.body.json
    }
}
