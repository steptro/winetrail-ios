import Foundation
import Observation

/// Locally-persisted set of user IDs the current user has blocked.
///
/// This exists so that blocked users' content can be filtered out of the feed
/// **instantly** — without waiting for a network round-trip or the next backend
/// refresh — which is required by App Store Guideline 1.2 (a block must remove
/// the abusive user's content from the feed immediately).
///
/// The authoritative list lives on the backend (see `ModerationService`); this
/// store is a fast local mirror. It is seeded from the server on launch and
/// updated optimistically whenever the user blocks/unblocks someone.
@MainActor
@Observable
final class BlockStore {
    private static let defaultsKey = "winetrail.blockedUserIDs"

    /// The set of blocked user IDs. Reading this drives UI filtering.
    private(set) var blockedUserIDs: Set<String>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.array(forKey: Self.defaultsKey) as? [String] ?? []
        self.blockedUserIDs = Set(stored)
    }

    /// Whether the given user ID is currently blocked.
    func isBlocked(_ userID: String?) -> Bool {
        guard let userID else { return false }
        return blockedUserIDs.contains(userID)
    }

    /// Optimistically records a block locally and notifies observers.
    func addBlock(_ userID: String) {
        guard !userID.isEmpty else { return }
        blockedUserIDs.insert(userID)
        persist()
        notifyChanged()
    }

    /// Removes a block locally and notifies observers.
    func removeBlock(_ userID: String) {
        blockedUserIDs.remove(userID)
        persist()
        notifyChanged()
    }

    /// Replaces the local set with the authoritative list from the backend.
    func replaceAll(with userIDs: [String]) {
        let newSet = Set(userIDs)
        guard newSet != blockedUserIDs else { return }
        blockedUserIDs = newSet
        persist()
        notifyChanged()
    }

    /// Clears all local block state (e.g. on sign-out).
    func clear() {
        guard !blockedUserIDs.isEmpty else { return }
        blockedUserIDs.removeAll()
        persist()
        notifyChanged()
    }

    // MARK: - Private

    private func persist() {
        defaults.set(Array(blockedUserIDs), forKey: Self.defaultsKey)
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .blockedUsersDidChange, object: nil)
    }
}
