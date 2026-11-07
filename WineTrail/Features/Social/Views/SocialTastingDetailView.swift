import SwiftUI
import MapKit
import FirebaseAuth

/// Read-only detail page for a friend's feed post (a `FeedJournalEntryDto`).
///
/// Shows the post's photos, wine, the poster's rating, notes, and — for a shared tasting —
/// the list of friends' ratings plus an "Add My Rating" button. The button is hidden once
/// the current user has already rated (i.e. appears in the shared tasting's ratings).
struct SocialTastingDetailView: View {
    @Environment(SocialService.self) private var socialService
    @Environment(JournalService.self) private var journalService
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let post: Components.Schemas.FeedJournalEntryDto

    @State private var sharedRatings: [Components.Schemas.SharedRatingDto] = []
    @State private var showAddRating = false
    @State private var showComments = false
    @State private var reportTarget: ReportTarget?
    @State private var toastMessage: String?

    // Join request state — only relevant on a friend's post the user is not part of yet.
    @State private var joinRequestPending = false
    @State private var joinRequestClosed = false
    @State private var isSendingJoinRequest = false

    // Edit/delete state — shown only for the current user's own post.
    @State private var editingTasting: Components.Schemas.JournalEntryDto?
    @State private var showDeleteConfirmation = false
    @State private var isPreparingEdit = false

    /// True once the current user has their own rating in this shared tasting.
    private var hasMyRating: Bool {
        guard let myId = appState.currentUserId else { return false }
        return sharedRatings.contains { $0.user.id == myId }
    }

    /// True when this post belongs to the current user (hide report for own content).
    private var isOwnPost: Bool {
        guard let myId = appState.currentUserId else { return false }
        return post.user.id == myId
    }

    /// True when the user may ask to join: a friend's post they are not tagged on, with no
    /// earlier request (a rejection is final, an approval means they are already tagged).
    private var canRequestToJoin: Bool {
        guard let myId = appState.currentUserId else { return false }
        guard !isOwnPost, !joinRequestClosed else { return false }
        return !post.taggedUsers.contains { $0.id == myId }
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
                    AskSommelierButton(
                        wineName: post.wine.name,
                        producer: post.wine.producer,
                        region: post.wine.regionName
                    )
                    joinRequestSection
                    sharedTastingSection
                    notesSection
                    metadataPills
                }
                .padding(.horizontal, Theme.spacing)
                .padding(.top, Theme.spacing)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnPost {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await prepareEdit() }
                    } label: {
                        if isPreparingEdit {
                            ProgressView()
                        } else {
                            Image(systemName: "pencil")
                        }
                    }
                    .disabled(isPreparingEdit)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        reportTarget = ReportTarget(
                            contentType: .journalEntry,
                            contentId: post.id,
                            authorUserId: post.user.id,
                            authorName: post.user.username
                        )
                    } label: {
                        Image(systemName: "flag")
                    }
                    .tint(.red)
                    .accessibilityLabel("Report Post")
                }
            }
        }
        .alert("Delete Wine", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteEntry() }
            }
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
        .sheet(item: $editingTasting, onDismiss: {
            NotificationCenter.default.post(name: .tastingDidChange, object: nil)
        }) { tasting in
            NavigationStack {
                EditTastingView(tasting: tasting)
            }
        }
        .sheet(item: $reportTarget) { target in
            ReportContentSheet(target: target, onReported: {
                toastMessage = "Thanks. Our team will review this within 24 hours."
            })
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { self.toastMessage = nil }
                    }
            }
        }
        .animation(.snappy, value: toastMessage)
        .task {
            // The feed passes the current user's request status along with the post.
            joinRequestPending = post.joinRequestStatus == .PENDING
            joinRequestClosed = post.joinRequestStatus == .APPROVED || post.joinRequestStatus == .REJECTED
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
                    AvatarView(urlString: post.user.avatarUrl, size: 28)
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
                    ZoomableScrollView {
                        CachedAsyncImage(url: URL(string: photo.url)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(.quaternary).overlay { ProgressView() }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: post.photos.count > 1 ? .automatic : .never))
            .frame(height: 480)
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

    // MARK: - Join Request

    @ViewBuilder
    private var joinRequestSection: some View {
        if canRequestToJoin {
            if joinRequestPending {
                Menu {
                    Button(role: .destructive) {
                        Task { await cancelJoinRequest() }
                    } label: {
                        Label("Withdraw Request", systemImage: "xmark")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                        Text("Requested")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            } else {
                Button {
                    Task { await requestToJoin() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                        Text("Request to Join")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.wineAccent)
                .disabled(isSendingJoinRequest)
            }
        }
    }

    private func requestToJoin() async {
        isSendingJoinRequest = true
        defer { isSendingJoinRequest = false }

        do {
            try await socialService.requestToJoin(entryId: post.id)
            joinRequestPending = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            Log.error("Failed to request to join post", error: error)
            if case WineTrailError.validationFailed(let message) = error {
                // Already requested or already part of the post: nothing left to ask for.
                joinRequestClosed = true
                toastMessage = message
            } else {
                toastMessage = "Couldn't send your request. Try again."
            }
        }
    }

    private func cancelJoinRequest() async {
        do {
            try await socialService.cancelJoinRequest(entryId: post.id)
            joinRequestPending = false
        } catch {
            Log.error("Failed to cancel join request", error: error)
            toastMessage = "Couldn't withdraw your request. Try again."
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

    // MARK: - Metadata Pills

    @ViewBuilder
    private var metadataPills: some View {
        let pills = buildPills()

        if !pills.isEmpty {
            let columns = [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ]

            LazyVGrid(columns: columns, spacing: Theme.smallSpacing) {
                ForEach(pills, id: \.label) { pill in
                    if let coordinate = pill.coordinate {
                        NavigationLink {
                            MapView(focusCoordinate: coordinate, focusName: pill.label)
                                .navigationTitle(pill.label)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            pillCell(pill)
                        }
                        .buttonStyle(.plain)
                    } else {
                        pillCell(pill)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A single metadata pill cell (icon, value, title).
    @ViewBuilder
    private func pillCell(_ pill: MetadataPill) -> some View {
        VStack(spacing: 4) {
            Image(systemName: pill.icon)
                .font(.title3)
                .foregroundStyle(.wineAccent)
                .frame(height: 24)
            Text(pill.label)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 16)
            Text(pill.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.smallSpacing)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
    }

    private struct MetadataPill {
        let icon: String
        let title: String
        let label: String
        /// Set only for the Location pill: tapping it opens the map centered here.
        var coordinate: CLLocationCoordinate2D? = nil
    }

    private func buildPills() -> [MetadataPill] {
        var pills: [MetadataPill] = []

        pills.append(MetadataPill(icon: "calendar", title: "Date", label: formattedTastingDate))

        if let location = post.location {
            let coordinate = location.latitude.flatMap { lat in
                location.longitude.map { lng in CLLocationCoordinate2D(latitude: lat, longitude: lng) }
            }
            let storedName = location.locationName.flatMap { $0.isEmpty ? nil : $0 }
            if storedName != nil || coordinate != nil {
                let label = storedName ?? "View on Map"
                pills.append(MetadataPill(icon: "mappin", title: "Location", label: label, coordinate: coordinate))
            }
        }

        if let food = post.foodPairing, !food.isEmpty {
            pills.append(MetadataPill(icon: "fork.knife", title: "Pairing", label: food))
        }

        if let occasion = post.occasion, !occasion.isEmpty {
            pills.append(MetadataPill(icon: "party.popper", title: "Occasion", label: occasion))
        }

        return pills
    }

    private var formattedTastingDate: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = inputFormatter.date(from: post.tastingDate) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "dd MMM yyyy"
            outputFormatter.locale = Locale.current
            return outputFormatter.string(from: date)
        }
        return post.tastingDate
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

    /// Fetch the full journal entry so the edit sheet has the complete tasting (the feed DTO
    /// lacks fields EditTastingView needs), then present the editor.
    private func prepareEdit() async {
        isPreparingEdit = true
        defer { isPreparingEdit = false }
        do {
            editingTasting = try await journalService.getTasting(id: post.id)
        } catch {
            Log.error("Failed to load entry for editing", error: error)
            toastMessage = "Couldn't open the editor. Please try again."
        }
    }

    /// Delete the current user's own entry, then pop back to the profile.
    private func deleteEntry() async {
        do {
            try await journalService.deleteTasting(id: post.id)
            NotificationCenter.default.post(name: .tastingDidChange, object: nil)
            dismiss()
        } catch {
            Log.error("Failed to delete entry", error: error)
            toastMessage = "Couldn't delete this entry. Please try again."
        }
    }

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
