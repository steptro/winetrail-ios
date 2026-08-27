import Foundation

/// Central configuration constants for the WineTrail app.
enum AppConfig {
    /// Base hostname for the WineTrail backend and website.
    static let hostname = "winetrail.stephantromer.dev"

    /// API base URL used for all backend requests.
    static let serverURL = URL(string: "https://\(hostname)")!

    /// Privacy Policy URL.
    static let privacyPolicyURL = URL(string: "https://\(hostname)/privacy-policy")!

    /// Terms of Service URL.
    static let termsOfServiceURL = URL(string: "https://\(hostname)/terms-of-service")!
}
