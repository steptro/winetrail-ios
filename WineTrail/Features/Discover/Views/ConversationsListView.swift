import SwiftUI

/// Sheet listing the user's past AI Sommelier conversations, most recent first.
/// Selecting one calls `onSelect` with its id so the chat screen can resume it.
struct ConversationsListView: View {
    @Environment(AssistantService.self) private var assistant
    @Environment(\.dismiss) private var dismiss

    let onSelect: (UUID) -> Void

    @State private var conversations: [AssistantConversation] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    ContentUnavailableView {
                        Label("Couldn't Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") { Task { await load() } }
                    }
                } else if conversations.isEmpty {
                    ContentUnavailableView(
                        "No Conversations",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Your past chats with the sommelier will appear here.")
                    )
                } else {
                    List(conversations) { conversation in
                        Button {
                            onSelect(conversation.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.displayTitle)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(conversation.updatedAt, format: .relative(presentation: .named))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            conversations = try await assistant.listConversations()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Please try again."
        }
        isLoading = false
    }
}
