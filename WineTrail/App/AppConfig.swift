import Foundation

/// Central configuration constants for the WineTrail app.
enum AppConfig {
    /// Base hostname for the WineTrail backend and website.
    static let hostname = "https://winetrail-app.com"
//    static let hostname = "http://localhost:8091"

    /// API base URL used for all backend requests.
    static let serverURL = URL(string: "\(hostname)")!

    /// Privacy Policy URL.
    static let privacyPolicyURL = URL(string: "\(hostname)/privacy-policy")!

    /// Terms of Service URL.
    static let termsOfServiceURL = URL(string: "\(hostname)/terms-of-service")!
}
