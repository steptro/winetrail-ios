import SwiftUI
import CoreLocation

/// Location picker component for the Log Tasting flow.
///
/// Allows the user to toggle between GPS-based location (using LocationService)
/// and manual text entry. When GPS is selected, shows the current coordinates
/// or a "getting location..." state.
struct LocationPickerView: View {
    @Environment(LocationService.self) private var locationService

    /// Whether to use GPS for location.
    @Binding var useGPS: Bool

    /// Manual location name (used when GPS is off).
    @Binding var locationName: String

    @State private var isGettingLocation = false
    @State private var locationError: String?
    @State private var resolvedCoordinate: CLLocationCoordinate2D?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Toggle("Use current location", isOn: $useGPS)
                .accessibilityHint("Enable to tag this wine with your GPS coordinates")

            if useGPS {
                gpsLocationContent
            } else {
                TextField("Location name (e.g. restaurant, city)", text: $locationName)
                    .accessibilityLabel("Manual location name")
            }

            if let locationError {
                Text(locationError)
                    .font(Theme.captionFont)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: useGPS) { _, isEnabled in
            if isEnabled {
                Task { await fetchLocation() }
            } else {
                resolvedCoordinate = nil
                locationError = nil
            }
        }
    }

    // MARK: - GPS Content

    @ViewBuilder
    private var gpsLocationContent: some View {
        if isGettingLocation {
            HStack(spacing: Theme.smallSpacing) {
                ProgressView()
                    .controlSize(.small)
                Text("Getting location...")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            }
        } else if let coordinate = resolvedCoordinate {
            HStack(spacing: Theme.smallSpacing) {
                Image(systemName: "location.fill")
                    .foregroundStyle(.wineAccent)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatCoordinate(coordinate))
                        .font(Theme.captionFont)
                        .foregroundStyle(.primary)
                    Text("GPS coordinates will be saved")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Location: \(formatCoordinate(coordinate))")
        } else if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
            HStack(spacing: Theme.smallSpacing) {
                Image(systemName: "location.slash")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Location access denied")
                        .font(Theme.captionFont)
                        .foregroundStyle(.primary)
                    Text("Enable in Settings → Privacy → Location Services")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Location Fetching

    private func fetchLocation() async {
        isGettingLocation = true
        locationError = nil

        do {
            let coordinate = try await locationService.getCurrentLocation()
            resolvedCoordinate = coordinate
        } catch {
            locationError = "Unable to get location. Please try again."
            useGPS = false
        }

        isGettingLocation = false
    }

    // MARK: - Formatting

    private func formatCoordinate(_ coord: CLLocationCoordinate2D) -> String {
        String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
    }
}

#Preview {
    @Previewable @State var useGPS = false
    @Previewable @State var locationName = ""
    Form {
        Section("Location") {
            LocationPickerView(useGPS: $useGPS, locationName: $locationName)
        }
    }
    .environment(LocationService())
}
