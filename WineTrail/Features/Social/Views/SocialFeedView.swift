import SwiftUI

/// Social feed showing friends' wine tastings with likes and comments.
struct SocialFeedView: View {
    @Environment(SocialService.self) private var socialService
    @Environment(SocialState.self) private var socialState
    @State private var viewModel: SocialFeedViewModel?
    @State private var commentsTastingId: String?
    @State private var likesTastingId: String?
    @State private var showAddFriend = false

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.posts.isEmpty && !viewModel.isLoading {
                    ScrollView {
                        EmptyStateView(
                            icon: "person.2",
                            title: "No Friends Yet",
                            message: "Add friends to see their wine tastings here.",
                            actionTitle: "Add Friends",
                            action: { showAddFriend = true }
                        )
                    }
                    .refreshable {
                        await Task { await viewModel.loadInitial() }.value
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(viewModel.posts, id: \.id) { post in
                                SocialFeedPostView(
                                    post: post,
                                    onLike: { await viewModel.toggleLike(on: post) },
                                    onComment: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        commentsTastingId = post.id
                                    },
                                    onLikesCount: { likesTastingId = post.id }
                                )
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
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            } else {
                WineGlassLoadingView()
            }
        }
        .navigationTitle("Social")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    FriendsView()
                } label: {
                    Image(systemName: "person.2")
                        .overlay(alignment: .topTrailing) {
                            if socialState.pendingRequestCount > 0 {
                                Text("\(socialState.pendingRequestCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(.red, in: Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = SocialFeedViewModel(socialService: socialService)
            }
            await viewModel?.loadInitial()
            await socialState.refreshPendingCount()
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
        .sheet(isPresented: $showAddFriend) {
            AddFriendView()
        }
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
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text(post.user.displayName ?? post.user.username)
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
            .padding(.horizontal, Theme.spacing)
            .padding(.vertical, 10)

            // Photo
            if !post.photos.isEmpty {
                TabView {
                    ForEach(post.photos, id: \.id) { photo in
                        CachedAsyncImage(url: URL(string: photo.url)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(.quaternary)
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: post.photos.count > 1 ? .automatic : .never))
                .frame(height: 300)
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
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
