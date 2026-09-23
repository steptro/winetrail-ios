import SwiftUI
import RevenueCatUI

/// AI Sommelier — a multi-turn wine chat backed by the assistant endpoint.
///
/// Entry is gated on the `winetrail_pro` entitlement at the tap site in `DiscoverView`, so this
/// screen is normally reached only by subscribers. The `presentPaywallIfNeeded` here is a
/// defensive backstop for any other entry path (e.g. a future deep link); it auto-dismisses for
/// active subscribers.
struct SommelierView: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(AssistantService.self) private var assistant

    @State private var model = SommelierChatModel()

    var body: some View {
        chat
            .navigationTitle("AI Sommelier")
            .navigationBarTitleDisplayMode(.inline)
            .task { model.attach(assistant) }
            // Defensive backstop for non-standard entry paths (e.g. a future deep link):
            // only present the paywall once entitlement state has RESOLVED and the user is
            // genuinely not Pro. Gating on our own resolved state (rather than letting
            // presentPaywallIfNeeded read RevenueCat's cache) prevents a paywall flash for a
            // subscriber during the initial loading window. Discover already gates entry on Pro.
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
