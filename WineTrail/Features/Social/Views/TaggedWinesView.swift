import SwiftUI

/// A list of wines the current user has been tagged in by friends.
///
/// Tapping an entry opens the social detail page, where the user can see friend ratings
/// and add their own. Distinct from the journal — these are friends' posts, not the user's.
struct TaggedWinesView: View {
    @Environment(SocialService.self) private var socialService

    @State private var posts: [Components.Schemas.FeedJournalEntryDto] = []
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        Group {
            if isLoading && posts.isEmpty {
                WineGlassLoadingView()
            } else if error != nil, posts.isEmpty {
                ErrorStateView {
                    Task { await load() }
                }
            } else if posts.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No Tagged Wines",
                    message: "When a friend tags you in a wine, it shows up here so you can add your own rating."
                )
            } else {
                VStack(spacing: 0) {
                    Text("These are wines friends tagged you in that you haven't rated yet. Add your rating to share your take.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.spacing)
                        .padding(.top, Theme.smallSpacing)
                        .padding(.bottom, Theme.smallSpacing)

                    List {
                        ForEach(posts, id: \.id) { post in
                            NavigationLink {
                                SocialTastingDetailView(post: post)
                            } label: {
                                taggedRow(post)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Tagged Wines")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await Task { await load() }.value
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .task {
            await load()
        }
    }

    @ViewBuilder
    private func taggedRow(_ post: Components.Schemas.FeedJournalEntryDto) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "wineglass.fill")
                .font(.title3)
                .foregroundStyle(post.wine.color?.accentColor ?? .wineAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(post.wine.name + (post.vintage.map { " (\($0))" } ?? ""))
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("Tagged by \(post.user.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(post.participantCount) rating\(post.participantCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            let result = try await socialService.getTaggedEntries()
            posts = result.content
        } catch {
            Log.error("Failed to load tagged wines", error: error)
            self.error = error
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        TaggedWinesView()
            .environment(SocialService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
    }
}
