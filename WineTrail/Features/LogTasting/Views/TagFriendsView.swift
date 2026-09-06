import SwiftUI

/// A multi-select sheet for tagging friends on a wine post.
///
/// Binds a set of friend user IDs. Tagging a friend lets them add their own rating to the
/// same wine (a shared tasting); it never writes into their journal. Only accepted friends
/// are taggable, so this lists the current user's friends.
struct TagFriendsView: View {
    @Environment(SocialService.self) private var socialService
    @Environment(\.dismiss) private var dismiss

    /// Selected friend user IDs, bound to the caller (e.g. the log-tasting view model).
    @Binding var selectedFriendIds: [String]

    @State private var friends: [Components.Schemas.FriendshipDto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""

    /// Cap mirrors the backend limit (max 20 tags per post).
    private let maxTags = 20

    /// Friends filtered by the search text (username, with display name as a fallback).
    private var filteredFriends: [Components.Schemas.FriendshipDto] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return friends }
        return friends.filter {
            $0.friend.username.lowercased().contains(query)
                || ($0.friend.displayName?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && friends.isEmpty {
                    WineGlassLoadingView()
                } else if friends.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No Friends Yet",
                        message: "Add friends to tag them when you log a wine."
                    )
                } else {
                    List {
                        Section {
                            if filteredFriends.isEmpty {
                                Text("No friends match \"\(searchText)\".")
                                    .font(Theme.captionFont)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(filteredFriends, id: \.id) { friendship in
                                    friendRow(friendship.friend)
                                }
                            }
                        } footer: {
                            Text("Tagged friends can add their own rating to this wine. You can tag up to \(maxTags) people.")
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "Search friends")
                }
            }
            .navigationTitle("Tag Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .errorAlert($errorMessage)
            .task {
                await loadFriends()
            }
        }
    }

    @ViewBuilder
    private func friendRow(_ friend: Components.Schemas.FriendUserDto) -> some View {
        let isSelected = selectedFriendIds.contains(friend.id)
        Button {
            toggle(friend.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.wineAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName ?? friend.username)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("@\(friend.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.wineAccent : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ friendId: String) {
        if let index = selectedFriendIds.firstIndex(of: friendId) {
            selectedFriendIds.remove(at: index)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            guard selectedFriendIds.count < maxTags else {
                errorMessage = "You can tag at most \(maxTags) people."
                return
            }
            selectedFriendIds.append(friendId)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func loadFriends() async {
        isLoading = true
        do {
            friends = try await socialService.getFriends()
        } catch {
            Log.error("Failed to load friends for tagging", error: error)
            errorMessage = "Failed to load friends."
        }
        isLoading = false
    }
}

#Preview {
    TagFriendsView(selectedFriendIds: .constant([]))
        .environment(SocialService(apiClient: APIClient(
            serverURL: AppConfig.serverURL,
            authService: AuthService()
        )))
}
