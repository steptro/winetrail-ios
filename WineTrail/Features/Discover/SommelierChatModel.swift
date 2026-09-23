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

    private var assistant: AssistantService?
    private var conversationId: UUID?
    private var streamTask: Task<Void, Never>?

    /// True when there is text to send and no reply is currently streaming.
    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    /// Binds the service; called from the view's `.task`. Safe to call repeatedly.
    func attach(_ assistant: AssistantService) {
        self.assistant = assistant
    }

    /// Sends the current draft and starts streaming the reply.
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming, let assistant else { return }

        draft = ""
        errorMessage = nil

        appendUserMessage(text)
        let modelMessageId = appendModelPlaceholder()

        isStreaming = true
        streamTask = Task { await runTurn(assistant, text: text, modelMessageId: modelMessageId) }
    }

    /// Ensures a conversation exists, then streams the reply into the placeholder turn.
    private func runTurn(_ assistant: AssistantService, text: String, modelMessageId: UUID) async {
        do {
            let conversation = try await ensureConversation(assistant)

            for try await delta in assistant.streamReply(conversationId: conversation, message: text) {
                appendDelta(delta, to: modelMessageId)
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
        }
    }

    private func failTurn(_ error: Error, modelMessageId: UUID) {
        isStreaming = false
        streamTask = nil

        // Remove the placeholder if nothing streamed into it, so no empty bubble lingers.
        if let index = messages.firstIndex(where: { $0.id == modelMessageId }),
           messages[index].content.isEmpty {
            messages.remove(at: index)
        }

        errorMessage = (error as? LocalizedError)?.errorDescription ?? AssistantError.streamFailed.errorDescription
    }
}
