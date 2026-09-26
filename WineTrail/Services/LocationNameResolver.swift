import CoreLocation

/// Reverse-geocodes coordinates into a human-readable place name via CoreLocation.
///
/// Used both at save time (so a GPS/pin location without a typed name is stored with a name) and
/// as a display-time fallback for older tastings that were saved with coordinates but no name.
/// Best effort throughout: a failure (offline, throttled, or no matching placemark) returns nil and
/// the caller keeps the coordinates without a name.
enum LocationNameResolver {
    private static let geocoder = CLGeocoder()

    /// Resolves a display name for the given coordinates, preferring a POI/business name and
    /// falling back to locality/administrative area/country. Returns nil when nothing resolves.
    static func name(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)

        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return nil
        }

        // Prefer a named point of interest (a restaurant, winery, bar); otherwise compose the most
        // specific place available from the address components.
        if let poi = placemark.name, !poi.isEmpty, poi != placemark.thoroughfare {
            return poi
        }

        let parts = [placemark.locality, placemark.administrativeArea, placemark.country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
