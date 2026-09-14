import SwiftUI

/// Public profile view shown when tapping another user's name/avatar.
/// Displays their stats, friendship status/actions, and tastings (if friends).
struct UserProfileView: View {
    @Environment(SocialService.self) private var socialService
    @Environment(ModerationService.self) private var moderationService
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: UserProfileViewModel?
    @State private var showRemoveConfirmation = false
    @State private var pendingNotifyValue: Bool?
    @State private var commentsTastingId: String?
    @State private var likesTastingId: String?
    @State private var reportTarget: ReportTarget?
    @State private var showBlockConfirmation = false
    @State private var toastMessage: String?

    let userId: String
    let username: String
    let displayName: String?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoadingProfile && viewModel.profile == nil {
                    WineGlassLoadingView()
                } else if viewModel.isUnavailable {
                    ContentUnavailableView(
                        "User Unavailable",
                        systemImage: "person.slash",
                        description: Text("This profile can't be shown.")
                    )
                } else if let profile = viewModel.profile {
                    profileContent(profile, viewModel: viewModel)
                } else if let error = viewModel.error {
                    ContentUnavailableView(
                        "Could not load profile",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text(error)
                    )
                }
            } else {
                WineGlassLoadingView()
            }
        }
        .navigationTitle(displayName ?? "@\(username)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let viewModel {
                    if viewModel.isFriend {
                        notificationBellToolbarItem(viewModel: viewModel)
                    }
                    friendshipToolbarItem(viewModel: viewModel)
                }
                Menu {
                    Button(role: .destructive) {
                        reportTarget = ReportTarget(
                            contentType: .user,
                            contentId: userId,
                            authorUserId: userId,
                            authorName: username
                        )
                    } label: {
                        Label("Report User", systemImage: "flag")
                    }
                    Button(role: .destructive) {
                        showBlockConfirmation = true
                    } label: {
                        Label("Block @\(username)", systemImage: "nosign")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More options")
            }
        }
        .sheet(item: $reportTarget) { target in
            ReportContentSheet(target: target, onReported: {
                toastMessage = "Thanks. Our team will review this within 24 hours."
            })
        }
        .alert("Block @\(username)?", isPresented: $showBlockConfirmation) {
            Button("Block", role: .destructive) { Task { await blockUser() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see their content and they won't be able to interact with you. This also reports them to our moderation team.")
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
            if viewModel == nil {
                viewModel = UserProfileViewModel(userId: userId, socialService: socialService)
            }
            await viewModel?.loadProfile()
            await viewModel?.loadTastings()
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(_ profile: Components.Schemas.PublicUserProfileDto, viewModel: UserProfileViewModel) -> some View {
        ScrollView {
            VStack(spacing: Theme.largeSpacing) {
                profileHeader(profile)
                    .padding(.horizontal, Theme.spacing)
                statsGrid(profile)
                    .padding(.horizontal, Theme.spacing)

                if viewModel.isFriend {
                    tastingsSection(viewModel: viewModel)
                } else if profile.friendshipStatus == .NONE {
                    notFriendsPlaceholder(viewModel: viewModel)
                        .padding(.horizontal, Theme.spacing)
                } else if viewModel.isPendingReceived {
                    pendingReceivedPlaceholder(viewModel: viewModel)
                        .padding(.horizontal, Theme.spacing)
                } else if viewModel.isPendingSent {
                    pendingSentPlaceholder
                        .padding(.horizontal, Theme.spacing)
                }
            }
            .padding(.bottom, Theme.largeSpacing)
        }
        .refreshable {
            await viewModel.loadProfile()
            if viewModel.isFriend {
                await viewModel.resetTastings()
            }
        }
        .sheet(item: $commentsTastingId) { tastingId in
            NavigationStack {
                CommentsView(tastingId: tastingId)
            }
        }
        .sheet(item: $likesTastingId) { tastingId in
            NavigationStack {
                LikesListView(tastingId: tastingId)
            }
        }
        .alert("Remove Friend", isPresented: $showRemoveConfirmation) {
            Button("Remove Friend", role: .destructive) {
                Task { await viewModel.removeFriend() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll no longer see each other's tastings.")
        }
        .alert(
            pendingNotifyValue == true ? "Turn on new wine alerts?" : "Turn off new wine alerts?",
            isPresented: Binding(
                get: { pendingNotifyValue != nil },
                set: { if !$0 { pendingNotifyValue = nil } }
            )
        ) {
            if let target = pendingNotifyValue {
                Button(target ? "Turn On" : "Turn Off") {
                    Task { await viewModel.setNotifyOnNewWine(target) }
                    pendingNotifyValue = nil
                }
                Button("Cancel", role: .cancel) { pendingNotifyValue = nil }
            }
        } message: {
            let name = profile.displayName ?? profile.username
            Text(pendingNotifyValue == true
                 ? "You'll be notified when \(name) adds a new wine."
                 : "You'll stop getting notified when \(name) adds a new wine.")
        }
    }

    // MARK: - Profile Header

    @ViewBuilder
    private func profileHeader(_ profile: Components.Schemas.PublicUserProfileDto) -> some View {
        VStack(spacing: Theme.smallSpacing) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.wineAccent)

            Text(profile.displayName ?? profile.username)
                .font(.title2.weight(.bold))
                .foregroundStyle(.wineText)

            Text("@\(profile.username)")
                .font(Theme.subheadlineFont)
                .foregroundStyle(.wineSecondaryText)

            if profile.friendshipStatus == .FRIENDS {
                Label("Friends", systemImage: "person.fill.checkmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.12), in: Capsule())
            }

            Text("Member since \(profile.memberSince.formatted(.dateTime.month(.wide).year()))")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        }
        .padding(.top, Theme.spacing)
    }

    // MARK: - Stats

    @ViewBuilder
    private func statsGrid(_ profile: Components.Schemas.PublicUserProfileDto) -> some View {
        HStack(spacing: 0) {
            statCell(value: "\(profile.totalTastings)", label: "Wines")
            Divider().frame(height: 32)
            statCell(value: "\(profile.uniqueWines)", label: "Unique")
            Divider().frame(height: 32)
            statCell(
                value: profile.averageRating.map { String(format: "%.1f", $0) } ?? "—",
                label: "Avg Rating"
            )
            Divider().frame(height: 32)
            statCell(value: "\(profile.friendCount)", label: "Friends")
        }
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.wineText)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Notification Bell Toolbar Item

    @ViewBuilder
    private func notificationBellToolbarItem(viewModel: UserProfileViewModel) -> some View {
        if viewModel.isUpdatingNotifications {
            ProgressView()
                .controlSize(.small)
        } else {
            Button {
                pendingNotifyValue = !viewModel.notifyOnNewWine
            } label: {
                Image(systemName: viewModel.notifyOnNewWine ? "bell.fill" : "bell")
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(viewModel.notifyOnNewWine ? "Turn off new wine alerts" : "Turn on new wine alerts")
            .tint(viewModel.notifyOnNewWine ? .wineAccent : nil)
        }
    }

    // MARK: - Friendship Toolbar Item

    @ViewBuilder
    private func friendshipToolbarItem(viewModel: UserProfileViewModel) -> some View {
        switch viewModel.profile?.friendshipStatus {
        case .NONE:
            if viewModel.isSendingRequest {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    Task { await viewModel.sendFriendRequest() }
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }

        case .PENDING_RECEIVED:
            Menu {
                Button {
                    Task { await viewModel.acceptFriendRequest() }
                } label: {
                    Label("Accept Request", systemImage: "checkmark")
                }
                Button(role: .destructive) {
                    Task { await viewModel.removeFriend() }
                } label: {
                    Label("Decline", systemImage: "xmark")
                }
            } label: {
                Image(systemName: "person.badge.clock")
                    .symbolRenderingMode(.multicolor)
            }

        case .PENDING_SENT:
            Menu {
                Button(role: .destructive) {
                    Task { await viewModel.removeFriend() }
                } label: {
                    Label("Cancel Request", systemImage: "xmark")
                }
            } label: {
                Image(systemName: "clock")
                    .foregroundStyle(.orange)
            }

        case .FRIENDS:
            Menu {
                Button(role: .destructive) {
                    showRemoveConfirmation = true
                } label: {
                    Label("Remove Friend", systemImage: "person.badge.minus")
                }
            } label: {
                Image(systemName: "person.fill.checkmark")
                    .foregroundStyle(.green)
            }

        case nil:
            EmptyView()
        }
    }

    // MARK: - Tastings Section

    @ViewBuilder
    private func tastingsSection(viewModel: UserProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Recent Tastings")
                .font(Theme.headlineFont)
                .foregroundStyle(.wineText)
                .padding(.horizontal, Theme.spacing)

            if viewModel.tastings.isEmpty && !viewModel.isLoadingTastings {
                Text("No tastings yet.")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.largeSpacing)
            } else {
                LazyVStack(spacing: Theme.spacing) {
                    ForEach(viewModel.tastings, id: \.id) { post in
                        SocialFeedPostView(
                            post: post,
                            onLike: { await viewModel.toggleLike(on: post) },
                            onComment: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                commentsTastingId = post.id
                            },
                            onLikesCount: { likesTastingId = post.id }
                        )
                        .task { await viewModel.onTastingAppear(post) }
                    }

                    if viewModel.isLoadingTastings {
                        WineGlassLoadingView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
        }
    }

    // MARK: - Placeholders

    private func notFriendsPlaceholder(viewModel: UserProfileViewModel) -> some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Add as a friend to see their tastings")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)

            if viewModel.isSendingRequest {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Button {
                    Task { await viewModel.sendFriendRequest() }
                } label: {
                    Label("Add Friend", systemImage: "person.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.wineAccent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.largeSpacing)
    }

    private func pendingReceivedPlaceholder(viewModel: UserProfileViewModel) -> some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "person.badge.clock")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Wants to be your friend")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)

            if viewModel.isSendingRequest {
                ProgressView()
                    .controlSize(.regular)
            } else {
                HStack(spacing: Theme.smallSpacing) {
                    Button {
                        Task { await viewModel.acceptFriendRequest() }
                    } label: {
                        Label("Accept", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(role: .destructive) {
                        Task { await viewModel.removeFriend() }
                    } label: {
                        Label("Decline", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.largeSpacing)
    }

    private var pendingSentPlaceholder: some View {
        VStack(spacing: Theme.smallSpacing) {
            Image(systemName: "hourglass")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Waiting for them to accept your request")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.largeSpacing)
    }

    // MARK: - Moderation

    private func blockUser() async {
        do {
            try await moderationService.blockUser(userId: userId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            toastMessage = "@\(username) has been blocked and reported."
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        } catch {
            Log.error("Failed to block user", error: error)
            toastMessage = "Couldn't block this user. Please try again."
        }
    }
}


#Preview {
    NavigationStack {
        UserProfileView(
            userId: "test-id",
            username: "stephan",
            displayName: "Stephan"
        )
        .environment(SocialService(apiClient: APIClient(
            serverURL: AppConfig.serverURL,
            authService: AuthService()
        )))
        .environment(ModerationService(
            apiClient: APIClient(serverURL: AppConfig.serverURL, authService: AuthService()),
            blockStore: BlockStore()
        ))
    }
}
