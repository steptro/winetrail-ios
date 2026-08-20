import Foundation
import Observation
import OpenAPIRuntime
import OpenAPIURLSession

/// Wraps the generated OpenAPI `Client` with authentication middleware and a configurable base URL.
///
/// Usage:
/// ```swift
/// let apiClient = APIClient(
///     serverURL: URL(string: "https://api.winetrail.app")!,
///     authService: authService
/// )
/// let response = try await apiClient.client.getTimeline(...)
/// ```
@Observable
final class APIClient {
    /// The generated OpenAPI client, configured with auth middleware and URLSession transport.
    let client: Client

    /// Creates an API client pointing at the given server URL with automatic auth token injection.
    /// - Parameters:
    ///   - serverURL: The base URL of the WineTrail backend (e.g. `https://api.winetrail.app`).
    ///   - authService: The auth service used by the middleware to obtain Firebase ID tokens.
    init(serverURL: URL, authService: AuthService) {
        let middleware = AuthMiddleware(authService: authService)
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        let session = URLSession(configuration: configuration)
        self.client = Client(
            serverURL: serverURL,
            configuration: .init(dateTranscoder: ISO8601DateTranscoderWithFractionalSeconds()),
            transport: URLSessionTransport(configuration: .init(session: session)),
            middlewares: [middleware]
        )
    }
}

// MARK: - Date Transcoder

/// A date transcoder that decodes ISO 8601 strings with or without fractional seconds.
struct ISO8601DateTranscoderWithFractionalSeconds: DateTranscoder, @unchecked Sendable {
    private let formatterWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let formatterWithout: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func encode(_ date: Date) throws -> String {
        formatterWithFractional.string(from: date)
    }

    func decode(_ string: String) throws -> Date {
        if let date = formatterWithFractional.date(from: string) {
            return date
        }
        if let date = formatterWithout.date(from: string) {
            return date
        }
        throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "Expected ISO 8601 date string, got: \(string)")
        )
    }
}
