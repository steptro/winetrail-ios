import MapKit
import SwiftUI

/// Map screen showing wine regions explored and drinking locations.
///
/// Displays an interactive Apple Map with two pin layers:
/// - **Regions Explored** — wine region pins (burgundy) showing where the user's wines originate
/// - **Where I Drank** — location pins (accent) showing where tastings took place
///
/// Users can toggle each layer independently via buttons. Tapping a pin shows
/// the name and tasting count. An empty state nudges the user to log more wines.
struct MapView: View {
    @Environment(MapService.self) private var mapService
    @State private var viewModel: MapViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.mapData == nil {
                    ProgressView()
                } else if let error = viewModel.error {
                    VStack(spacing: Theme.spacing) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text(error.localizedDescription)
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await viewModel.loadMapData() }
                        }
                    }
                    .padding()
                } else if viewModel.hasData {
                    mapContent(viewModel: viewModel)
                } else {
                    EmptyStateView(
                        icon: "map",
                        title: "No Map Data",
                        message: "Log more wines to see your map come alive."
                    )
                }
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel?.loadMapData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel?.isLoading == true)
                .accessibilityLabel("Refresh map")
            }
        }
        .task {
            if viewModel == nil {
                viewModel = MapViewModel(mapService: mapService)
            }
            await viewModel?.loadMapData()
        }
    }

    // MARK: - Map Content

    @ViewBuilder
    private func mapContent(viewModel: MapViewModel) -> some View {
        Map {
            // Location pins — accent-colored drinking location markers
            ForEach(viewModel.visibleLocationPins) { pin in
                Annotation(
                    pin.locationName ?? "Location",
                    coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                ) {
                    locationPinView(pin: pin)
                }
            }
        }
        .mapStyle(.standard)
    }

    // MARK: - Pin Views

    @ViewBuilder
    private func locationPinView(pin: LocationPin) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "wineglass.fill")
                .font(.title2)
                .foregroundStyle(.wineAccent)
            Text("\(pin.tastingCount)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.wineText)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Preview

#Preview("With data") {
    NavigationStack {
        MapView()
            .environment(MapService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}

#Preview("Empty state") {
    NavigationStack {
        MapView()
            .environment(MapService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
