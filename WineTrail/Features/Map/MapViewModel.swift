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
            Log.error("Failed to load map data", error: error)
            self.error = error
        }
        isLoading = false
    }

    /// Drinking-location pins filtered by the current layer toggle state.
    var visibleLocationPins: [LocationPin] {
        guard showLocations else { return [] }
        return mapData?.drinkingLocations ?? []
    }

    /// Clusters nearby pins within a given distance threshold (in degrees).
    /// Returns clusters with a center coordinate and combined tasting count.
    func clusteredPins(threshold: Double = 0.5) -> [PinCluster] {
        let pins = visibleLocationPins
        guard !pins.isEmpty else { return [] }

        var used = Set<Int>()
        var clusters: [PinCluster] = []

        for i in pins.indices {
            guard !used.contains(i) else { continue }
            var clusterPins = [pins[i]]
            used.insert(i)

            for j in pins.indices {
                guard !used.contains(j) else { continue }
                let dx = pins[i].latitude - pins[j].latitude
                let dy = pins[i].longitude - pins[j].longitude
                let dist = (dx * dx + dy * dy).squareRoot()
                if dist < threshold {
                    clusterPins.append(pins[j])
                    used.insert(j)
                }
            }

            let avgLat = clusterPins.map(\.latitude).reduce(0, +) / Double(clusterPins.count)
            let avgLon = clusterPins.map(\.longitude).reduce(0, +) / Double(clusterPins.count)
            let totalCount = clusterPins.map { Int($0.tastingCount) }.reduce(0, +)
            let name = clusterPins.count == 1 ? clusterPins[0].locationName : nil

            clusters.append(PinCluster(
                id: "\(i)",
                latitude: avgLat,
                longitude: avgLon,
                tastingCount: totalCount,
                pinCount: clusterPins.count,
                locationName: name
            ))
        }

        return clusters
    }

    /// Whether any map data has been loaded (at least one location pin).
    var hasData: Bool {
        guard let data = mapData else { return false }
        return !data.drinkingLocations.isEmpty
    }
}



// MARK: - Pin Cluster Model

struct PinCluster: Identifiable {
    let id: String
    let latitude: Double
    let longitude: Double
    let tastingCount: Int
    let pinCount: Int
    let locationName: String?
}
