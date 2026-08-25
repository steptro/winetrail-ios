import SwiftUI

/// Friends management screen — segmented into Friends and Requests tabs.
struct FriendsView: View {
    @Environment(SocialService.self) private var socialService

    @State private var friends: [Components.Schemas.FriendshipDto] = []
    @State private var requests: [Components.Schemas.FriendRequestDto] = []
    @State private var outgoingRequests: [Components.Schemas.FriendshipDto] = []
    @State private var isLoading = false
    @State private var showAddFriend = false
    @State private var friendshipToRemove: Components.Schemas.FriendshipDto?
    @State private var errorMessage: String?
    @State private var selectedTab: FriendsTab = .friends

    private enum FriendsTab: String, CaseIterable {
        case friends = "Friends"
        case requests = "Requests"
    }

    private var requestsBadge: Int {
        requests.count + outgoingRequests.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("", selection: $selectedTab) {
                ForEach(FriendsTab.allCases, id: \.self) { tab in
                    if tab == .requests && requestsBadge > 0 {
                        Text("\(tab.rawValue) (\(requestsBadge))")
                            .tag(tab)
                    } else {
                        Text(tab.rawValue)
                            .tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.spacing)
            .padding(.vertical, Theme.smallSpacing)

            // Content
            switch selectedTab {
            case .friends:
                friendsList
            case .requests:
                requestsList
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
        .errorAlert($errorMessage)
    }

    // MARK: - Friends List

    private var friendsList: some View {
        List {
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
        .listStyle(.plain)
    }

    // MARK: - Requests List

    private var requestsList: some View {
        List {
            if !requests.isEmpty {
                Section("Incoming") {
                    ForEach(requests, id: \.id) { request in
                        requestRow(request)
                    }
                }
            }

            if !outgoingRequests.isEmpty {
                Section("Sent") {
                    ForEach(outgoingRequests, id: \.id) { request in
                        outgoingRow(request)
                    }
                }
            }

            if requests.isEmpty && outgoingRequests.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Requests",
                    systemImage: "person.badge.clock",
                    description: Text("Friend requests will appear here.")
                )
            }
        }
        .listStyle(.plain)
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
            errorMessage = "Failed to load friends."
        }
        isLoading = false
    }

    // MARK: - Row Views

    @ViewBuilder
    private func friendRow(_ friendship: Components.Schemas.FriendshipDto) -> some View {
        NavigationLink {
            UserProfileView(
                userId: friendship.friend.id,
                username: friendship.friend.username,
                displayName: friendship.friend.displayName
            )
        } label: {
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
        NavigationLink {
            UserProfileView(
                userId: request.sender.id,
                username: request.sender.username,
                displayName: request.sender.displayName
            )
        } label: {
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
            }
        }
    }

    @ViewBuilder
    private func outgoingRow(_ request: Components.Schemas.FriendshipDto) -> some View {
        NavigationLink {
            UserProfileView(
                userId: request.friend.id,
                username: request.friend.username,
                displayName: request.friend.displayName
            )
        } label: {
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
            errorMessage = "Failed to accept request. Please try again."
        }
    }

    private func rejectRequest(friendshipId: String) async {
        do {
            try await socialService.rejectFriendRequest(friendshipId: friendshipId)
            await loadData()
            NotificationCenter.default.post(name: .friendRequestsDidChange, object: nil)
        } catch {
            Log.error("Failed to reject friend request", error: error)
            errorMessage = "Failed to reject request."
        }
    }

    private func removeFriend(friendshipId: String) async {
        do {
            try await socialService.removeFriend(friendshipId: friendshipId)
            friends.removeAll { $0.id == friendshipId }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            Log.error("Failed to remove friend", error: error)
            errorMessage = "Failed to remove friend."
        }
    }

    private func cancelOutgoingRequest(friendshipId: String) async {
        do {
            try await socialService.removeFriend(friendshipId: friendshipId)
            outgoingRequests.removeAll { $0.id == friendshipId }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            Log.error("Failed to cancel friend request", error: error)
            errorMessage = "Failed to cancel request."
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
