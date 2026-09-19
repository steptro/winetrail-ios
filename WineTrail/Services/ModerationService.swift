import Foundation
import Observation

/// Trust & Safety operations: reporting objectionable content and blocking abusive users.
///
/// This service backs the App Store Guideline 1.2 requirements:
/// - a mechanism to flag/report objectionable content,
/// - a mechanism to block abusive users that removes their content from the
///   feed instantly (via `BlockStore`) and notifies the developer (the block is
///   forwarded to the backend, which alerts the moderation team),
/// - the developer acts on reports within 24 hours on the server side.
@Observable
final class ModerationService {
    private let apiClient: APIClient
    private let blockStore: BlockStore

    init(apiClient: APIClient, blockStore: BlockStore) {
        self.apiClient = apiClient
        self.blockStore = blockStore
    }

    // MARK: - Reporting

    /// Reports objectionable content or an abusive user for moderation review.
    ///
    /// The backend routes the report to the moderation team, which acts within
    /// 24 hours by removing offending content and ejecting offending users.
    func report(target: ReportTarget, reason: ReportReason, details: String?) async throws {
        let trimmedDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await apiClient.client.reportContent(
            body: .json(.init(
                contentType: mapContentType(target.contentType),
                contentId: target.contentId,
                reportedUserId: target.authorUserId,
                reason: mapReason(reason),
                details: (trimmedDetails?.isEmpty == false) ? trimmedDetails : nil
            ))
        )
        Log.info("Submitted moderation report for \(target.contentType.rawValue) \(target.contentId)")
    }

    // MARK: - Blocking

    /// Blocks a user.
    ///
    /// The user's ID is added to the local `BlockStore` first so their content
    /// disappears from the feed immediately, then the block is persisted on the
    /// backend (which also notifies the moderation team). If the network call
    /// fails, the local block remains in effect and can be retried on next launch.
    func blockUser(userId: String) async throws {
        // Instant local removal from the feed.
        await MainActor.run { blockStore.addBlock(userId) }

        do {
            _ = try await apiClient.client.blockUser(
                body: .json(.init(blockedUserId: userId))
            )
            Log.info("Blocked user \(userId)")
        } catch {
            Log.error("Backend block failed; local block retained", error: error)
            throw error
        }
    }

    /// Unblocks a previously blocked user.
    func unblockUser(userId: String) async throws {
        _ = try await apiClient.client.unblockUser(path: .init(userId: userId))
        await MainActor.run { blockStore.removeBlock(userId) }
        Log.info("Unblocked user \(userId)")
    }

    /// Fetches the authoritative block list from the backend and refreshes the
    /// local store. Safe to call on launch. Failures are non-fatal (the local
    /// mirror keeps working).
    func refreshBlockedUsers() async {
        do {
            let response = try await apiClient.client.getBlockedUsers()
            let blocked = try response.ok.body.json
            let ids = blocked.map(\.id)
            await MainActor.run { blockStore.replaceAll(with: ids) }
        } catch {
            Log.error("Failed to refresh blocked users", error: error)
        }
    }

    /// Lists blocked users for the "Blocked Users" management screen.
    func getBlockedUsers() async throws -> [Components.Schemas.BlockedUserDto] {
        let response = try await apiClient.client.getBlockedUsers()
        return try response.ok.body.json
    }

    // MARK: - Mapping to generated enums

    private func mapContentType(_ type: ReportedContentType) -> Components.Schemas.ReportContentRequest.contentTypePayload {
        switch type {
        case .journalEntry: return .JOURNAL_ENTRY
        case .comment: return .COMMENT
        }
    }

    private func mapReason(_ reason: ReportReason) -> Components.Schemas.ReportContentRequest.reasonPayload {
        switch reason {
        case .harassment: return .HARASSMENT
        case .hateSpeech: return .HATE_SPEECH
        case .sexualContent: return .SEXUAL_CONTENT
        case .violence: return .VIOLENCE
        case .spam: return .SPAM
        case .other: return .OTHER
        }
    }
}
