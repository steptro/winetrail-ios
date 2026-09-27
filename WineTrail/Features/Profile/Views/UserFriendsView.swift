import SwiftUI

/// Lists a given user's friends (public). Each row opens that friend's profile,
/// so you can browse friends-of-friends. Reached by tapping the Friends stat on a
/// public profile.
struct UserFriendsView: View {
    @Environment(SocialService.self) private var socialService

    let userId: String
    let title: String

    @State private var friends: [Components.Schemas.FriendUserDto] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                WineGlassLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView(
                    "Couldn't load friends",
                    systemImage: "person.2.slash",
                    description: Text(error)
                )
            } else if friends.isEmpty {
                ContentUnavailableView(
                    "No friends yet",
                    systemImage: "person.2",
                    description: Text("This user hasn't added any friends.")
                )
            } else {
                List(friends, id: \.id) { friend in
                    NavigationLink {
                        UserProfileView(
                            userId: friend.id,
                            username: friend.username,
                            displayName: friend.displayName
                        )
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(urlString: friend.avatarUrl, size: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName ?? friend.username)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("@\(friend.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            friends = try await socialService.getUserFriends(userId: userId)
        } catch {
            Log.error("Failed to load user friends", error: error)
            self.error = "Please try again."
        }
        isLoading = false
    }
}
