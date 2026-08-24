import Foundation
import OpenAPIRuntime
import HTTPTypes

/// Middleware that retries transient network errors (timeouts, connectivity) with exponential backoff.
/// Only retries idempotent GET requests. Non-GET requests and client/server errors are not retried.
struct RetryMiddleware: ClientMiddleware {
    let maxRetries: Int
    let baseDelay: Duration

    init(maxRetries: Int = 2, baseDelay: Duration = .milliseconds(500)) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }

    func intercept(_ request: HTTPTypes.HTTPRequest, body: OpenAPIRuntime.HTTPBody?, baseURL: URL, operationID: String, next: @concurrent @Sendable (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
        // Only retry GET requests (idempotent)
        guard request.method == .get else {
            return try await next(request, body, baseURL)
        }

        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                let (response, responseBody) = try await next(request, body, baseURL)

                // Retry on 5xx server errors
                if response.status.code >= 500 && attempt < maxRetries {
                    let delay = baseDelay * Int(pow(2.0, Double(attempt)))
                    try await Task.sleep(for: delay)
                    continue
                }

                return (response, responseBody)
            } catch {
                lastError = error

                // Don't retry cancellation
                if error.isCancellation {
                    throw error
                }

                // Retry transient network errors
                if attempt < maxRetries {
                    let delay = baseDelay * Int(pow(2.0, Double(attempt)))
                    try await Task.sleep(for: delay)
                    continue
                }
            }
        }

        throw lastError!
    }
}
