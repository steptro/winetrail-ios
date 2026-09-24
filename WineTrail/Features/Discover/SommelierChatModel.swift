import Foundation
import Observation

/// Drives the AI Sommelier chat: owns the transcript, the draft input, and the streaming lifecycle.
///
/// A conversation is created lazily on the first send, so opening the screen costs nothing until
/// the user actually asks something. Each send appends the user's turn, then an empty model turn
/// that fills in as deltas stream from `AssistantService`.
@MainActor
@Observable
final class SommelierChatModel {

    private(set) var messages: [AssistantMessage] = []
    var draft: String = ""
    private(set) var isStreaming = false
    private(set) var errorMessage: String?

    /// Set when a send is rejected with a 403 (Pro entitlement gone/absent). The view observes this
    /// to refresh subscription state — which flips the Pro gate to the locked/paywall view — rather
    /// than showing a generic error for what is really "you're no longer Pro".
    private(set) var entitlementLost = false

    private var assistant: AssistantService?
    private var conversationId: UUID?
    private var streamTask: Task<Void, Never>?

    /// The last user message we attempted to send, kept so a failed turn can be retried without
    /// the user retyping. Cleared once a turn completes successfully.
    private var lastUserText: String?

    /// True when the most recent turn failed and there is a message available to retry.
    private(set) var canRetry = false

    /// No delta for this long during a stream is treated as a stalled reply and fails the turn,
    /// so a hung SSE connection self-heals instead of spinning forever on the stop button.
    private static let streamStallTimeout: Duration = .seconds(30)

    /// Timestamp of the most recent streamed delta, read by the stall watchdog.
    private var lastDeltaAt: ContinuousClock.Instant = .now

    /// True when there is text to send and no reply is currently streaming.
    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    /// Binds the service; called from the view's `.task`. Safe to call repeatedly.
    func attach(_ assistant: AssistantService) {
        self.assistant = assistant
    }

    /// Resets to a fresh, empty conversation (a new thread is created lazily on the first send).
    func startNewChat() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        messages = []
        draft = ""
        errorMessage = nil
        conversationId = nil
        lastUserText = nil
        canRetry = false
    }

    /// Resumes an existing conversation: loads its transcript and continues sending into it.
    func resume(conversationId id: UUID) async {
        guard let assistant else { return }

        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        draft = ""
        errorMessage = nil
        lastUserText = nil
        canRetry = false

        do {
            let history = try await assistant.getConversation(id: id)
            messages = history
            conversationId = id
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? AssistantError.streamFailed.errorDescription
        }
    }

    /// Sends the current draft and starts streaming the reply.
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        send(text: text)
    }

    /// Sends an explicit message (used to seed a chat from outside the view, e.g. an
    /// "Ask the Sommelier about this wine" button). Clears the draft and streams the reply.
    func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming, let assistant else { return }

        draft = ""
        errorMessage = nil
        canRetry = false
        lastUserText = trimmed

        appendUserMessage(trimmed)
        let modelMessageId = appendModelPlaceholder()

        isStreaming = true
        streamTask = Task { await runTurn(assistant, text: trimmed, modelMessageId: modelMessageId) }
    }

    /// Re-sends the last message after a failed turn. The failed turn left the user's bubble in the
    /// transcript (and possibly no conversation, if creation itself failed); drop that trailing
    /// user turn so the retry re-appends it cleanly rather than duplicating it.
    func retryLastTurn() {
        guard !isStreaming, let text = lastUserText else { return }

        if let last = messages.last, last.role == .user, last.content == text {
            messages.removeLast()
        }

        send(text: text)
    }

    /// Stops the in-flight reply at the user's request, keeping whatever has streamed so far.
    /// If nothing streamed into the placeholder yet, the empty model bubble is removed so the
    /// transcript doesn't show a blank turn.
    func cancelStreaming() {
        guard isStreaming else { return }

        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        canRetry = false

        if let last = messages.last, last.role == .model, last.content.isEmpty {
            messages.removeLast()
        }
    }

    /// Ensures a conversation exists, then streams the reply into the placeholder turn.
    ///
    /// A watchdog races the stream: each delta pushes the deadline out, and if no delta arrives
    /// within `streamStallTimeout` the turn fails with `.timedOut` rather than streaming forever.
    private func runTurn(_ assistant: AssistantService, text: String, modelMessageId: UUID) async {
        do {
            let conversation = try await ensureConversation(assistant)

            try await withThrowingTaskGroup(of: Void.self) { group in
                // Producer: consume deltas, bumping the shared deadline on each one.
                group.addTask { @MainActor in
                    for try await delta in assistant.streamReply(conversationId: conversation, message: text) {
                        self.lastDeltaAt = ContinuousClock.now
                        self.appendDelta(delta, to: modelMessageId)
                    }
                }

                // Watchdog: fail the turn if the gap since the last delta exceeds the timeout.
                group.addTask { @MainActor in
                    self.lastDeltaAt = ContinuousClock.now
                    while true {
                        try await Task.sleep(for: .seconds(1))
                        if ContinuousClock.now - self.lastDeltaAt > Self.streamStallTimeout {
                            throw AssistantError.timedOut
                        }
                    }
                }

                // The producer finishes normally when the stream ends; cancel the watchdog then.
                // A thrown error (timeout or stream failure) propagates out of `next()`.
                try await group.next()
                group.cancelAll()
            }

            finishTurn(modelMessageId: modelMessageId)
        } catch {
            failTurn(error, modelMessageId: modelMessageId)
        }
    }

    /// Returns the existing conversation id or creates one on first use.
    private func ensureConversation(_ assistant: AssistantService) async throws -> UUID {
        if let conversationId { return conversationId }

        let created = try await assistant.createConversation()
        conversationId = created
        return created
    }

    // MARK: - Transcript mutation

    private func appendUserMessage(_ text: String) {
        messages.append(AssistantMessage(id: UUID(), role: .user, content: text, createdAt: Date()))
    }

    private func appendModelPlaceholder() -> UUID {
        let id = UUID()
        messages.append(AssistantMessage(id: id, role: .model, content: "", createdAt: Date()))
        return id
    }

    private func appendDelta(_ delta: String, to messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index].content += delta
    }

    private func finishTurn(modelMessageId: UUID) {
        isStreaming = false
        streamTask = nil

        // Drop an empty reply so the user sees the error state rather than a blank bubble.
        if let index = messages.firstIndex(where: { $0.id == modelMessageId }),
           messages[index].content.isEmpty {
            messages.remove(at: index)
            errorMessage = AssistantError.streamFailed.errorDescription
            canRetry = true
            return
        }

        // Successful reply: nothing left to retry.
        lastUserText = nil
        canRetry = false
    }

    private func failTurn(_ error: Error, modelMessageId: UUID) {
        isStreaming = false
        streamTask = nil

        // Remove the placeholder if nothing streamed into it, so no empty bubble lingers.
        if let index = messages.firstIndex(where: { $0.id == modelMessageId }),
           messages[index].content.isEmpty {
            messages.remove(at: index)
        }

        // A 403 means the Pro entitlement is gone/absent: signal the view to refresh subscription
        // state (surfacing the locked/paywall view) instead of showing a generic error line.
        if case AssistantError.notEntitled = error {
            entitlementLost = true
            return
        }

        errorMessage = (error as? LocalizedError)?.errorDescription ?? AssistantError.streamFailed.errorDescription
        canRetry = lastUserText != nil
    }
}
