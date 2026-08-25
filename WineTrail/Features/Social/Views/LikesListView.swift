import SwiftUI

/// Shows who liked a tasting.
/// Note: Requires a GET /api/v1/social/tastings/{tastingId}/likes endpoint.
/// Currently shows a placeholder until the backend adds this endpoint.
struct LikesListView: View {
    @Environment(SocialService.self) private var socialService
    @Environment(\.dismiss) private var dismiss

    let tastingId: String

    @State private var likers: [Components.Schemas.FriendUserDto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        WineGlassLoadingView()
                        Spacer()
                    }
                } else if likers.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "heart")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No likes yet")
                            .font(Theme.subheadlineFont)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(likers, id: \.id) { user in
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.wineAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName ?? user.username)
                                    .font(.body.weight(.medium))
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Likes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .errorAlert($errorMessage)
        .task {
                await loadLikes()
            }
        }
        .presentationDetents([.medium])
    }

    private func loadLikes() async {
        isLoading = true
        do {
            likers = try await socialService.getLikes(tastingId: tastingId)
        } catch {
            Log.error("Failed to load likes", error: error)
            errorMessage = "Failed to load likes."
        }
        isLoading = false
    }
}

#Preview {
    LikesListView(tastingId: "preview-123")
        .environment(SocialService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
}
