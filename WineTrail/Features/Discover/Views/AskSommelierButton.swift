import SwiftUI
import RevenueCatUI

/// A reusable "Ask the Sommelier about this wine" button for wine detail screens.
///
/// The AI Sommelier is a WineTrail Pro feature, so the button gates on the resolved
/// entitlement: a Pro member opens a fresh Sommelier chat seeded with a question about the
/// wine (auto-sent), while a non-Pro member is shown the paywall. The gate reads our own
/// resolved `isPro`; while entitlement is still loading the button is disabled so a subscriber
/// never triggers a paywall flash.
struct AskSommelierButton: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(AssistantService.self) private var assistant

    /// The wine's display name, used to build the seed prompt.
    let wineName: String
    /// Optional producer, folded into the seed prompt to disambiguate common names.
    var producer: String? = nil
    /// Optional region, folded into the seed prompt for extra context.
    var region: String? = nil

    @State private var showSommelier = false
    @State private var showPaywall = false
    @State private var showSubscriptionsUnavailable = false

    var body: some View {
        Button {
            if subscriptions.isPro {
                showSommelier = true
            } else if subscriptions.offeringsFailed {
                showSubscriptionsUnavailable = true
            } else {
                showPaywall = true
            }
        } label: {
            Label("Ask the Sommelier", systemImage: "sparkles")
                .font(Theme.bodyFont.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.wineAccent)
        .disabled(subscriptions.isLoading)
        .sheet(isPresented: $showSommelier) {
            NavigationStack {
                SommelierView(seedPrompt: seedPrompt)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button { showSommelier = false } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
            .environment(assistant)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(displayCloseButton: true)
                .onPurchaseCompleted { _ in Task { await subscriptions.refresh() } }
                .onRestoreCompleted { _ in Task { await subscriptions.refresh() } }
        }
        .alert("Subscriptions Unavailable", isPresented: $showSubscriptionsUnavailable) {
            Button("Try Again") { Task { await subscriptions.loadOfferings() } }
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't load subscriptions right now. Please try again in a little while.")
        }
    }

    /// The question the seeded chat opens with.
    private var seedPrompt: String {
        var descriptor = wineName

        let details = [producer, region]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !details.isEmpty {
            descriptor += " (\(details.joined(separator: ", ")))"
        }

        return "Tell me more about \(descriptor)"
    }
}
