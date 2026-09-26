import SwiftUI
import FirebaseAuth
import RevenueCatUI

/// Profile tab — the user's identity, stats, and their own wines (tastings timeline).
/// Account and app settings live behind the gear icon in the navigation bar.
struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @Environment(ProfileService.self) private var profileService
    @Environment(SocialService.self) private var socialService
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var username: String = ""
    @State private var showPaywall = false
    @State private var showSubscriptionsUnavailable = false

    @State private var feedViewModel: ProfileFeedViewModel?
    @State private var commentsTastingId: String?
    @State private var likesTastingId: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.spacing) {
                profileHeader

                proMembershipCard
                    .padding(.horizontal, Theme.spacing)

                myWinesSection
            }
            .padding(.top, Theme.spacing)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .refreshable {
            await loadData()
        }
        .task {
            if feedViewModel == nil, let userId = appState.currentUserId {
                feedViewModel = ProfileFeedViewModel(userId: userId, socialService: socialService)
            }
            await loadData()
            await feedViewModel?.loadInitial()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tastingDidChange)) { _ in
            Task { await feedViewModel?.loadInitial() }
        }
        .sheet(item: $commentsTastingId) { tastingId in
            CommentsView(tastingId: tastingId)
        }
        .sheet(item: $likesTastingId) { tastingId in
            LikesListView(tastingId: tastingId)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(displayCloseButton: true)
                .onPurchaseCompleted { _ in Task { await subscriptions.refresh() } }
                .onRestoreCompleted { _ in Task { await subscriptions.refresh() } }
        }
        .alert("Subscriptions Unavailable", isPresented: $showSubscriptionsUnavailable) {
            Button("Try Again") { Task { await subscriptions.loadOfferings() } }
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't load subscriptions right now. Please try again in a little while.")
        }
    }

    // MARK: - My Wines (feed-style)

    /// The user's own tastings, rendered with the same card the social feed uses (photo, wine info,
    /// rating, notes, and like/comment affordances) so the profile matches the social screen.
    @ViewBuilder
    private var myWinesSection: some View {
        if let vm = feedViewModel {
            if vm.posts.isEmpty && !vm.isLoading {
                EmptyStateView(
                    icon: "wineglass",
                    title: "No Wines Yet",
                    message: "Add your first wine to start your journey."
                )
                .padding(.top, Theme.spacing)
            } else {
                LazyVStack(spacing: 24) {
                    ForEach(vm.posts, id: \.id) { post in
                        NavigationLink {
                            SocialTastingDetailView(post: post)
                        } label: {
                            SocialFeedPostView(
                                post: post,
                                onLike: { await vm.toggleLike(on: post) },
                                onComment: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    commentsTastingId = post.id
                                },
                                onLikesCount: { likesTastingId = post.id }
                            )
                        }
                        .buttonStyle(.plain)
                        .task { await vm.onPostAppear(post) }
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

    // MARK: - Pro Membership

    /// Shows the user's WineTrail Pro status. A subscriber sees a Pro badge; a resolved
    /// non-subscriber sees an upgrade prompt with a Subscribe button that opens the paywall.
    /// While entitlement state is still loading, nothing is shown (so a subscriber never briefly
    /// sees an "upgrade" prompt before their entitlement resolves).
    @ViewBuilder
    private var proMembershipCard: some View {
        if subscriptions.isLoading {
            EmptyView()
        } else if subscriptions.isPro {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(.wineGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("WineTrail Pro")
                        .font(.headline)
                        .foregroundStyle(.wineText)
                    Text("You're a Pro member")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(Theme.spacing)
            .frame(maxWidth: .infinity)
            .modifier(GlassCardModifier())
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundStyle(.wineGold)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade to WineTrail Pro")
                            .font(.headline)
                            .foregroundStyle(.wineText)
                        Text("Unlock the AI Sommelier and more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Button {
                    if subscriptions.offeringsFailed {
                        showSubscriptionsUnavailable = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Text("Subscribe")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.wineAccent, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            }
            .padding(Theme.spacing)
            .frame(maxWidth: .infinity)
            .modifier(GlassCardModifier())
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

    // MARK: - Data Loading

    private func loadData() async {
        await loadProfile()
    }

    private func loadProfile() async {
        do {
            let profile = try await profileService.getProfile()
            username = profile.username
        } catch {
            // Non-critical
        }
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
            .environment(SubscriptionManager())
    }
}
