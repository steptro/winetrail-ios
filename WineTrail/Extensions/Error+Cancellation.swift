import Foundation

extension Error {
    /// Returns `true` if this error represents a task cancellation,
    /// including when `CancellationError` is wrapped inside another error (e.g. `ClientError`).
    var isCancellation: Bool {
        if self is CancellationError {
            return true
        }
        // Check localizedDescription for wrapped cancellation errors from OpenAPI client
        let description = String(describing: self)
        if description.contains("CancellationError") {
            return true
        }
        // Google Sign-In user cancelled (GIDSignIn error code -5)
        let nsError = self as NSError
        if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
            return true
        }
        return false
    }
}
