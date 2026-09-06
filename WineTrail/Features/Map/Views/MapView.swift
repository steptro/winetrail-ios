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
                } else if let error = viewModel.error, viewModel.mapData == nil {
                    ErrorStateView(error: error) {
                        Task { await viewModel.loadMapData() }
                    }
                } else if viewModel.hasData {
                    mapContent(viewModel: viewModel)
                } else {
                    EmptyStateView(
                        icon: "map",
                        title: "No Map Data",
                        message: "Add more wines to see your map come alive."
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
        Map(initialPosition: mapCameraPosition(for: viewModel.visibleLocationPins)) {
            ForEach(viewModel.visibleLocationPins) { pin in
                Annotation(
                    pin.locationName ?? "\(pin.tastingCount) wines",
                    coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                ) {
                    singlePinView(tastingCount: Int(pin.tastingCount))
                }
            }
        }
        .mapStyle(.standard)
    }

    /// Computes a camera position that fits all pins with some padding.
    private func mapCameraPosition(for pins: [LocationPin]) -> MapCameraPosition {
        guard !pins.isEmpty else {
            return .automatic
        }

        let lats = pins.map(\.latitude)
        let lons = pins.map(\.longitude)

        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )

        let latDelta = max((lats.max()! - lats.min()!) * 1.4, 0.05)
        let lonDelta = max((lons.max()! - lons.min()!) * 1.4, 0.05)

        return .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        ))
    }

    // MARK: - Pin Views

    @ViewBuilder
    private func singlePinView(tastingCount: Int) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(.wineAccent)
                    .frame(width: 36, height: 36)
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
            .shadow(color: .wineAccent.opacity(0.4), radius: 4, y: 2)

            if tastingCount > 1 {
                Text("\(tastingCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.wineAccent.opacity(0.85), in: Capsule())
                    .offset(y: -2)
            }

            Triangle()
                .fill(.wineAccent)
                .frame(width: 12, height: 8)
                .offset(y: -2)
        }
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview("With data") {
    NavigationStack {
        MapView()
            .environment(MapService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
    }
}

#Preview("Empty state") {
    NavigationStack {
        MapView()
            .environment(MapService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
    }
}
