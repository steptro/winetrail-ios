import SwiftUI

/// Friends' requests to join the current user's posts. Approving turns the post into a
/// shared tasting that includes the requester; rejecting is final for that person.
struct JoinRequestsView: View {
    @Environment(SocialService.self) private var socialService

    @State private var requests: [Components.Schemas.JoinRequestDto] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var actionErrorMessage: String?
    @State private var decidingIds: Set<String> = []

    var body: some View {
        Group {
            if isLoading && requests.isEmpty {
                WineGlassLoadingView()
            } else if error != nil, requests.isEmpty {
                ErrorStateView {
                    Task { await load() }
                }
            } else if requests.isEmpty {
                EmptyStateView(
                    icon: "person.badge.plus",
                    title: "No Join Requests",
                    message: "When a friend asks to join one of your posts, it shows up here."
                )
            } else {
                List {
                    ForEach(requests, id: \.id) { request in
                        requestRow(request)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Join Requests")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await Task { await load() }.value
        }
        .task {
            await load()
        }
        .alert("Couldn't Update Request", isPresented: Binding(
            get: { actionErrorMessage != nil },
            set: { if !$0 { actionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private func requestRow(_ request: Components.Schemas.JoinRequestDto) -> some View {
        let isDeciding = decidingIds.contains(request.id)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AvatarView(urlString: request.requester.avatarUrl, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(request.requester.displayName ?? request.requester.username)
                        .font(.body.weight(.medium))
                    Text("Wants to join your \(request.wine.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 12) {
                Button {
                    Task { await decide(request, approve: true) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("Approve")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.wineAccent)

                Button(role: .destructive) {
                    Task { await decide(request, approve: false) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("Reject")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .disabled(isDeciding)
        }
        .padding(.vertical, 6)
    }

    private func decide(_ request: Components.Schemas.JoinRequestDto, approve: Bool) async {
        decidingIds.insert(request.id)
        defer { decidingIds.remove(request.id) }

        do {
            if approve {
                try await socialService.approveJoinRequest(id: request.id)
            } else {
                try await socialService.rejectJoinRequest(id: request.id)
            }
            requests.removeAll { $0.id == request.id }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            Log.error("Failed to decide join request", error: error)
            actionErrorMessage = approve
                ? "Couldn't approve this request. Try again."
                : "Couldn't reject this request. Try again."
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            requests = try await socialService.getPendingJoinRequests().content
        } catch {
            Log.error("Failed to load join requests", error: error)
            self.error = error
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        JoinRequestsView()
            .environment(SocialService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
    }
}
