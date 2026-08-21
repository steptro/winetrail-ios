import SwiftUI

/// Feed screen showing tastings in an Instagram-style layout.
///
/// Each tasting is a full-width post with a header (wine glass + name + date),
/// hero photo, and metadata row. Supports infinite scroll, pull-to-refresh,
/// context menu actions, and an empty state.
struct TimelineView: View {
    @Environment(TastingService.self) private var tastingService
    @State private var viewModel: TimelineViewModel?
    @State private var editingTasting: Tasting?
    @State private var tastingToDelete: Tasting?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.tastings.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "wineglass",
                        title: "No Wines Yet",
                        message: "Log your first wine to start your diary.",
                        actionTitle: "New Wine"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(viewModel.tastings, id: \.id) { tasting in
                                NavigationLink(value: tasting) {
                                    FeedPostView(tasting: tasting)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        editingTasting = tasting
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        tastingToDelete = tasting
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .task { await viewModel.onTastingAppear(tasting) }
                            }
                            if viewModel.isLoading {
                                WineGlassLoadingView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .padding(.horizontal, 0)
                    }
                    .refreshable {
                        await viewModel.loadInitial()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    .navigationDestination(for: Tasting.self) { tasting in
                        TastingDetailView(tasting: tasting, viewModel: viewModel)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel == nil {
                viewModel = TimelineViewModel(tastingService: tastingService)
            }
            await viewModel?.loadInitial()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tastingDidChange)) { _ in
            Task { await viewModel?.loadInitial() }
        }
        .sheet(item: $editingTasting) { tasting in
            NavigationStack {
                EditTastingView(tasting: tasting)
            }
        }
        .alert("Delete Wine", isPresented: Binding(
            get: { tastingToDelete != nil },
            set: { if !$0 { tastingToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { tastingToDelete = nil }
            Button("Delete", role: .destructive) {
                if let tasting = tastingToDelete {
                    guard let viewModel else { return }
                    Task { await viewModel.deleteTasting(id: tasting.id) }
                }
            }
        } message: {
            Text("Are you sure you want to delete this entry? This cannot be undone.")
        }
    }
}

// MARK: - Feed Post

/// A single post in the feed, styled like an Instagram card.
fileprivate struct FeedPostView: View {
    let tasting: Tasting

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        f.locale = Locale.current
        return f
    }()

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = formatter.date(from: tasting.tastingDate) {
            return Self.dateFormatter.string(from: date)
        }
        return tasting.tastingDate
    }

    /// Converts an ISO 3166-1 alpha-2 code to its flag emoji.
    private static func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo carousel (slidable)
            if !tasting.photos.isEmpty {
                TabView {
                    ForEach(tasting.photos, id: \.id) { photo in
                        AsyncImage(url: URL(string: photo.url)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(.quaternary)
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: tasting.photos.count > 1 ? .automatic : .never))
                .frame(height: 320)
            } else {
                // No photo — show a subtle placeholder with the wine color
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                (tasting.wine.color?.accentColor ?? .wineAccent).opacity(0.15),
                                (tasting.wine.color?.accentColor ?? .wineAccent).opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "wineglass")
                            .font(.largeTitle)
                            .foregroundStyle(tasting.wine.color?.accentColor.opacity(0.3) ?? .wineAccent.opacity(0.3))
                    }
            }

            // Info below photo
            VStack(alignment: .leading, spacing: 8) {
                // Wine name + producer + date row
                HStack(spacing: 10) {
                    Image(systemName: "wineglass.fill")
                        .font(.title2)
                        .foregroundStyle(tasting.wine.color?.accentColor ?? .wineAccent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(tasting.wine.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            if let country = tasting.wine.country, !country.isEmpty {
                                Text(Self.flag(for: country))
                            }
                            if let producer = tasting.wine.producer, !producer.isEmpty {
                                Text(producer)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Stars + location row
                HStack {
                    RatingView(rating: Double(tasting.rating), starSize: .callout)
                    Spacer()
                    if let location = tasting.location, let name = location.locationName {
                        Label(name, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // Notes preview
                if let notes = tasting.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, Theme.spacing)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Feed") {
    NavigationStack {
        TimelineView()
            .environment(TastingService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}

#Preview("Feed Post") {
    FeedPostView(tasting: Components.Schemas.TastingDto(
        id: "preview-1",
        wine: Components.Schemas.WineSummary(
            id: "wine-1",
            name: "Château Margaux 2015",
            producer: "Château Margaux",
            regionName: "Bordeaux",
            country: "FR",
            color: .RED
        ),
        rating: 4,
        notes: "Incredibly complex, with layers of blackcurrant and cedar. Long finish.",
        foodPairing: "Grilled lamb",
        occasion: nil,
        price: nil,
        currency: nil,
        location: Components.Schemas.LocationData(
            latitude: 48.8566,
            longitude: 2.3522,
            locationName: "Le Comptoir, Paris"
        ),
        tastingDate: "2026-08-15",
        vintage: 2015,
        photos: [],
        createdAt: Date(),
        updatedAt: Date()
    ))
    .padding()
}
