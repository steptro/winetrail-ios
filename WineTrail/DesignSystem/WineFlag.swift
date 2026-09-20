import Foundation

/// Converts an ISO 3166-1 alpha-2 country code into its emoji flag.
enum WineFlag {
    /// Returns the emoji flag for a country code (e.g. "IT" → 🇮🇹), or an empty string if invalid.
    static func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}
