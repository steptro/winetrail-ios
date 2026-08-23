import Foundation

/// Represents a deep link destination parsed from a push notification payload.
enum DeepLink: Equatable {
    case tasting(id: String)
    case friends

    /// Parses a push notification `userInfo` dictionary into a `DeepLink`.
    static func from(userInfo: [AnyHashable: Any]) -> DeepLink? {
        guard let type = userInfo["type"] as? String else { return nil }

        switch type {
        case "like", "comment":
            guard let tastingId = userInfo["tastingId"] as? String else { return nil }
            return .tasting(id: tastingId)
        case "friend_request", "friend_accepted":
            return .friends
        default:
            return nil
        }
    }
}
