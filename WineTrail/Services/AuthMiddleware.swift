import Foundation
import OpenAPIRuntime
import HTTPTypes

/// Transport middleware that attaches a Firebase ID token to every outgoing request
/// and retries exactly once on 401 responses with a force-refreshed token.
struct AuthMiddleware: ClientMiddleware {
    func intercept(_ request: HTTPTypes.HTTPRequest, body: OpenAPIRuntime.HTTPBody?, baseURL: URL, operationID: String, next: @concurrent @Sendable (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
        // 1. Get current cached token and attach Bearer header
        var authenticatedRequest = request
        let token = try await authService.getIDToken(forceRefresh: false)
        authenticatedRequest.headerFields[.authorization] = "Bearer \(token)"

        // 2. Send request
        let (response, responseBody) = try await next(authenticatedRequest, body, baseURL)

        // 3. On 401, force-refresh token and retry exactly once
        if response.status == .unauthorized {
            var retryRequest = request
            let freshToken = try await authService.getIDToken(forceRefresh: true)
            retryRequest.headerFields[.authorization] = "Bearer \(freshToken)"
            return try await next(retryRequest, body, baseURL)
        }

        return (response, responseBody)
    }
    
    let authService: AuthService
}
