import Foundation

/// Represents a deep link destination parsed from a push notification payload.
enum DeepLink: Equatable {
    case tasting(id: String)
    /// A friend's post the current user was tagged in — opens the social detail page.
    case taggedPost(entryId: String)
    case friends
    /// A wine shared via a `winetrail-app.com/wines/{id}` universal link.
    case wine(id: String)

    /// Parses a push notification `userInfo` dictionary into a `DeepLink`.
    static func from(userInfo: [AnyHashable: Any]) -> DeepLink? {
        guard let type = userInfo["type"] as? String else { return nil }

        switch type {
        case "like", "comment", "comment_like", "friend_wine":
            guard let entryId = userInfo["entryId"] as? String else { return nil }
            return .tasting(id: entryId)
        case "tagged_in_post":
            guard let entryId = userInfo["entryId"] as? String else { return nil }
            return .taggedPost(entryId: entryId)
        case "friend_request", "friend_accepted":
            return .friends
        default:
            return nil
        }
    }

    /// Parses a universal link (e.g. `https://winetrail-app.com/wines/{id}`) into a `DeepLink`.
    ///
    /// Only recognises paths we host an Apple App Site Association entry for; unknown
    /// paths return `nil` so the system falls back to opening the link in the browser.
    static func from(url: URL) -> DeepLink? {
        let segments = url.pathComponents.filter { $0 != "/" }

        switch segments.first {
        case "wines" where segments.count >= 2:
            return .wine(id: segments[1])
        default:
            return nil
        }
    }
}
