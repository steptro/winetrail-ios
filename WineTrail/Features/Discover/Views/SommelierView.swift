import SwiftUI
import RevenueCatUI

/// AI Sommelier — a multi-turn wine chat backed by the assistant endpoint.
///
/// This is a top-level tab, so the paywall here is the PRIMARY Pro gate: once entitlement state
/// has resolved, a non-subscriber is shown the paywall and a subscriber sees the chat. The gate
/// is driven by our own resolved `isPro` (via PaywallBackstop) so it never flashes for a
/// subscriber during the initial loading window.
struct SommelierView: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(AssistantService.self) private var assistant

    @State private var model = SommelierChatModel()
    @State private var showConversations = false

    var body: some View {
        chat
            .navigationTitle("AI Sommelier")
            .navigationBarTitleDisplayMode(.inline)
            .task { model.attach(assistant) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.startNewChat()
                    } label: {
                        Label("New Chat", systemImage: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showConversations = true
                    } label: {
                        Label("Conversations", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showConversations) {
                ConversationsListView { id in
                    showConversations = false
                    Task { await model.resume(conversationId: id) }
                }
                .environment(assistant)
            }
            // Primary Pro gate for this top-level tab: only present the paywall once entitlement
            // state has RESOLVED and the user is genuinely not Pro (via our own isPro, so it never
            // flashes for a subscriber during the initial loading window).
            .modifier(PaywallBackstop(
                shouldPresent: !subscriptions.isLoading && !subscriptions.isPro,
                onResolved: { Task { await subscriptions.refresh() } }
            ))
    }

    // MARK: - Chat

    private var chat: some View {
        VStack(spacing: 0) {
            transcript

            Divider()

            inputBar
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.messages.isEmpty, !model.isStreaming {
                        emptyState
                            .padding(.top, 48)
                    }

                    ForEach(model.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .id("error")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: model.messages.last?.content) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: model.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.wineAccent)

            Text("Ask Your Sommelier")
                .font(.title3.weight(.semibold))

            Text("Ask for a pairing, a wine like one you loved, or what to open tonight.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask about wine…", text: $model.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 20))
                .disabled(model.isStreaming)

            Button {
                model.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(model.canSend ? .wineAccent : .secondary)
            }
            .disabled(!model.canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let lastID = model.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: AssistantMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            bubbleText
                .font(.body)
                .foregroundStyle(message.role == .user ? Color.white : Color.primary)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.role == .user ? AnyShapeStyle(Color.wineAccent) : AnyShapeStyle(.fill.tertiary),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .model { Spacer(minLength: 40) }
        }
    }

    /// Model replies are rendered as Markdown (the assistant emits **bold**, lists, etc.); user
    /// turns are shown verbatim. An empty placeholder renders a single space to keep bubble height.
    @ViewBuilder
    private var bubbleText: some View {
        if message.content.isEmpty {
            Text(" ")
        } else if message.role == .model {
            Text(LocalizedStringKey(message.content))
        } else {
            Text(message.content)
        }
    }
}

/// Applies RevenueCatUI's `presentPaywallIfNeeded` ONLY when `shouldPresent` is true — i.e. once
/// entitlement state has resolved and the user is genuinely not Pro. When false, the modifier is
/// not attached at all, so a subscriber (or the not-yet-loaded state) never triggers a paywall.
private struct PaywallBackstop: ViewModifier {
    let shouldPresent: Bool
    let onResolved: () -> Void

    func body(content: Content) -> some View {
        if shouldPresent {
            content.presentPaywallIfNeeded(
                requiredEntitlementIdentifier: AppConfig.proEntitlementID,
                purchaseCompleted: { _ in onResolved() },
                restoreCompleted: { _ in onResolved() }
            )
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SommelierView()
            .environment(SubscriptionManager())
            .environment(AssistantService(authService: AuthService()))
    }
}
