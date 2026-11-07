import SwiftUI

/// Social feed showing friends' wine tastings with likes and comments.
struct SocialFeedView: View {
    @Environment(SocialService.self) private var socialService
    @Environment(SocialState.self) private var socialState
    @Environment(ModerationService.self) private var moderationService
    @Environment(BlockStore.self) private var blockStore
    @State private var viewModel: SocialFeedViewModel?
    @State private var commentsTastingId: String?
    @State private var likesTastingId: String?
    @State private var showAddFriend = false
    @State private var reportTarget: ReportTarget?
    @State private var toastMessage: String?
    @State private var menuDestination: SocialMenuDestination?

    /// Screens reachable from the social options menu.
    private enum SocialMenuDestination: Hashable {
        case taggedWines, friends, joinRequests, blockedUsers
    }

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.posts.isEmpty && viewModel.error != nil && !viewModel.isLoading {
                    ScrollView {
                        EmptyStateView(
                            icon: "exclamationmark.triangle",
                            title: "Couldn't Load Feed",
                            message: "Something went wrong loading your friends' wines. Pull to try again.",
                            actionLabel: Label("Retry", systemImage: "arrow.clockwise"),
                            action: { Task { await viewModel.loadInitial() } }
                        )
                    }
                    .refreshable {
                        await Task { await viewModel.loadInitial() }.value
                    }
                } else if viewModel.posts.isEmpty && !viewModel.isLoading {
                    ScrollView {
                        EmptyStateView(
                            icon: "person.2",
                            title: "No Friends Yet",
                            message: "Add friends to see their wine tastings here.",
                            actionLabel: Label("Add Friends", systemImage: "plus"),
                            action: { showAddFriend = true }
                        )
                    }
                    .refreshable {
                        await Task { await viewModel.loadInitial() }.value
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(viewModel.posts, id: \.id) { post in
                                NavigationLink {
                                    SocialTastingDetailView(post: post)
                                } label: {
                                    SocialFeedPostView(
                                        post: post,
                                        onLike: { await viewModel.toggleLike(on: post) },
                                        onComment: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            commentsTastingId = post.id
                                        },
                                        onLikesCount: { likesTastingId = post.id },
                                        onReport: {
                                            reportTarget = ReportTarget(
                                                contentType: .journalEntry,
                                                contentId: post.id,
                                                authorUserId: post.user.id,
                                                authorName: post.user.username
                                            )
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .task { await viewModel.onPostAppear(post) }
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
                    }
                }
            } else {
                WineGlassLoadingView()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        menuDestination = .taggedWines
                    } label: {
                        menuLabel("Tagged Wines", systemImage: "tag", count: socialState.taggedCount)
                    }
                    Button {
                        menuDestination = .friends
                    } label: {
                        menuLabel("Friends", systemImage: "person.2", count: socialState.pendingRequestCount)
                    }
                    Button {
                        menuDestination = .joinRequests
                    } label: {
                        menuLabel("Join Requests", systemImage: "person.badge.plus", count: socialState.joinRequestCount)
                    }
                    Button {
                        menuDestination = .blockedUsers
                    } label: {
                        Label("Blocked Users", systemImage: "nosign")
                    }
                } label: {
                    // Fixed frame so the badge anchors to the button's corner, not the glyph.
                    Image(systemName: "ellipsis")
                        .frame(width: 32, height: 32)
                        .overlay(alignment: .topTrailing) {
                            if socialState.socialBadgeCount > 0 {
                                Text("\(socialState.socialBadgeCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(.red, in: Capsule())
                                    .offset(x: 10, y: -10)
                            }
                        }
                }
                .accessibilityLabel("Social options")
                .accessibilityValue(socialState.socialBadgeCount > 0 ? "\(socialState.socialBadgeCount) pending" : "")
            }
        }
        .navigationDestination(item: $menuDestination) { destination in
            switch destination {
            case .taggedWines: TaggedWinesView()
            case .friends: FriendsView()
            case .joinRequests: JoinRequestsView()
            case .blockedUsers: BlockedUsersView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = SocialFeedViewModel(
                    socialService: socialService,
                    moderationService: moderationService,
                    blockStore: blockStore
                )
            }
            await viewModel?.loadInitial()
            await socialState.refresh()
        }
        .sheet(item: $commentsTastingId) { tastingId in
            CommentsView(tastingId: tastingId)
        }
        .sheet(item: $likesTastingId) { tastingId in
            LikesListView(tastingId: tastingId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendRequestsDidChange)) { _ in
            Task { await socialState.refreshPendingCount() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tastingDidChange)) { _ in
            Task { await socialState.refreshTaggedCount() }
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .taggedWinesDidChange)) { _ in
            Task { await socialState.refreshTaggedCount() }
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
    }

    /// Menu row whose icon carries a red count badge at the top right when something is
    /// waiting. Menus only draw plain images, so the badge is baked into the icon.
    @ViewBuilder
    private func menuLabel(_ title: String, systemImage: String, count: Int) -> some View {
        if count > 0 {
            Label {
                Text(title)
            } icon: {
                Image(uiImage: Self.badgedIcon(systemName: systemImage, count: count))
                    .renderingMode(.original)
            }
        } else {
            Label(title, systemImage: systemImage)
        }
    }

    /// Draws an SF Symbol with a red count badge in its top-right corner.
    private static func badgedIcon(systemName: String, count: Int) -> UIImage {
        let canvas = CGSize(width: 30, height: 26)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        let symbol = UIImage(systemName: systemName, withConfiguration: symbolConfig)?
            .withTintColor(.label, renderingMode: .alwaysOriginal)

        let image = UIGraphicsImageRenderer(size: canvas).image { _ in
            if let symbol {
                let origin = CGPoint(x: 0, y: (canvas.height - symbol.size.height) / 2 + 2)
                symbol.draw(at: origin)
            }

            let text = count > 99 ? "99+" : "\(count)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = (text as NSString).size(withAttributes: attributes)
            let badgeHeight: CGFloat = 15
            let badgeWidth = max(badgeHeight, textSize.width + 8)
            let badgeRect = CGRect(x: canvas.width - badgeWidth, y: 0, width: badgeWidth, height: badgeHeight)

            UIColor.systemRed.setFill()
            UIBezierPath(roundedRect: badgeRect, cornerRadius: badgeHeight / 2).fill()
            (text as NSString).draw(
                at: CGPoint(x: badgeRect.midX - textSize.width / 2, y: badgeRect.midY - textSize.height / 2),
                withAttributes: attributes
            )
        }

        return image.withRenderingMode(.alwaysOriginal)
    }
}

// MARK: - Make String identifiable for sheet

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - Social Feed Post

struct SocialFeedPostView: View {
    let post: Components.Schemas.FeedJournalEntryDto
    let onLike: () async -> Void
    let onComment: () -> Void
    let onLikesCount: () -> Void
    var onReport: (() -> Void)? = nil
    @State private var showHeartOverlay = false

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: post.createdAt, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User + date (above photo, Instagram-style)
            HStack {
                NavigationLink {
                    UserProfileView(
                        userId: post.user.id,
                        username: post.user.username,
                        displayName: post.user.displayName
                    )
                } label: {
                    HStack {
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
                if let onReport {
                    Menu {
                        Button(role: .destructive) {
                            onReport()
                        } label: {
                            Label("Report Post", systemImage: "flag")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("More options")
                }
            }
            .padding(.horizontal, Theme.spacing)
            .padding(.vertical, 10)

            // Photo
            if !post.photos.isEmpty {
                TabView {
                    ForEach(post.photos, id: \.id) { photo in
                        ZoomableScrollView(doubleTapToZoom: false) {
                            CachedAsyncImage(url: URL(string: photo.url)) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(.quaternary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: post.photos.count > 1 ? .automatic : .never))
                .frame(height: 420)
                .overlay {
                    if showHeartOverlay {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .onTapGesture(count: 2) {
                    Task {
                        if !post.likedByMe {
                            await onLike()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            showHeartOverlay = true
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        try? await Task.sleep(for: .milliseconds(800))
                        withAnimation { showHeartOverlay = false }
                    }
                }
            } else {
                WinePlaceholderView(color: post.wine.color, height: 120)
                    .overlay {
                        if showHeartOverlay {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 10)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .onTapGesture(count: 2) {
                        Task {
                            if !post.likedByMe {
                                await onLike()
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                showHeartOverlay = true
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            try? await Task.sleep(for: .milliseconds(800))
                            withAnimation { showHeartOverlay = false }
                        }
                    }
            }

            // Content below photo
            VStack(alignment: .leading, spacing: 10) {
                // Wine info
                HStack(spacing: 8) {
                    Image(systemName: "wineglass.fill")
                        .font(.title3)
                        .foregroundStyle(post.wine.color?.accentColor ?? .wineAccent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.wine.name + (post.vintage.map { " (\($0))" } ?? ""))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if let producer = post.wine.producer {
                            HStack(spacing: 4) {
                                if let country = post.wine.country, !country.isEmpty {
                                    Text(flag(for: country))
                                }
                                Text(producer)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                // Rating
                RatingView(rating: post.rating, starSize: .callout)

                // Notes
                if let notes = post.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Like + Comment bar
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Button {
                            Task { await onLike() }
                        } label: {
                            Image(systemName: post.likedByMe ? "heart.fill" : "heart")
                                .font(.body)
                                .foregroundStyle(post.likedByMe ? .red : .secondary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            onLikesCount()
                        } label: {
                            Text("\(post.likeCount)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        onComment()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.right")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Text("\(post.commentCount)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                // Shared tasting: who's tagged (tap the post to add your own rating)
                if post.sharedTastingId != nil, !post.taggedUsers.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.wineAccent)
                        Text("Tasted with " + post.taggedUsers
                            .map { $0.username }
                            .joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(Theme.spacing)
        }
        .background(Color(.systemBackground))
    }

    private func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}

#Preview {
    NavigationStack {
        SocialFeedView()
            .environment(SocialService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
            .environment(BlockStore())
            .environment(ModerationService(
                apiClient: APIClient(serverURL: AppConfig.serverURL, authService: AuthService()),
                blockStore: BlockStore()
            ))
    }
}
