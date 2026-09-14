import Foundation
import Observation

/// Tracks whether the user has accepted the End User License Agreement (EULA) /
/// Terms of Use, including the zero-tolerance policy for objectionable content and
/// abusive behavior.
///
/// Apple Guideline 1.2 requires that users agree to terms making clear there is no
/// tolerance for objectionable content or abusive users *before* they can use the
/// user-generated-content features. Acceptance is recorded per terms version so a
/// future material change to the terms can re-prompt existing users.
@MainActor
@Observable
final class AgreementStore {
    /// Bump when the EULA text changes materially to re-prompt all users.
    static let currentTermsVersion = 1

    private static let versionKey = "winetrail.acceptedTermsVersion"

    private let defaults: UserDefaults

    /// Whether the user has accepted the current version of the terms.
    private(set) var hasAcceptedCurrentTerms: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let accepted = defaults.integer(forKey: Self.versionKey)
        self.hasAcceptedCurrentTerms = accepted >= Self.currentTermsVersion
    }

    /// Records acceptance of the current terms version.
    func accept() {
        defaults.set(Self.currentTermsVersion, forKey: Self.versionKey)
        hasAcceptedCurrentTerms = true
    }

#if DEBUG
    /// Clears the recorded acceptance so the agreement gate is shown again.
    ///
    /// Debug builds only — used to re-test the EULA acceptance flow without
    /// reinstalling the app.
    func reset() {
        defaults.removeObject(forKey: Self.versionKey)
        hasAcceptedCurrentTerms = false
    }
#endif
}
