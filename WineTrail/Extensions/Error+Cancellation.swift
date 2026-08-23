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
        return description.contains("CancellationError")
    }
}
