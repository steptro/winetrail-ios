import Foundation
import Observation

/// A single turn in an assistant conversation.
struct AssistantMessage: Identifiable, Sendable, Equatable {
    enum Role: String, Sendable {
        case user = "USER"
        case model = "MODEL"
    }

    let id: UUID
    let role: Role
    var content: String
    let createdAt: Date
}

/// Errors surfaced by the assistant streaming client.
enum AssistantError: LocalizedError {
    case badResponse(status: Int)
    case streamFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .badResponse(let status):
            return "The assistant returned an unexpected response (\(status))."
        case .streamFailed:
            return "The assistant is unavailable. Please try again."
        case .notAuthenticated:
            return "You need to be signed in to use the assistant."
        }
    }
}

/// Client for the wine-assistant chat backend (`/api/v1/assistant`).
///
/// Conversation creation is plain JSON; sending a message streams the model's reply back over
/// Server-Sent Events. The generated OpenAPI client cannot model the SSE stream, so this service
/// issues its own authenticated `URLSession` requests, reusing `AuthService` for the Firebase
/// bearer token and `AppConfig.serverURL` for the base URL.
@MainActor
@Observable
final class AssistantService {

    /// SSE event name for an incremental reply chunk.
    private static let eventDelta = "delta"
    /// SSE event name signalling the reply is complete.
    private static let eventDone = "done"
    /// SSE event name signalling the turn failed.
    private static let eventError = "error"

    private let authService: AuthService
    private let baseURL: URL
    private let session: URLSession

    init(authService: AuthService, baseURL: URL = AppConfig.serverURL) {
        self.authService = authService
        self.baseURL = baseURL

        // Streaming replies can outlast the short default request timeout, so give the resource a
        // generous budget while keeping connection setup snappy.
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Conversation lifecycle

    /// Starts a new conversation and returns its id.
    func createConversation() async throws -> UUID {
        var request = try await authorizedRequest(path: "/api/v1/assistant/conversations", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try Self.ensureSuccess(response, body: data, context: "createConversation")

        let detail = try Self.jsonDecoder.decode(ConversationDetailResponse.self, from: data)
        return detail.id
    }

    // MARK: - Streaming

    /// Sends a user message and streams the assistant's reply as text deltas.
    ///
    /// The returned `AsyncThrowingStream` yields each incremental chunk in order and finishes when
    /// the backend emits its `done` event. An `error` event or a transport failure finishes the
    /// stream with `AssistantError`.
    func streamReply(conversationId: UUID, message: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.runStream(conversationId: conversationId, message: message, continuation: continuation)
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Issues the SSE request and forwards each parsed `delta` event into the continuation.
    private func runStream(
        conversationId: UUID,
        message: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let path = "/api/v1/assistant/conversations/\(conversationId.uuidString)/messages"
        var request = try await authorizedRequest(path: path, method: "POST")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.jsonEncoder.encode(SendMessageBody(message: message))

        let (bytes, response) = try await session.bytes(for: request)

        // On a non-2xx, read the (small) error body from the byte stream for the log before throwing.
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            var errorBody = ""
            for try await line in bytes.lines { errorBody += line + "\n"; if errorBody.count > 2000 { break } }
            Log.error("Assistant sendMessage failed: status=\(http.statusCode) body=\(errorBody)")
            if http.statusCode == 401 { throw AssistantError.notAuthenticated }
            throw AssistantError.badResponse(status: http.statusCode)
        }

        // Parse the SSE stream line by line: an event is a run of `event:`/`data:` lines
        // terminated by a blank line.
        var eventName = ""
        var dataLines: [String] = []

        // The backend does not always emit blank-line separators between events, so we cannot rely
        // on an empty line as the boundary. Instead, a new `event:` line flushes the PREVIOUS event;
        // `data:` lines accumulate into the current event; a blank line (when present) also flushes.
        for try await rawLine in bytes.lines {
            let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine

            if line.hasPrefix("event:") {
                // Starting a new event: flush whatever we accumulated for the previous one.
                if !eventName.isEmpty {
                    try Self.dispatchEvent(eventName, dataLines, into: continuation)
                }
                eventName = Self.fieldValue(line, prefix: "event:")
                dataLines = []
            } else if line.hasPrefix("data:") {
                // Do NOT strip the SSE leading space here: the backend emits token chunks like
                // " I'm" / " pair" and relies on that space being preserved. Dropping it fuses
                // words together ("Hello!" + "I'm" -> "Hello!I'm"). Only remove the "data:" prefix.
                dataLines.append(String(line.dropFirst("data:".count)))
            } else if line.isEmpty {
                if !eventName.isEmpty {
                    try Self.dispatchEvent(eventName, dataLines, into: continuation)
                    eventName = ""
                    dataLines = []
                }
            }
        }

        // Flush the final event, then finish.
        try Self.dispatchEvent(eventName, dataLines, into: continuation)
        continuation.finish()
    }

    /// Emits a parsed SSE event, throwing on an `error` event and finishing on `done`.
    private static func dispatchEvent(
        _ name: String,
        _ dataLines: [String],
        into continuation: AsyncThrowingStream<String, Error>.Continuation
    ) throws {
        guard !name.isEmpty else { return }

        switch name {
        case eventDelta:
            let text = dataLines.joined(separator: "\n")
            if !text.isEmpty { continuation.yield(text) }
        case eventDone:
            continuation.finish()
        case eventError:
            throw AssistantError.streamFailed
        default:
            break
        }
    }

    // MARK: - Request building

    /// Builds a bearer-authenticated request for the given path.
    private func authorizedRequest(path: String, method: String) async throws -> URLRequest {
        let token = try await authService.getIDToken(forceRefresh: false)

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return request
    }

    // MARK: - Helpers

    /// Strips an SSE field prefix and the single optional leading space per the SSE spec.
    private static func fieldValue(_ line: String, prefix: String) -> String {
        var value = String(line.dropFirst(prefix.count))
        if value.hasPrefix(" ") { value.removeFirst() }
        return value
    }

    private static func ensureSuccess(_ response: URLResponse, body: Data? = nil, context: String = "") throws {
        guard let http = response as? HTTPURLResponse else {
            Log.error("Assistant \(context): non-HTTP response")
            throw AssistantError.streamFailed
        }
        guard (200...299).contains(http.statusCode) else {
            let bodyText = body.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
            Log.error("Assistant \(context) failed: status=\(http.statusCode) body=\(bodyText)")
            if http.statusCode == 401 { throw AssistantError.notAuthenticated }
            throw AssistantError.badResponse(status: http.statusCode)
        }
    }

    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private static let jsonEncoder = JSONEncoder()

    // MARK: - Wire types

    private struct SendMessageBody: Encodable {
        let message: String
    }

    private struct ConversationDetailResponse: Decodable {
        let id: UUID
    }
}
