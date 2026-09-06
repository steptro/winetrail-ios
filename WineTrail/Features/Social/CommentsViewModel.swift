import Foundation
import Observation
import SwiftUI

/// ViewModel for the comments sheet on a tasting.
///
/// Owns comment pagination (page cursor, `hasMorePages`, `isLoading`), the running
/// `totalComments` count shown in the sheet title, and the add/delete/like actions —
/// including the optimistic like toggle with rollback on failure.
///
/// Extracted from `CommentsView` so the last hand-rolled inline paginator lives in a
/// testable, `@Observable` view model like every other list screen.
@MainActor
@Observable
final class CommentsViewModel {
    private let socialService: SocialService
    private let tastingId: String
    private let pageSize: Int

    private(set) var comments: [Components.Schemas.CommentDto] = []
    private(set) var totalComments = 0
    private(set) var isLoading = false
    private(set) var hasMorePages = true
    /// The most recent user-facing error message; drives the error alert. Set to nil to dismiss.
    var errorMessage: String?

    private var currentPage = 0

    init(socialService: SocialService, tastingId: String, pageSize: Int = 20) {
        self.socialService = socialService
        self.tastingId = tastingId
        self.pageSize = pageSize
    }

    // MARK: - Loading

    /// Loads the first page of comments, resetting paging state.
    func loadComments() async {
        isLoading = true
        currentPage = 0
        hasMorePages = true
        do {
            let result = try await socialService.getComments(tastingId: tastingId, page: 0, size: pageSize)
            comments = result.content
            totalComments = result.totalElements
            hasMorePages = !result.isLast
            currentPage = 1
        } catch {
            Log.error("Failed to load comments", error: error)
            errorMessage = "Failed to load comments."
        }
        isLoading = false
    }

    /// Loads the next page when the last row appears, if more pages remain.
    func loadMoreComments() async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        do {
            let result = try await socialService.getComments(tastingId: tastingId, page: currentPage, size: pageSize)
            comments.append(contentsOf: result.content)
            hasMorePages = !result.isLast
            currentPage += 1
        } catch {
            Log.error("Failed to load more comments", error: error)
            errorMessage = "Failed to load more comments."
        }
        isLoading = false
    }

    /// True when `comment` is the last loaded row and more pages remain — used to trigger paging.
    func shouldLoadMore(after comment: Components.Schemas.CommentDto) -> Bool {
        comment.id == comments.last?.id && hasMorePages
    }

    // MARK: - Mutations

    /// Sends a new comment, appending it locally and bumping the total on success.
    /// Returns `true` when sent (so the view can clear its text field).
    @discardableResult
    func sendComment(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        do {
            let comment = try await socialService.addComment(tastingId: tastingId, body: trimmed)
            comments.append(comment)
            totalComments += 1
            WineAnalytics.logComment(tastingId: tastingId)
            return true
        } catch {
            Log.error("Failed to add comment", error: error)
            errorMessage = "Failed to send comment. Please try again."
            return false
        }
    }

    /// Deletes a comment, removing it locally and decrementing the total on success.
    func deleteComment(_ comment: Components.Schemas.CommentDto) async {
        do {
            try await socialService.deleteComment(commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
            totalComments = max(totalComments - 1, 0)
        } catch {
            Log.error("Failed to delete comment", error: error)
            errorMessage = "Failed to delete comment."
        }
    }

    /// Optimistically toggles a comment's like, rolling back on API failure.
    func toggleLike(_ comment: Components.Schemas.CommentDto) async {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        let wasLiked = comment.likedByMe
        let previousCount = comment.likeCount

        // Optimistic update
        withAnimation(.snappy) {
            comments[index].likedByMe = !wasLiked
            comments[index].likeCount = max(previousCount + (wasLiked ? -1 : 1), 0)
        }

        do {
            if wasLiked {
                try await socialService.unlikeComment(commentId: comment.id)
            } else {
                try await socialService.likeComment(commentId: comment.id)
            }
        } catch {
            Log.error("Failed to toggle comment like", error: error)
            guard let rollbackIndex = comments.firstIndex(where: { $0.id == comment.id }) else { return }
            withAnimation(.snappy) {
                comments[rollbackIndex].likedByMe = wasLiked
                comments[rollbackIndex].likeCount = previousCount
            }
            errorMessage = "Failed to update like."
        }
    }
}
