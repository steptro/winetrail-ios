import Foundation
import Observation

/// ViewModel for the Map feature.
///
/// Fetches region and drinking-location pin data from the backend and manages
/// layer toggle state so the user can show/hide each pin category independently.
@MainActor @Observable
final class MapViewModel {
    private let mapService: MapService

    private(set) var mapData: MapResponse?
    private(set) var isLoading = false
    private(set) var error: Error?
    var showLocations = true

    init(mapService: MapService) {
        self.mapService = mapService
    }

    /// Fetches map data from the backend.
    ///
    /// - Postconditions: `mapData` is populated on success, `error` is set on failure,
    ///   `isLoading` is reset to false in both cases.
    func loadMapData() async {
        isLoading = true
        error = nil
        do {
            mapData = try await mapService.getMapData()
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Drinking-location pins filtered by the current layer toggle state.
    var visibleLocationPins: [LocationPin] {
        guard showLocations else { return [] }
        return mapData?.drinkingLocations ?? []
    }

    /// Whether any map data has been loaded (at least one location pin).
    var hasData: Bool {
        guard let data = mapData else { return false }
        return !data.drinkingLocations.isEmpty
    }
}
