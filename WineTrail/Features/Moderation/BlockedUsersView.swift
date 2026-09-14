import SwiftUI

/// Lists the users the current user has blocked and allows unblocking them.
/// Reachable from the Profile tab so users can manage and review their blocks.
struct BlockedUsersView: View {
    @Environment(ModerationService.self) private var moderationService

    @State private var blocked: [Components.Schemas.BlockedUserDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if blocked.isEmpty {
                ContentUnavailableView(
                    "No Blocked Users",
                    systemImage: "nosign",
                    description: Text("People you block won't be able to see or interact with your content, and you won't see theirs.")
                )
            } else {
                ForEach(blocked, id: \.id) { user in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName ?? user.username)
                                .font(.subheadline.weight(.medium))
                            Text("@\(user.username)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Unblock") {
                            Task { await unblock(user) }
                        }
                        .font(.subheadline.weight(.medium))
                        .buttonStyle(.bordered)
                        .tint(.wineAccent)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() async {
        isLoading = true
        do {
            blocked = try await moderationService.getBlockedUsers()
        } catch {
            Log.error("Failed to load blocked users", error: error)
            errorMessage = "Couldn't load your blocked users."
        }
        isLoading = false
    }

    private func unblock(_ user: Components.Schemas.BlockedUserDto) async {
        do {
            try await moderationService.unblockUser(userId: user.id)
            blocked.removeAll { $0.id == user.id }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            Log.error("Failed to unblock user", error: error)
            errorMessage = "Couldn't unblock this user. Please try again."
        }
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
            .environment(ModerationService(
                apiClient: APIClient(serverURL: AppConfig.serverURL, authService: AuthService()),
                blockStore: BlockStore()
            ))
    }
}
