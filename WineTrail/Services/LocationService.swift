import Foundation
import CoreLocation
import Observation

/// Wraps CLLocationManager for GPS access with user permission handling.
///
/// Requests When-In-Use permission only when the user explicitly taps to add a location.
/// Provides an async `getCurrentLocation()` method for one-shot coordinate retrieval.
@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var currentLocation: CLLocationCoordinate2D?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    /// Requests When-In-Use location authorization and waits for the user's response.
    func requestPermission() async {
        guard authorizationStatus == .notDetermined else { return }
        let status = await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
        authorizationStatus = status
    }

    /// Returns the device's current GPS coordinates.
    ///
    /// If authorization has not been determined yet, triggers a permission prompt and waits.
    /// Throws `WineTrailError.locationPermissionDenied` when the user has denied or restricted access.
    func getCurrentLocation() async throws -> CLLocationCoordinate2D {
        if authorizationStatus == .notDetermined {
            await requestPermission()
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw WineTrailError.locationPermissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated {
            currentLocation = location.coordinate
            locationContinuation?.resume(returning: location.coordinate)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            let mappedError: Error
            if let clError = error as? CLError {
                switch clError.code {
                case .locationUnknown, .network:
                    mappedError = WineTrailError.locationUnavailable
                case .denied:
                    mappedError = WineTrailError.locationPermissionDenied
                default:
                    mappedError = WineTrailError.locationUnavailable
                }
            } else {
                mappedError = WineTrailError.locationUnavailable
            }
            locationContinuation?.resume(throwing: mappedError)
            locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorizationStatus = status
            if status != .notDetermined {
                authorizationContinuation?.resume(returning: status)
                authorizationContinuation = nil
            }
        }
    }
}
