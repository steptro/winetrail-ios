import Foundation

extension Notification.Name {
    /// Posted when a tasting is created, updated, or deleted.
    /// Observers should refresh their tasting-related data.
    static let tastingDidChange = Notification.Name("tastingDidChange")

    /// Posted when friend requests change (e.g. new incoming request via silent push).
    /// Observers should refresh friend request counts and lists.
    static let friendRequestsDidChange = Notification.Name("friendRequestsDidChange")
}
