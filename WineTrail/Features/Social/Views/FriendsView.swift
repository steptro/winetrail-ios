import SwiftUI

/// Friends management screen — list friends, view/accept/reject requests, search and add users.
struct FriendsView: View {
    @Environment(SocialService.self) private var socialService

    @State private var friends: [Components.Schemas.FriendshipDto] = []
    @State private var requests: [Components.Schemas.FriendRequestDto] = []
    @State private var outgoingRequests: [Components.Schemas.FriendshipDto] = []
    @State private var isLoading = false
    @State private var showAddFriend = false
    @State private var friendshipToRemove: Components.Schemas.FriendshipDto?
    @State private var selectedRequest: Components.Schemas.FriendRequestDto?

    var body: some View {
        List {
            // Pending incoming requests section
            if !requests.isEmpty {
                Section("Friend Requests") {
                    ForEach(requests, id: \.id) { request in
                        requestRow(request)
                    }
                }
            }

            // Outgoing pending requests section
            if !outgoingRequests.isEmpty {
                Section("Sent Requests") {
                    ForEach(outgoingRequests, id: \.id) { request in
                        outgoingRow(request)
                    }
                }
            }

            // Friends list
            Section("Friends (\(friends.count))") {
                if friends.isEmpty && !isLoading {
                    Text("No friends yet. Add someone to get started!")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(friends, id: \.id) { friendship in
                        friendRow(friendship)
                    }
                }
            }
        }
        .navigationTitle("Friends")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddFriend = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .refreshable {
            await Task {
                await loadData()
                NotificationCenter.default.post(name: .friendRequestsDidChange, object: nil)
            }.value
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendView()
        }
        .alert(
            "Remove Friend",
            isPresented: Binding(
                get: { friendshipToRemove != nil },
                set: { if !$0 { friendshipToRemove = nil } }
            )
        ) {
            Button("Remove", role: .destructive) {
                if let friendship = friendshipToRemove {
                    Task { await removeFriend(friendshipId: friendship.id) }
                }
            }
            Button("Cancel", role: .cancel) {
                friendshipToRemove = nil
            }
        } message: {
            if let friendship = friendshipToRemove {
                Text("Are you sure you want to remove \(friendship.friend.displayName ?? friendship.friend.username) as a friend?")
            }
        }
        .confirmationDialog(
            selectedRequest.map { "Friend request from \($0.sender.displayName ?? $0.sender.username)" } ?? "Friend Request",
            isPresented: Binding(
                get: { selectedRequest != nil },
                set: { if !$0 { selectedRequest = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Accept") {
                if let request = selectedRequest {
                    Task { await acceptRequest(friendshipId: request.id) }
                }
            }
            Button("Reject", role: .destructive) {
                if let request = selectedRequest {
                    Task { await rejectRequest(friendshipId: request.id) }
                }
            }
            Button("Cancel", role: .cancel) {
                selectedRequest = nil
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        do {
            async let friendsResult = socialService.getFriends()
            async let requestsResult = socialService.getFriendRequests()
            async let outgoingResult = socialService.getOutgoingRequests()
            friends = try await friendsResult
            requests = try await requestsResult
            outgoingRequests = try await outgoingResult
        } catch {
            Log.error("Failed to load friends", error: error)
        }
        isLoading = false
    }

    // MARK: - Row Views

    @ViewBuilder
    private func friendRow(_ friendship: Components.Schemas.FriendshipDto) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.wineAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(friendship.friend.displayName ?? friendship.friend.username)
                    .font(.body.weight(.medium))
                Text("@\(friendship.friend.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                friendshipToRemove = friendship
            } label: {
                Label("Remove", systemImage: "person.badge.minus")
            }
        }
    }

    @ViewBuilder
    private func requestRow(_ request: Components.Schemas.FriendRequestDto) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle")
                .font(.title2)
                .foregroundStyle(.wineAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.sender.displayName ?? request.sender.username)
                    .font(.body.weight(.medium))
                Text("@\(request.sender.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedRequest = request
        }
    }

    @ViewBuilder
    private func outgoingRow(_ request: Components.Schemas.FriendshipDto) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.friend.displayName ?? request.friend.username)
                    .font(.body.weight(.medium))
                Text("@\(request.friend.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Pending")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await cancelOutgoingRequest(friendshipId: request.id) }
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
        }
    }

    // MARK: - Actions

    private func acceptRequest(friendshipId: String) async {
        do {
            try await socialService.acceptFriendRequest(friendshipId: friendshipId)
            WineAnalytics.logFriendRequestAccepted()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await loadData()
            NotificationCenter.default.post(name: .friendRequestsDidChange, object: nil)
        } catch {
            Log.error("Failed to accept friend request", error: error)
        }
    }

    private func rejectRequest(friendshipId: String) async {
        do {
            try await socialService.rejectFriendRequest(friendshipId: friendshipId)
            await loadData()
            NotificationCenter.default.post(name: .friendRequestsDidChange, object: nil)
        } catch {
            Log.error("Failed to reject friend request", error: error)
        }
    }

    private func removeFriend(friendshipId: String) async {
        do {
            try await socialService.removeFriend(friendshipId: friendshipId)
            friends.removeAll { $0.id == friendshipId }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            Log.error("Failed to remove friend", error: error)
        }
    }

    private func cancelOutgoingRequest(friendshipId: String) async {
        do {
            try await socialService.removeFriend(friendshipId: friendshipId)
            outgoingRequests.removeAll { $0.id == friendshipId }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            Log.error("Failed to cancel friend request", error: error)
        }
    }
}

#Preview {
    NavigationStack {
        FriendsView()
            .environment(SocialService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
