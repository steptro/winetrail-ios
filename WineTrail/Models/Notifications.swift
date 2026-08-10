import Foundation

extension Notification.Name {
    /// Posted when a tasting is created, updated, or deleted.
    /// Observers should refresh their tasting-related data.
    static let tastingDidChange = Notification.Name("tastingDidChange")
}
