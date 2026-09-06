import SwiftUI

/// A reusable full-screen error state shown when a screen's data fails to load.
///
/// Built on `EmptyStateView` (which wraps `ContentUnavailableView`) so failed loads
/// look consistent with the empty states across Timeline, Wines, Map, and Stats —
/// but with a warning icon and a "Try Again" retry action instead of a "no data" nudge.
///
/// This exists so a network/load failure is never silently rendered as an empty state
/// ("No Wines Yet"), which would misrepresent a transient error as "you have no data".
///
/// The on-screen message is a friendly, generic line — never the raw `error.localizedDescription`,
/// which for the generated OpenAPI client is a large, technical dump. The underlying error is
/// still captured via `Log.error` at the call site for debugging.
struct ErrorStateView: View {
    /// Optional user-facing message. Defaults to a friendly generic line.
    var message: String = "Something went wrong. Pull to refresh or try again."
    /// Invoked when the user taps "Try Again".
    let retry: () -> Void

    var body: some View {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Couldn't Load",
            message: message,
            actionTitle: "Try Again",
            action: retry
        )
    }
}

#Preview {
    ErrorStateView(retry: {})
}
