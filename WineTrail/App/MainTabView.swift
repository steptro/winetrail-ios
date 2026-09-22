import SwiftUI

/// Main tab-based navigation container with Journal, Wines, Discover, Social, and Settings tabs.
/// Each tab wraps its content in a NavigationStack for drill-down navigation.
/// A floating "+" button overlays the tab bar to trigger New Wine from any tab.
/// Stats moved to a toolbar entry inside the Wines tab.
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(JournalService.self) private var journalService
    @Environment(WineService.self) private var wineService
    @Environment(SocialService.self) private var socialService
    @Environment(SocialState.self) private var socialState

    @State private var selectedTab = 3
    @State private var showLogTasting = false
    @State private var didSaveTasting = false
    @State private var deepLinkTasting: Tasting?
    @State private var deepLinkTaggedPost: Components.Schemas.FeedJournalEntryDto?
    @State private var deepLinkWine: SharedWine?

    /// Wraps a resolved shared wine so it can drive a `.sheet(item:)`.
    private struct SharedWine: Identifiable {
        let id: String
        let wine: WineSearch
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Social", systemImage: "person.2", value: 3) {
                    NavigationStack {
                        SocialFeedView()
                    }
                }
                .badge(socialState.socialBadgeCount)
                Tab("Journal", systemImage: "book", value: 0) {
                    NavigationStack {
                        TimelineView()
                    }
                }
                Tab("Wines", systemImage: "wineglass", value: 1) {
                    NavigationStack {
                        WinesListView()
                    }
                }
                Tab("Discover", systemImage: "sparkle.magnifyingglass", value: 2) {
                    NavigationStack {
                        DiscoverView()
                    }
                }
                Tab("Settings", systemImage: "gearshape", value: 4) {
                    NavigationStack {
                        ProfileView()
                    }
                }
            }

            // Floating Action Button — New Wine
            Button {
                showLogTasting = true
            } label: {
                Image(systemName: "plus")
                    .glassButtonStyle()
            }
            .padding(.trailing, 20)
            .padding(.bottom, 70) // Position above the tab bar
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("New Wine")
        }
        .sheet(isPresented: $showLogTasting, onDismiss: {
            // Only refresh the timeline if the user actually saved a wine — cancelling
            // the wizard should leave the feed untouched.
            if didSaveTasting {
                NotificationCenter.default.post(name: .tastingDidChange, object: nil)
                didSaveTasting = false
            }
        }) {
            LogTastingView(didSave: $didSaveTasting)
        }
        .sheet(item: $deepLinkTasting) { tasting in
            NavigationStack {
                TastingDetailView(
                    tasting: tasting,
                    viewModel: TimelineViewModel(journalService: journalService),
                    showActions: false
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { deepLinkTasting = nil } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
        }
        .sheet(item: $deepLinkTaggedPost) { post in
            NavigationStack {
                SocialTastingDetailView(post: post)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button { deepLinkTaggedPost = nil } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
        }
        .sheet(item: $deepLinkWine) { shared in
            NavigationStack {
                WineSearchDetailView(wine: shared.wine, showsNavigationTitle: false)
                    .environment(wineService)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button { deepLinkWine = nil } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
        }
        .onChange(of: appState.pendingDeepLink) { _, deepLink in
            guard let deepLink else { return }
            handleDeepLink(deepLink)
            appState.pendingDeepLink = nil
        }
        .tint(.wineAccent)
        .task {
            await socialState.refresh()
        }
        .onChange(of: selectedTab) { _, _ in
            Task { await socialState.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendRequestsDidChange)) { _ in
            Task { await socialState.refreshPendingCount() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taggedWinesDidChange)) { _ in
            Task { await socialState.refreshTaggedCount() }
        }
    }

    private func handleDeepLink(_ deepLink: DeepLink) {
        switch deepLink {
        case .tasting(let id):
            Task {
                do {
                    let tasting = try await journalService.getTasting(id: id)
                    deepLinkTasting = tasting
                } catch {
                    Log.error("Failed to load tasting from deep link", error: error)
                }
            }
        case .friends:
            selectedTab = 3 // Social tab
        case .taggedPost(let entryId):
            selectedTab = 3 // Social tab
            Task {
                do {
                    // No single-entry social endpoint; find the post among the user's tagged wines.
                    let tagged = try await socialService.getTaggedEntries(page: 0, size: 50)
                    if let match = tagged.content.first(where: { $0.id == entryId }) {
                        deepLinkTaggedPost = match
                    }
                } catch {
                    Log.error("Failed to load tagged post from deep link", error: error)
                }
            }
        case .wine(let id):
            Task {
                do {
                    // Resolve via the global catalog endpoint so a shared wine opens even
                    // when the recipient has never logged it. Map to WineSearch so the
                    // detail view can offer "Log a Tasting" against the catalog wine.
                    let dto = try await wineService.getWine(id: id)
                    let wine = WineSearch(
                        wineId: dto.id,
                        name: dto.name,
                        producer: dto.producer,
                        region: dto.regionName,
                        country: dto.country,
                        color: dto.color,
                        grapeVarieties: dto.grapeVarieties,
                        description: dto.description
                    )
                    deepLinkWine = SharedWine(id: dto.id, wine: wine)
                } catch {
                    Log.error("Failed to load wine from deep link", error: error)
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}
