import SwiftUI
import FirebaseAuth

/// Comments sheet for viewing and adding comments on a tasting.
///
/// All paging and comment mutations live in `CommentsViewModel`; this view owns only
/// UI state (the draft text, the sending spinner, haptics, and animation).
struct CommentsView: View {
    @Environment(SocialService.self) private var socialService
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    let tastingId: String

    @State private var viewModel: CommentsViewModel?
    @State private var newComment = ""
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let viewModel {
                    content(viewModel: viewModel)
                } else {
                    Spacer()
                    WineGlassLoadingView()
                    Spacer()
                }

                Divider()

                inputBar
            }
            .navigationTitle((viewModel?.totalComments ?? 0) > 0 ? "\(viewModel!.totalComments) Comments" : "Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .errorAlert(Binding(
            get: { viewModel?.errorMessage },
            set: { viewModel?.errorMessage = $0 }
        ))
        .task {
            if viewModel == nil {
                viewModel = CommentsViewModel(socialService: socialService, tastingId: tastingId)
            }
            await viewModel?.loadComments()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(viewModel: CommentsViewModel) -> some View {
        if viewModel.isLoading && viewModel.comments.isEmpty {
            Spacer()
            WineGlassLoadingView()
            Spacer()
        } else if viewModel.comments.isEmpty {
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
                    ForEach(viewModel.comments, id: \.id) { comment in
                        commentRow(comment)
                            .onAppear {
                                if viewModel.shouldLoadMore(after: comment) {
                                    Task { await viewModel.loadMoreComments() }
                                }
                            }
                    }
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Input Bar

    @ViewBuilder
    private var inputBar: some View {
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

    // MARK: - Comment Row

    @ViewBuilder
    private func commentRow(_ comment: Components.Schemas.CommentDto) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.author.username)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(formatRelativeDate(comment.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(comment.body)
                    .font(.subheadline)

                Button {
                    Task { await toggleLike(comment) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: comment.likedByMe ? "heart.fill" : "heart")
                            .foregroundStyle(comment.likedByMe ? Color.wineAccent : Color.secondary)
                        if comment.likeCount > 0 {
                            Text("\(comment.likeCount)")
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
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

    // MARK: - Actions (UI concerns; logic delegated to the view model)

    private func sendComment() async {
        guard let viewModel else { return }
        isSending = true
        let sent = await viewModel.sendComment(newComment)
        if sent {
            newComment = ""
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        isSending = false
    }

    private func deleteComment(_ comment: Components.Schemas.CommentDto) async {
        guard let viewModel else { return }
        await viewModel.deleteComment(comment)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func toggleLike(_ comment: Components.Schemas.CommentDto) async {
        guard let viewModel else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        await viewModel.toggleLike(comment)
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
            serverURL: AppConfig.serverURL,
            authService: AuthService()
        )))
}
