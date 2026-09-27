import SwiftUI
import FirebaseAuth
import RevenueCatUI
import PhotosUI

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

    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var showAvatarPicker = false
    @State private var isUpdatingAvatar = false
    @State private var showRemoveAvatarConfirm = false
    @State private var avatarError: String?

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
        .photosPicker(isPresented: $showAvatarPicker, selection: $avatarPickerItem, matching: .images)
        .onChange(of: avatarPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                defer { avatarPickerItem = nil }
                await uploadAvatar(newItem)
            }
        }
        .confirmationDialog("Remove profile photo?", isPresented: $showRemoveAvatarConfirm, titleVisibility: .visible) {
            Button("Remove Photo", role: .destructive) {
                Task { await removeAvatar() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .errorAlert($avatarError)
        .sheet(isPresented: $showPaywall) {
            PaywallView(displayCloseButton: true)
                .onPurchaseCompleted { _ in Task { await subscriptions.refresh() } }
                .onRestoreCompleted { _ in Task { await subscriptions.refresh() } }
                .onPurchaseFailure { error in subscriptions.logPaywallFailure("purchase", error: error) }
                .onRestoreFailure { error in subscriptions.logPaywallFailure("restore", error: error) }
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
        // Prefer the backend avatar (uploaded in-app); fall back to the Firebase photo
        // URL, then the placeholder.
        let backendUrl = appState.currentUserAvatarUrl
        let firebaseUrl = authService.currentUser?.photoURL?.absoluteString
        let effectiveUrl = backendUrl ?? firebaseUrl

        // With a removable (backend) avatar, offer a Change/Remove menu; otherwise tapping
        // goes straight to the picker, since there is nothing to remove yet.
        if backendUrl != nil {
            Menu {
                Button {
                    showAvatarPicker = true
                } label: {
                    Label("Change Photo", systemImage: "photo")
                }
                Button(role: .destructive) {
                    showRemoveAvatarConfirm = true
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            } label: {
                avatarLabel(effectiveUrl)
            }
            .disabled(isUpdatingAvatar)
            .accessibilityLabel("Profile photo")
            .accessibilityHint("Change or remove your profile photo")
        } else {
            Button {
                showAvatarPicker = true
            } label: {
                avatarLabel(effectiveUrl)
            }
            .buttonStyle(.plain)
            .disabled(isUpdatingAvatar)
            .accessibilityLabel("Add profile photo")
            .accessibilityHint("Tap to choose a profile photo")
        }
    }

    /// The circular avatar image with its camera badge / updating spinner overlay.
    @ViewBuilder
    private func avatarLabel(_ effectiveUrl: String?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarView(urlString: effectiveUrl, size: 88)

            if isUpdatingAvatar {
                Circle()
                    .fill(.black.opacity(0.4))
                    .frame(width: 88, height: 88)
                ProgressView()
                    .tint(.white)
                    .offset(x: -33, y: -33)
            } else {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.wineAccent)
                    .background(Circle().fill(Color(.systemBackground)))
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        await loadProfile()
    }

    private func loadProfile() async {
        do {
            let profile = try await profileService.getProfile()
            username = profile.username
            appState.setCurrentUserAvatarUrl(profile.avatarUrl)
        } catch {
            // Non-critical
        }
    }

    /// Uploads a newly picked avatar image and refreshes the cached URL.
    private func uploadAvatar(_ item: PhotosPickerItem) async {
        isUpdatingAvatar = true
        defer { isUpdatingAvatar = false }

        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else {
            avatarError = "Couldn't load that photo. Try another one."
            return
        }

        do {
            let previousUrl = appState.currentUserAvatarUrl
            let profile = try await profileService.uploadAvatar(image)
            // Replacing the avatar produces a new object key, but evict the old cached
            // image so it can't linger in memory/disk.
            if let previousUrl, let url = URL(string: previousUrl) {
                ImageCache.shared.remove(for: url)
            }
            appState.setCurrentUserAvatarUrl(profile.avatarUrl)
        } catch {
            Log.error("Avatar upload failed", error: error)
            avatarError = "Couldn't update your photo. Please try again."
        }
    }

    /// Removes the current avatar and clears the cached URL.
    private func removeAvatar() async {
        isUpdatingAvatar = true
        defer { isUpdatingAvatar = false }

        do {
            let previousUrl = appState.currentUserAvatarUrl
            try await profileService.deleteAvatar()
            // Evict the deleted avatar from the image cache so it isn't served stale.
            if let previousUrl, let url = URL(string: previousUrl) {
                ImageCache.shared.remove(for: url)
            }
            appState.setCurrentUserAvatarUrl(nil)
        } catch {
            Log.error("Avatar removal failed", error: error)
            avatarError = "Couldn't remove your photo. Please try again."
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
