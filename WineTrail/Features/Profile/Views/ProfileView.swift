import SwiftUI
import FirebaseAuth

/// Profile tab — the user's identity, stats, and their own wines (tastings timeline).
/// Account and app settings live behind the gear icon in the navigation bar.
struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @Environment(ProfileService.self) private var profileService
    @Environment(SocialService.self) private var socialService
    @Environment(StatsService.self) private var statsService
    @Environment(JournalService.self) private var journalService

    @State private var username: String = ""
    @State private var friendCount: Int = 0
    @State private var stats: Stats?

    @State private var timelineViewModel: TimelineViewModel?
    @State private var editingTasting: Tasting?
    @State private var tastingToDelete: Tasting?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.spacing) {
                profileHeader

                statsGrid
                    .padding(.horizontal, Theme.spacing)

                myWinesSection
            }
            .padding(.top, Theme.spacing)
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .navigationDestination(for: Tasting.self) { tasting in
            if let timelineViewModel {
                TastingDetailView(tasting: tasting, viewModel: timelineViewModel)
            }
        }
        .refreshable {
            await loadData()
        }
        .task {
            if timelineViewModel == nil {
                timelineViewModel = TimelineViewModel(journalService: journalService)
            }
            await loadData()
            await timelineViewModel?.loadInitial()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tastingDidChange)) { _ in
            Task { await timelineViewModel?.loadInitial() }
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
                if let tasting = tastingToDelete, let vm = timelineViewModel {
                    Task { await vm.deleteTasting(id: tasting.id) }
                }
            }
        } message: {
            Text("Are you sure you want to delete this entry? This cannot be undone.")
        }
    }

    // MARK: - My Wines (tastings)

    @ViewBuilder
    private var myWinesSection: some View {
        HStack {
            Text("My Wines")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.wineText)
            Spacer()
        }
        .padding(.horizontal, Theme.spacing)

        if let vm = timelineViewModel {
            if vm.tastings.isEmpty && !vm.isLoading {
                EmptyStateView(
                    icon: "wineglass",
                    title: "No Wines Yet",
                    message: "Add your first wine to start your journey."
                )
                .padding(.top, Theme.spacing)
            } else {
                LazyVStack(spacing: 24) {
                    ForEach(vm.tastings, id: \.id) { tasting in
                        NavigationLink(value: tasting) {
                            ProfileTastingRow(tasting: tasting)
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
                        .task { await vm.onTastingAppear(tasting) }
                    }
                    if vm.isLoading {
                        WineGlassLoadingView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
        } else {
            ProgressView()
                .padding(.top, Theme.spacing)
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: Theme.smallSpacing) {
            avatar

            Text(authService.currentUser?.displayName ?? "Wine Enthusiast")
                .font(.title2.weight(.bold))
                .foregroundStyle(.wineText)

            if !username.isEmpty {
                Text("@\(username)")
                    .font(Theme.subheadlineFont)
                    .foregroundStyle(.wineSecondaryText)
            }

            if let creationDate = authService.currentUser?.metadata.creationDate {
                Text("Member since \(creationDate.formatted(.dateTime.month(.wide).year()))")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let photoURL = authService.currentUser?.photoURL {
            AsyncImage(url: photoURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                avatarPlaceholder
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 88, height: 88)
            .foregroundStyle(.wineAccent)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 0) {
            statItem(value: "\(totalTastings)", label: "Tastings")
            statItem(value: "\(stats?.uniqueWines ?? 0)", label: "Wines")
            statItem(
                value: stats?.averageRating.map { String(format: "%.1f", $0) } ?? "—",
                label: "Avg Rating"
            )
            statItem(value: "\(friendCount)", label: "Friends")
        }
        .padding(.vertical, 12)
        .modifier(GlassCardModifier())
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.wineAccent)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var totalTastings: Int {
        guard let stats, let split = stats.colorSplit else { return 0 }
        return split.additionalProperties.values.reduce(0) { $0 + Int($1) }
    }

    // MARK: - Data Loading

    private func loadData() async {
        async let profileTask: () = loadProfile()
        async let friendsTask: () = loadFriends()
        async let statsTask: () = loadStats()
        _ = await (profileTask, friendsTask, statsTask)
    }

    private func loadProfile() async {
        do {
            let profile = try await profileService.getProfile()
            username = profile.username
        } catch {
            // Non-critical
        }
    }

    private func loadFriends() async {
        do {
            let friends = try await socialService.getFriends()
            friendCount = friends.count
        } catch {
            // Non-critical
        }
    }

    private func loadStats() async {
        do {
            stats = try await statsService.getStats()
        } catch {
            // Non-critical
        }
    }
}

/// Compact tasting row for the profile's "My Wines" list.
private struct ProfileTastingRow: View {
    let tasting: Tasting

    var body: some View {
        HStack(spacing: 12) {
            if let first = tasting.photos.first {
                CachedAsyncImage(url: URL(string: first.url)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill((tasting.wine.color?.accentColor ?? .wineAccent).opacity(0.2))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "wineglass.fill")
                            .foregroundStyle(tasting.wine.color?.accentColor ?? .wineAccent)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tasting.wine.name + (tasting.vintage.map { " (\($0))" } ?? ""))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let producer = tasting.wine.producer, !producer.isEmpty {
                    Text(producer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                RatingView(rating: Double(tasting.rating), starSize: .caption)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.spacing)
    }
}

// MARK: - Glass Card Modifier

/// Applies Liquid Glass on iOS 26+, falls back to ultraThinMaterial on older versions.
private struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: Theme.cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environment(AuthService())
            .environment(ProfileService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
            .environment(StatsService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
            .environment(JournalService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
    }
}
