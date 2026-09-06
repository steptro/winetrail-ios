import SwiftUI

/// A reusable full-screen error state shown when a screen's data fails to load.
///
/// Built on `EmptyStateView` (which wraps `ContentUnavailableView`) so failed loads
/// look consistent with the empty states across Timeline, Wines, Map, and Stats —
/// but with a warning icon and a "Try Again" retry action instead of a "no data" nudge.
///
/// This exists so a network/load failure is never silently rendered as an empty state
/// ("No Wines Yet"), which would misrepresent a transient error as "you have no data".
struct ErrorStateView: View {
    /// The underlying error. Its `localizedDescription` is shown as the message.
    let error: Error
    /// Invoked when the user taps "Try Again".
    let retry: () -> Void

    var body: some View {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Couldn't Load",
            message: error.localizedDescription,
            actionTitle: "Try Again",
            action: retry
        )
    }
}

#Preview {
    ErrorStateView(
        error: NSError(
            domain: "WineTrail",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        ),
        retry: {}
    )
}
