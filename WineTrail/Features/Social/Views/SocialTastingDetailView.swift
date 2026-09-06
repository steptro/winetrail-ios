import SwiftUI
import FirebaseAuth

/// Read-only detail page for a friend's feed post (a `FeedJournalEntryDto`).
///
/// Shows the post's photos, wine, the poster's rating, notes, and — for a shared tasting —
/// the list of friends' ratings plus an "Add My Rating" button. The button is hidden once
/// the current user has already rated (i.e. appears in the shared tasting's ratings).
struct SocialTastingDetailView: View {
    @Environment(SocialService.self) private var socialService
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    let post: Components.Schemas.FeedJournalEntryDto

    @State private var sharedRatings: [Components.Schemas.SharedRatingDto] = []
    @State private var showAddRating = false
    @State private var showComments = false

    /// True once the current user has their own rating in this shared tasting.
    private var hasMyRating: Bool {
        guard let myEmail = authService.currentUser?.email else { return false }
        return sharedRatings.contains { $0.user.email == myEmail }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                posterHeader
                    .padding(.horizontal, Theme.spacing)
                    .padding(.vertical, 10)

                heroPhoto

                VStack(alignment: .leading, spacing: Theme.largeSpacing) {
                    wineIdentity
                    HStack {
                        RatingView(rating: post.rating, starSize: .title2)
                        Spacer()
                    }
                    sharedTastingSection
                    notesSection
                }
                .padding(.horizontal, Theme.spacing)
                .padding(.top, Theme.spacing)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSharedRatings()
        }
        .sheet(isPresented: $showAddRating, onDismiss: {
            Task { await loadSharedRatings() }
        }) {
            LogTastingView(
                preselectedWine: Components.Schemas.WineSearchDto(
                    wineId: post.wine.id,
                    name: post.wine.name,
                    producer: post.wine.producer,
                    region: post.wine.regionName,
                    country: post.wine.country,
                    color: post.wine.color
                ),
                sharedTastingId: post.sharedTastingId,
                preselectedVintage: post.vintage.map { Int($0) },
                preselectedFoodPairing: post.foodPairing,
                preselectedOccasion: post.occasion,
                preselectedLocationName: post.location?.locationName,
                preselectedLatitude: post.location?.latitude,
                preselectedLongitude: post.location?.longitude
            )
        }
    }

    // MARK: - Poster Header

    @ViewBuilder
    private var posterHeader: some View {
        HStack {
            NavigationLink {
                UserProfileView(
                    userId: post.user.id,
                    username: post.user.username,
                    displayName: post.user.displayName
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(post.user.username)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text(timeAgo)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: post.createdAt, relativeTo: Date())
    }

    // MARK: - Hero Photo

    @ViewBuilder
    private var heroPhoto: some View {
        if !post.photos.isEmpty {
            TabView {
                ForEach(post.photos, id: \.id) { photo in
                    CachedAsyncImage(url: URL(string: photo.url)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(.quaternary).overlay { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: post.photos.count > 1 ? .automatic : .never))
            .frame(height: 320)
        } else {
            WinePlaceholderView(color: post.wine.color)
        }
    }

    // MARK: - Wine Identity

    @ViewBuilder
    private var wineIdentity: some View {
        HStack(spacing: 12) {
            Image(systemName: "wineglass.fill")
                .font(.title)
                .foregroundStyle(post.wine.color?.accentColor ?? .wineAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text(post.wine.name + (post.vintage.map { " (\($0))" } ?? ""))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    if let country = post.wine.country, !country.isEmpty {
                        Text(Self.flag(for: country))
                    }
                    if let producer = post.wine.producer, !producer.isEmpty {
                        Text(producer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let region = post.wine.regionName, !region.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(region)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Shared Tasting

    @ViewBuilder
    private var sharedTastingSection: some View {
        if post.sharedTastingId != nil {
            VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                if !post.taggedUsers.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(.wineAccent)
                        Text("Tasted with " + post.taggedUsers
                            .map { $0.username }
                            .joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if sharedRatings.count > 1 {
                    Text("Friend Ratings")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.wineAccent)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.top, 4)

                    ForEach(sharedRatings, id: \.user.id) { rating in
                        HStack(spacing: 10) {
                            Image(systemName: "person.circle.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Text(rating.user.username)
                                .font(.subheadline)
                            Spacer()
                            RatingView(rating: Double(rating.rating), starSize: .footnote)
                        }
                    }
                }

                // Add My Rating — only when this is a shared tasting the user hasn't rated yet.
                if !hasMyRating {
                    Button {
                        showAddRating = true
                    } label: {
                        Label("Add My Rating", systemImage: "plus.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.wineAccent)
                    .padding(.top, 4)
                }
            }
            .padding(Theme.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesSection: some View {
        if let notes = post.notes, !notes.isEmpty {
            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Data

    private func loadSharedRatings() async {
        guard let sharedTastingId = post.sharedTastingId else {
            sharedRatings = []
            return
        }
        do {
            sharedRatings = try await socialService.getSharedTastingRatings(sharedTastingId: sharedTastingId)
        } catch {
            Log.error("Failed to load shared tasting ratings", error: error)
        }
    }

    // MARK: - Helpers

    private static func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}
