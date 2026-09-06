import Foundation
import Observation

/// Handles all social features: feed, friends, likes, and comments.
@Observable
final class SocialService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Social Feed

    /// Fetches the social feed (friends' tastings).
    func getFeed(page: Int = 0, size: Int = 20) async throws -> PagedResult<Components.Schemas.FeedJournalEntryDto> {
        let response = try await apiClient.client.getSocialFeed(
            query: .init(page: Int32(page), size: Int32(size))
        )
        let dto = try response.ok.body.json
        return PagedResult(
            content: dto.content ?? [],
            totalPages: Int(dto.page?.totalPages ?? 0),
            totalElements: Int(dto.page?.totalElements ?? 0),
            currentPage: Int(dto.page?.number ?? 0),
            isLast: Int(dto.page?.number ?? 0) >= Int(dto.page?.totalPages ?? 1) - 1
        )
    }

    // MARK: - User Search

    /// Searches for users by username or display name.
    func searchUsers(query: String) async throws -> [Components.Schemas.FriendUserDto] {
        let response = try await apiClient.client.searchUsers(
            query: .init(q: query)
        )
        return try response.ok.body.json
    }

    // MARK: - Friends

    /// Lists accepted friends.
    func getFriends() async throws -> [Components.Schemas.FriendshipDto] {
        let response = try await apiClient.client.getFriends()
        return try response.ok.body.json
    }

    /// Lists incoming pending friend requests.
    func getFriendRequests() async throws -> [Components.Schemas.FriendRequestDto] {
        let response = try await apiClient.client.getPendingRequests()
        return try response.ok.body.json
    }

    /// Lists outgoing pending friend requests.
    func getOutgoingRequests() async throws -> [Components.Schemas.FriendshipDto] {
        let response = try await apiClient.client.getOutgoingRequests()
        return try response.ok.body.json
    }

    /// Sends a friend request to a user.
    func sendFriendRequest(receiverId: String) async throws {
        _ = try await apiClient.client.sendFriendRequest(
            body: .json(.init(receiverId: receiverId))
        )
    }

    /// Accepts a friend request.
    func acceptFriendRequest(friendshipId: String) async throws {
        _ = try await apiClient.client.acceptFriendRequest(
            path: .init(friendshipId: friendshipId)
        )
    }

    /// Rejects a friend request.
    func rejectFriendRequest(friendshipId: String) async throws {
        _ = try await apiClient.client.rejectFriendRequest(
            path: .init(friendshipId: friendshipId)
        )
    }

    /// Removes a friend or cancels a request.
    func removeFriend(friendshipId: String) async throws {
        _ = try await apiClient.client.removeFriend(
            path: .init(friendshipId: friendshipId)
        )
    }

    // MARK: - Friend Notification Preferences

    /// Returns whether the current user is notified when this friend posts a new wine.
    func getFriendWineNotifications(friendshipId: String) async throws -> Bool {
        let response = try await apiClient.client.getFriendWineNotifications(
            path: .init(friendshipId: friendshipId)
        )
        return try response.ok.body.json.notifyOnNewWine
    }

    /// Enables or disables new-wine notifications for this friend. Returns the new value.
    @discardableResult
    func setFriendWineNotifications(friendshipId: String, notifyOnNewWine: Bool) async throws -> Bool {
        let response = try await apiClient.client.setFriendWineNotifications(
            path: .init(friendshipId: friendshipId),
            body: .json(.init(notifyOnNewWine: notifyOnNewWine))
        )
        return try response.ok.body.json.notifyOnNewWine
    }

    // MARK: - Likes

    /// Gets who liked a journal entry.
    func getLikes(tastingId: String) async throws -> [Components.Schemas.FriendUserDto] {
        let response = try await apiClient.client.getLikes(
            path: .init(entryId: tastingId)
        )
        return try response.ok.body.json
    }

    /// Likes a journal entry.
    func likeTasting(tastingId: String) async throws {
        _ = try await apiClient.client.likeEntry(
            path: .init(entryId: tastingId)
        )
    }

    /// Unlikes a journal entry.
    func unlikeTasting(tastingId: String) async throws {
        _ = try await apiClient.client.unlikeEntry(
            path: .init(entryId: tastingId)
        )
    }

    // MARK: - Comments

    /// Gets comments for a journal entry.
    func getComments(tastingId: String, page: Int = 0, size: Int = 50) async throws -> PagedResult<Components.Schemas.CommentDto> {
        let response = try await apiClient.client.getComments(
            path: .init(entryId: tastingId),
            query: .init(page: Int32(page), size: Int32(size))
        )
        let dto = try response.ok.body.json
        return PagedResult(
            content: dto.content ?? [],
            totalPages: Int(dto.page?.totalPages ?? 0),
            totalElements: Int(dto.page?.totalElements ?? 0),
            currentPage: Int(dto.page?.number ?? 0),
            isLast: Int(dto.page?.number ?? 0) >= Int(dto.page?.totalPages ?? 1) - 1
        )
    }

    /// Adds a comment to a journal entry.
    func addComment(tastingId: String, body: String) async throws -> Components.Schemas.CommentDto {
        let response = try await apiClient.client.addComment(
            path: .init(entryId: tastingId),
            body: .json(.init(body: body))
        )
        return try response.created.body.json
    }

    /// Deletes a comment.
    func deleteComment(commentId: String) async throws {
        _ = try await apiClient.client.deleteComment(
            path: .init(commentId: commentId)
        )
    }

    /// Likes a comment.
    func likeComment(commentId: String) async throws {
        _ = try await apiClient.client.likeComment(
            path: .init(commentId: commentId)
        )
    }

    /// Unlikes a comment.
    func unlikeComment(commentId: String) async throws {
        _ = try await apiClient.client.unlikeComment(
            path: .init(commentId: commentId)
        )
    }

    // MARK: - User Profile

    /// Fetches a user's public profile with stats and friendship status.
    func getUserProfile(userId: String) async throws -> Components.Schemas.PublicUserProfileDto {
        let response = try await apiClient.client.getUserProfile(
            path: .init(userId: userId)
        )
        return try response.ok.body.json
    }

    /// Fetches a user's tastings (requires friendship).
    func getUserTastings(userId: String, page: Int = 0, size: Int = 20) async throws -> PagedResult<Components.Schemas.FeedJournalEntryDto> {
        let response = try await apiClient.client.getUserTastings(
            path: .init(userId: userId),
            query: .init(page: Int32(page), size: Int32(size))
        )
        let dto = try response.ok.body.json
        return PagedResult(
            content: dto.content ?? [],
            totalPages: Int(dto.page?.totalPages ?? 0),
            totalElements: Int(dto.page?.totalElements ?? 0),
            currentPage: Int(dto.page?.number ?? 0),
            isLast: Int(dto.page?.number ?? 0) >= Int(dto.page?.totalPages ?? 1) - 1
        )
    }

    // MARK: - Shared Tastings

    /// Fetches every participant's rating for a shared tasting.
    /// Visible to any authenticated user who can see the post.
    func getSharedTastingRatings(sharedTastingId: String) async throws -> [Components.Schemas.SharedRatingDto] {
        let response = try await apiClient.client.getSharedTastingRatings(
            path: .init(sharedTastingId: sharedTastingId)
        )
        return try response.ok.body.json
    }

    /// Fetches wines the current user has been tagged in (paginated, most-recent first).
    func getTaggedEntries(page: Int = 0, size: Int = 20) async throws -> PagedResult<Components.Schemas.FeedJournalEntryDto> {
        let response = try await apiClient.client.getTaggedEntries(
            query: .init(page: Int32(page), size: Int32(size))
        )
        let dto = try response.ok.body.json
        return PagedResult(
            content: dto.content ?? [],
            totalPages: Int(dto.page?.totalPages ?? 0),
            totalElements: Int(dto.page?.totalElements ?? 0),
            currentPage: Int(dto.page?.number ?? 0),
            isLast: Int(dto.page?.number ?? 0) >= Int(dto.page?.totalPages ?? 1) - 1
        )
    }

    /// Count of tagged shared tastings the user has not yet rated (Social tab badge).
    func getUnratedTaggedCount() async throws -> Int {
        let response = try await apiClient.client.getUnratedTaggedCount()
        return Int(try response.ok.body.json.count)
    }

    /// Photos belonging to a shared tasting (across all participant entries), for reuse
    /// when adding your own rating.
    func getSharedTastingPhotos(sharedTastingId: String) async throws -> [Components.Schemas.PhotoUploadDto] {
        let response = try await apiClient.client.getSharedTastingPhotos(
            path: .init(sharedTastingId: sharedTastingId)
        )
        return try response.ok.body.json
    }
}
