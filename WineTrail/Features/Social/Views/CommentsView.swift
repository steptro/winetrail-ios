import SwiftUI
import FirebaseAuth

/// Comments sheet for viewing and adding comments on a tasting.
struct CommentsView: View {
    @Environment(SocialService.self) private var socialService
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    let tastingId: String

    @State private var comments: [Components.Schemas.CommentDto] = []
    @State private var isLoading = false
    @State private var hasMorePages = true
    @State private var currentPage = 0
    @State private var newComment = ""
    @State private var isSending = false
    private let pageSize = 20

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Comments list
                if isLoading && comments.isEmpty {
                    Spacer()
                    WineGlassLoadingView()
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.right")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No comments yet")
                            .font(Theme.subheadlineFont)
                            .foregroundStyle(.secondary)
                        Text("Be the first to comment!")
                            .font(Theme.captionFont)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(comments, id: \.id) { comment in
                                commentRow(comment)
                                    .onAppear {
                                        if comment.id == comments.last?.id && hasMorePages {
                                            Task { await loadMoreComments() }
                                        }
                                    }
                            }
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .padding()
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 10) {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())

                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button {
                            Task { await sendComment() }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(newComment.isEmpty ? Color.secondary : Color.wineAccent)
                        }
                        .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .task {
            await loadComments()
        }
    }

    // MARK: - Comment Row

    @ViewBuilder
    private func commentRow(_ comment: Components.Schemas.CommentDto) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.author.displayName ?? comment.author.username)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(formatRelativeDate(comment.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(comment.body)
                    .font(.subheadline)
            }

            if isOwnComment(comment) {
                Button {
                    Task { await deleteComment(comment) }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isOwnComment(_ comment: Components.Schemas.CommentDto) -> Bool {
        guard let currentEmail = authService.currentUser?.email else { return false }
        return comment.author.email == currentEmail
    }

    private func deleteComment(_ comment: Components.Schemas.CommentDto) async {
        do {
            try await socialService.deleteComment(commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            Log.error("Failed to delete comment", error: error)
        }
    }

    // MARK: - Actions

    private func loadComments() async {
        isLoading = true
        currentPage = 0
        hasMorePages = true
        do {
            let result = try await socialService.getComments(tastingId: tastingId, page: 0, size: pageSize)
            comments = result.content
            hasMorePages = !result.isLast
            currentPage = 1
        } catch {
            Log.error("Failed to load comments", error: error)
        }
        isLoading = false
    }

    private func loadMoreComments() async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        do {
            let result = try await socialService.getComments(tastingId: tastingId, page: currentPage, size: pageSize)
            comments.append(contentsOf: result.content)
            hasMorePages = !result.isLast
            currentPage += 1
        } catch {
            Log.error("Failed to load more comments", error: error)
        }
        isLoading = false
    }

    private func sendComment() async {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true

        do {
            let comment = try await socialService.addComment(tastingId: tastingId, body: text)
            comments.append(comment)
            newComment = ""
            WineAnalytics.logComment(tastingId: tastingId)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            Log.error("Failed to add comment", error: error)
        }

        isSending = false
    }

    // MARK: - Helpers

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    CommentsView(tastingId: "preview-123")
        .environment(SocialService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
}
