import SwiftUI

/// Search users by username or display name and send friend requests.
struct AddFriendView: View {
    @Environment(SocialService.self) private var socialService
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [Components.Schemas.FriendUserDto] = []
    @State private var isSearching = false
    @State private var sentRequests: Set<String> = []
    @State private var sendingRequests: Set<String> = []
    @State private var existingFriendIds: Set<String> = []
    @State private var searchTask: Task<Void, Never>?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty && !isSearching && !query.isEmpty {
                    ContentUnavailableView(
                        "No users found",
                        systemImage: "person.slash",
                        description: Text("Try a different username or name.")
                    )
                } else {
                    ForEach(results, id: \.id) { user in
                        userRow(user)
                    }
                }

                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, isPresented: .constant(true), prompt: "Search by username or name")
            .onChange(of: query) { _, newValue in
                performSearch(query: newValue)
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .task {
                await loadExistingFriends()
            }
            .onAppear {
                Task { await loadExistingFriends() }
            }
            .errorAlert($errorMessage)
        }
    }

    // MARK: - Search

    private func performSearch(query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                let users = try await socialService.searchUsers(query: trimmed)
                guard !Task.isCancelled else { return }
                results = users
            } catch {
                guard !Task.isCancelled else { return }
                Log.error("User search failed", error: error)
                results = []
            }
            isSearching = false
        }
    }

    // MARK: - User Row

    @ViewBuilder
    private func userRow(_ user: Components.Schemas.FriendUserDto) -> some View {
        NavigationLink {
            UserProfileView(
                userId: user.id,
                username: user.username,
                displayName: user.displayName
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName ?? user.username)
                        .font(.body.weight(.medium))
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if existingFriendIds.contains(user.id) {
                    Label("Friends", systemImage: "person.fill.checkmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if sentRequests.contains(user.id) {
                    Label("Sent", systemImage: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if sendingRequests.contains(user.id) {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await sendRequest(to: user) }
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.wineAccent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Send Request

    private func sendRequest(to user: Components.Schemas.FriendUserDto) async {
        sendingRequests.insert(user.id)
        do {
            try await socialService.sendFriendRequest(receiverId: user.id)
            sentRequests.insert(user.id)
            WineAnalytics.logFriendRequestSent(receiverId: user.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            Log.error("Failed to send friend request", error: error)
            errorMessage = "Failed to send friend request. Please try again."
        }
        sendingRequests.remove(user.id)
    }

    private func loadExistingFriends() async {
        do {
            async let friendsResult = socialService.getFriends()
            async let outgoingResult = socialService.getOutgoingRequests()
            let friends = try await friendsResult
            let outgoing = try await outgoingResult
            existingFriendIds = Set(friends.map { $0.friend.id })
            sentRequests = Set(outgoing.map { $0.friend.id })
        } catch {
            Log.error("Failed to load friends list", error: error)
        }
    }
}

#Preview {
    AddFriendView()
        .environment(SocialService(apiClient: APIClient(
            serverURL: AppConfig.serverURL,
            authService: AuthService()
        )))
}
