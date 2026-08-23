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
                        message: "Add your first wine to start your journey.",
                        actionTitle: "New Wine"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(viewModel.tastings, id: \.id) { tasting in
                                NavigationLink(value: tasting) {
                                    FeedPostView(tasting: tasting)
                                }
                                .buttonStyle(PressScaleButtonStyle())
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
                        await Task {
                            await viewModel.loadInitial()
                        }.value
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
        .navigationTitle("Journal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(TimelineSort.allCases, id: \.self) { option in
                        Button {
                            Task { await viewModel?.changeSort(option) }
                        } label: {
                            Label(option.displayName, systemImage: viewModel?.sort == option ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
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
    @Environment(SocialService.self) private var socialService
    @State private var showLikes = false
    @State private var showComments = false
    @State private var likedByMe: Bool
    @State private var likeCount: Int

    init(tasting: Tasting) {
        self.tasting = tasting
        _likedByMe = State(initialValue: tasting.likedByMe)
        _likeCount = State(initialValue: Int(tasting.likeCount))
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: tasting.createdAt, relativeTo: Date())
    }

    /// Converts an ISO 3166-1 alpha-2 code to its flag emoji.
    private static func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }

    private func toggleLike() async {
        // Optimistic update
        let wasLiked = likedByMe
        let previousCount = likeCount
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            likedByMe.toggle()
            likeCount += likedByMe ? 1 : -1
            likeCount = max(likeCount, 0)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        do {
            if wasLiked {
                try await socialService.unlikeTasting(tastingId: tasting.id)
            } else {
                try await socialService.likeTasting(tastingId: tasting.id)
            }
        } catch {
            // Rollback on failure
            withAnimation {
                likedByMe = wasLiked
                likeCount = previousCount
            }
            Log.error("Failed to toggle like", error: error)
        }
    }

    private struct MetadataPill {
        let icon: String
        let label: String
    }

    private func buildPills(for tasting: Tasting) -> [MetadataPill] {
        var pills: [MetadataPill] = []

        if let location = tasting.location, let name = location.locationName, !name.isEmpty {
            pills.append(MetadataPill(icon: "mappin", label: name))
        }
        if let food = tasting.foodPairing, !food.isEmpty {
            pills.append(MetadataPill(icon: "fork.knife", label: food))
        }
        if let occasion = tasting.occasion, !occasion.isEmpty {
            pills.append(MetadataPill(icon: "party.popper", label: occasion))
        }
        if let price = tasting.price {
            let symbol = Self.currencySymbol(for: tasting.currency ?? "EUR")
            pills.append(MetadataPill(icon: "tag", label: "\(symbol)\(String(format: "%.2f", price))"))
        }

        return pills
    }

    private static func currencySymbol(for code: String) -> String {
        let locale = NSLocale(localeIdentifier: code)
        if let symbol = locale.displayName(forKey: .currencySymbol, value: code), symbol != code {
            return symbol
        }
        switch code {
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        case "CHF": return "CHF "
        default: return "\(code) "
        }
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
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)
                .overlay(alignment: .bottom) {
                    if tasting.photos.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(0..<tasting.photos.count, id: \.self) { _ in
                                Circle()
                                    .fill(.white.opacity(0.8))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.4), in: Capsule())
                        .padding(.bottom, 10)
                    }
                }
            } else {
                // No photo placeholder
                WinePlaceholderView(color: tasting.wine.color, height: 160)
            }

            // Info below photo
            VStack(alignment: .leading, spacing: 10) {
                // Wine identity
                HStack(spacing: 10) {
//                    Image(systemName: "wineglass.fill")
//                        .font(.title2)
//                        .foregroundStyle(tasting.wine.color?.accentColor ?? .wineAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tasting.wine.name + (tasting.vintage.map { " (\($0))" } ?? ""))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
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
                            if let region = tasting.wine.regionName, !region.isEmpty {
                                Text("·")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(region)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                // Rating + date row
                HStack {
                    RatingView(rating: Double(tasting.rating), starSize: .callout)
                    Spacer()
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Notes
                if let notes = tasting.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Metadata pills
                let pills = buildPills(for: tasting)
                if !pills.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(pills, id: \.label) { pill in
                                HStack(spacing: 3) {
                                    Image(systemName: pill.icon)
                                        .font(.caption2)
                                        .foregroundStyle(.wineAccent)
                                    Text(pill.label)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.wineAccent.opacity(0.15), in: Capsule())
                                .overlay(Capsule().strokeBorder(.wineAccent.opacity(0.3), lineWidth: 0.5))
                            }
                        }
                    }
                }

                // Social interactions
                HStack(spacing: 20) {
                    // Heart — tap to toggle like
                    HStack(spacing: 6) {
                        Button {
                            Task { await toggleLike() }
                        } label: {
                            Image(systemName: likedByMe ? "heart.fill" : "heart")
                                .font(.body)
                                .foregroundStyle(likedByMe ? .red : .secondary)
                                .scaleEffect(likedByMe ? 1.0 : 0.85)
                                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: likedByMe)
                        }
                        .buttonStyle(.plain)

                        // Like count — tap to show who liked
                        Button {
                            if likeCount > 0 { showLikes = true }
                        } label: {
                            Text("\(likeCount)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Comment count — tappable to open comments
                    Button {
                        showComments = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.right")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Text("\(tasting.commentCount)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .sheet(isPresented: $showLikes) {
                    LikesListView(tastingId: tasting.id)
                }
                .sheet(isPresented: $showComments) {
                    CommentsView(tastingId: tasting.id)
                }
            }
            .padding(.horizontal, Theme.spacing)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Press Scale Button Style

/// A button style that scales down slightly on press for tactile feedback.
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
            name: "Château Margaux",
            producer: "Château Margaux",
            regionName: "Bordeaux",
            country: "FR",
            color: .RED
        ),
        rating: 4,
        notes: "Incredibly complex, with layers of blackcurrant and cedar. Long finish.",
        foodPairing: "Grilled lamb",
        occasion: "Kerstdiner",
        price: 10.00,
        currency: "$",
        location: Components.Schemas.LocationData(
            latitude: 48.8566,
            longitude: 2.3522,
            locationName: "Le Comptoir, Paris"
        ),
        tastingDate: "2026-08-15",
        vintage: 2015,
        photos: [],
        likeCount: 3,
        commentCount: 1,
        likedByMe: false,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .padding()
}
