import Foundation
import Observation

/// ViewModel for the Stats dashboard.
///
/// Fetches personal wine statistics from the backend via `StatsService`
/// and exposes computed properties for each dashboard section.
@MainActor @Observable
final class StatsViewModel {
    private let statsService: StatsService

    private(set) var stats: Stats?
    private(set) var isLoading = false
    private(set) var error: Error?

    init(statsService: StatsService) {
        self.statsService = statsService
    }

    /// Fetches stats from the backend.
    ///
    /// - Postconditions: `stats` is populated on success, `error` is set on failure,
    ///   `isLoading` is reset to false in both cases.
    func loadStats() async {
        isLoading = true
        error = nil
        do {
            stats = try await statsService.getStats()
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Whether enough data exists to show meaningful stats.
    var hasData: Bool {
        guard let stats else { return false }
        return (stats.uniqueWines ?? 0) > 0
    }

    /// Color split dictionary (e.g. ["RED": 10, "WHITE": 5]).
    ///
    /// The generated type wraps `additionalProperties` as `[String: Int32]`.
    var colorSplit: [String: Int] {
        guard let stats, let split = stats.colorSplit else { return [:] }
        return split.additionalProperties.mapValues { Int($0) }
    }

    /// Top regions ranked by tasting count.
    var topRegions: [Components.Schemas.RegionCount] {
        stats?.topRegions ?? []
    }

    /// Top countries ranked by tasting count.
    var topCountries: [Components.Schemas.CountryCount] {
        stats?.topCountries ?? []
    }

    /// Activity timeline data points.
    var activityTimeline: [Components.Schemas.ActivityPoint] {
        stats?.activityTimeline ?? []
    }

    /// Price statistics (total spent, average, highest).
    var priceStats: Components.Schemas.PriceStats? {
        stats?.priceStats
    }
}
