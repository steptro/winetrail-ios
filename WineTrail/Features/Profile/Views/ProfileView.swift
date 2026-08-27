import SwiftUI
import FirebaseAuth

/// Redesigned Profile tab — shows the user's wine journey first
/// using native List with grouped sections and iOS 26 Liquid Glass.
struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @Environment(ProfileService.self) private var profileService
    @Environment(AppState.self) private var appState
    @Environment(SocialService.self) private var socialService
    @Environment(StatsService.self) private var statsService
    @Environment(DeviceService.self) private var deviceService
    @Environment(APIClient.self) private var apiClient

    @State private var username: String = ""
    @State private var friendCount: Int = 0
    @State private var stats: Stats?
    @State private var error: String?
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        List {
            // Profile Header — full width, no list row styling
            Section {
                profileHeader
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            // Account
            Section {
                NavigationLink {
                    EditProfileView()
                } label: {
                    Label("Edit Profile", systemImage: "person.fill")
                }

                NavigationLink {
                    FriendsView()
                } label: {
                    HStack {
                        Label("Friends", systemImage: "person.2.fill")
                        Spacer()
                        Text("\(friendCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Account")
            }

            // Legal
            Section {
                NavigationLink {
                    SafariView(url: URL(string: "https://winetrail.stephantromer.dev/privacy-policy")!)
                        .ignoresSafeArea()
                        .navigationTitle("Privacy Policy")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }

                NavigationLink {
                    SafariView(url: URL(string: "https://winetrail.stephantromer.dev/terms-of-service")!)
                        .ignoresSafeArea()
                        .navigationTitle("Terms of Service")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Terms of Service", systemImage: "doc.text.fill")
                }
            } header: {
                Text("Legal")
            }

            // Sign Out
            Section {
                Button(role: .destructive) {
                    Task {
                        try? await deviceService.unregisterToken()
                        try? authService.signOut()
                        appState.currentRoute = .auth
                    }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            // Delete Account
            Section {
                Button(role: .destructive) {
                    showDeleteAccountConfirmation = true
                } label: {
                    if isDeleting {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Deleting...")
                        }
                    } else {
                        Label("Delete Account", systemImage: "trash")
                    }
                }
                .disabled(isDeleting)
            } footer: {
                Text("Permanently deletes your account and all data. This cannot be undone.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .refreshable {
            await loadData()
        }
        .task {
            await loadData()
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete My Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, all your wines, tastings, photos, and social data. This cannot be undone.")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: Theme.smallSpacing) {
            avatar
                .padding(.top, Theme.spacing)

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
        .padding(.bottom, Theme.smallSpacing)
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

    // MARK: - Wine Journey Content

    @ViewBuilder
    private var wineJourneyContent: some View {
        if !colorSplit.isEmpty {
            HStack(spacing: 8) {
                ForEach(sortedColors, id: \.key) { entry in
                    colorBubble(color: entry.key, count: entry.value)
                }
                Spacer()
            }
        }

        if weeklyCount > 0 {
            HStack(spacing: 8) {
                Text("🔥")
                    .font(.title3)
                Text("\(weeklyCount) wine\(weeklyCount == 1 ? "" : "s") logged this week")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            }
        } else if colorSplit.isEmpty {
            Text("Start logging wines to see your journey here!")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func colorBubble(color: String, count: Int) -> some View {
        Text("\(count)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(colorForName(color), in: Circle())
    }

    // MARK: - Computed Helpers

    private var colorSplit: [String: Int] {
        guard let stats, let split = stats.colorSplit else { return [:] }
        return split.additionalProperties.mapValues { Int($0) }
    }

    private var sortedColors: [(key: String, value: Int)] {
        colorSplit.sorted { $0.value > $1.value }
    }

    private var totalTastings: Int {
        colorSplit.values.reduce(0, +)
    }

    private var weeklyCount: Int {
        guard let stats, let timeline = stats.activityTimeline, !timeline.isEmpty else { return 0 }
        return Int(timeline.last?.count ?? 0)
    }

    private func colorForName(_ name: String) -> Color {
        switch name.uppercased() {
        case "RED": return .wineRed
        case "WHITE": return .wineGold
        case "ROSE": return .wineRose
        case "ORANGE": return .wineOrange
        case "SPARKLING": return .wineSparkling
        default: return .wineAccent
        }
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

    private func deleteAccount() async {
        isDeleting = true
        do {
            try await deviceService.unregisterToken()
            try await authService.deleteAccount {
                _ = try await apiClient.client.deleteAccount()
            }
            appState.currentRoute = .auth
        } catch {
            Log.error("Failed to delete account", error: error)
            self.error = "Failed to delete account. Please try again."
        }
        isDeleting = false
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
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
            .environment(StatsService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
