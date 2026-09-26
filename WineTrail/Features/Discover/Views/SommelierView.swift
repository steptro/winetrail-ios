import SwiftUI
import RevenueCatUI
import MarkdownUI

/// AI Sommelier — a multi-turn wine chat backed by the assistant endpoint.
///
/// This is a top-level tab and a Pro-only feature. The gate is driven by our own resolved `isPro`:
/// while entitlement state is loading we show a neutral loader (so a subscriber never sees a
/// paywall flash), a resolved non-subscriber sees an explicit locked state with an "Unlock
/// WineTrail Pro" button that presents the paywall on demand, and a subscriber sees the chat.
struct SommelierView: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(AssistantService.self) private var assistant

    @State private var model = SommelierChatModel()
    @State private var showConversations = false
    @State private var showPaywall = false

    /// Optional prompt to seed a fresh chat with (e.g. "Tell me more about <wine>"), sent
    /// automatically once the chat appears. When set, the view opens straight into a new chat.
    private let seedPrompt: String?

    @State private var didSeed = false

    init(seedPrompt: String? = nil) {
        self.seedPrompt = seedPrompt
    }

    var body: some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task { model.attach(assistant) }
            .toolbar {
                if subscriptions.isPro {
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
            }
            .sheet(isPresented: $showConversations) {
                ConversationsListView { id in
                    showConversations = false
                    Task { await model.resume(conversationId: id) }
                }
                .environment(assistant)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(displayCloseButton: true)
                    .onPurchaseCompleted { _ in Task { await subscriptions.refresh() } }
                    .onRestoreCompleted { _ in Task { await subscriptions.refresh() } }
            }
    }

    // MARK: - Content gate

    /// The Sommelier is a Pro-only feature. While entitlement state is still resolving we show a
    /// neutral loader (never a paywall flash for a subscriber); a resolved non-subscriber lands on
    /// the locked state, which auto-presents the paywall on appear (and its Unlock button re-opens
    /// it if dismissed); a subscriber sees the chat.
    @ViewBuilder
    private var content: some View {
        if subscriptions.isLoading {
            WineGlassLoadingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if subscriptions.isPro {
            chat
        } else {
            proLockedState
                // Non-Pro and entitlement has RESOLVED (this branch never renders while loading),
                // so opening the tab surfaces the paywall directly — UNLESS offerings failed to
                // load, in which case the locked state shows a generic error instead of a paywall
                // with no products.
                .onAppear {
                    if !subscriptions.offeringsFailed {
                        showPaywall = true
                    }
                }
        }
    }

    private var proLockedState: some View {
        VStack(spacing: 16) {
            if subscriptions.offeringsFailed {
                subscriptionsUnavailable
            } else {
                proUpsell
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Generic, user-facing message when subscriptions could not be loaded. The real RevenueCat
    /// error is only logged (to Datadog), never shown here.
    @ViewBuilder
    private var subscriptionsUnavailable: some View {
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 44))
            .foregroundStyle(.secondary)

        Text("Subscriptions Unavailable")
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.center)

        Text("We couldn't load subscriptions right now. Please try again in a little while.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

        Button {
            Task { await subscriptions.loadOfferings() }
        } label: {
            Text("Try Again")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.wineAccent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var proUpsell: some View {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.wineAccent)

            Text("A WineTrail Pro Feature")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("The AI Sommelier is available to WineTrail Pro members. Upgrade to ask for pairings, recommendations, and what to open tonight.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showPaywall = true
            } label: {
                Text("Unlock WineTrail Pro")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.wineAccent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)
    }

    // MARK: - Chat

    private var chat: some View {
        transcript
            // Pin the input as a floating bottom inset so the transcript scrolls UNDER it (and under
            // the tab bar), matching the other screens where content flows beneath the bottom bar —
            // rather than a VStack that reserves an opaque band above the tab bar.
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
            // A send rejected with 403 means Pro is gone: refresh entitlement so the content gate
            // flips to the locked state (which presents the paywall), instead of a generic error.
            .onChange(of: model.entitlementLost) { _, lost in
                if lost {
                    Task { await subscriptions.refresh() }
                }
            }
            // `.task` runs once for the view's lifetime (not on every re-appearance the way
            // `.onAppear` does), so the seeded question is sent exactly once per opened chat.
            .task {
                guard let seedPrompt, !didSeed else { return }
                didSeed = true
                // Attach here too: this can run before body's `.task` attaches the service,
                // and `send(text:)` no-ops without it. `attach` is idempotent.
                model.attach(assistant)
                model.startNewChat()
                model.send(text: seedPrompt)
            }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            Group {
                if model.messages.isEmpty, !model.isStreaming {
                    // No messages yet: center the prompt in the full available height.
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(model.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if let error = model.errorMessage {
                                VStack(spacing: 8) {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)

                                    if model.canRetry {
                                        Button {
                                            model.retryLastTurn()
                                        } label: {
                                            Label("Try Again", systemImage: "arrow.clockwise")
                                                .font(.caption.weight(.semibold))
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.wineAccent)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .id("error")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        // Opening an existing conversation loads all messages in one batch; jump
                        // (no animation) to the newest after layout settles so it opens at the
                        // bottom rather than the top.
                        DispatchQueue.main.async { scrollToBottom(proxy, animated: false) }
                    }
                    .onChange(of: model.messages.last?.content) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: model.messages.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                }
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
        HStack(alignment: .center, spacing: 8) {
            TextField("Ask about wine…", text: $model.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .modifier(GlassInputBackground())
                .disabled(model.isStreaming)

            Button {
                if model.isStreaming {
                    model.cancelStreaming()
                } else {
                    model.send()
                }
            } label: {
                Image(systemName: model.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(sendButtonColor)
            }
            .disabled(!model.isStreaming && !model.canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// Color for the send/stop button: gold when it can act (there's a draft to send, or a reply
    /// is streaming and can be stopped), secondary when idle with an empty draft.
    private var sendButtonColor: Color {
        (model.isStreaming || model.canSend) ? .wineGold : Color.secondary
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastID = model.messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

// MARK: - Input glass background

/// Liquid Glass background for the chat input field on iOS 26+, falling back to an
/// ultra-thin material capsule on older versions so the field stays legible everywhere.
private struct GlassInputBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: AssistantMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            bubbleContent
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .model { Spacer(minLength: 40) }
        }
    }

    /// The bubble body. An empty MODEL bubble (the placeholder before the first token streams in)
    /// shows the branded glass loader so the wait is visible; everything else is a text bubble.
    @ViewBuilder
    private var bubbleContent: some View {
        if message.role == .model, message.content.isEmpty {
            WineGlassLoadingView()
                .frame(width: 40, height: 40)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        } else {
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
        }
    }

    /// Model replies are rendered as Markdown (the assistant emits **bold**, lists, etc.); user
    /// turns are shown verbatim.
    @ViewBuilder
    private var bubbleText: some View {
        if message.content.isEmpty {
            Text(" ")
        } else if message.role == .model {
            Markdown(message.content)
                .markdownTextStyle {
                    FontSize(UIFont.preferredFont(forTextStyle: .body).pointSize)
                    ForegroundColor(.primary)
                }
        } else {
            Text(message.content)
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
