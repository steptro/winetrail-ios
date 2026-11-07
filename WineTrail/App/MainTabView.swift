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
    @State private var showDeepLinkStats = false
    @State private var showDeepLinkJoinRequests = false
    @State private var sharedSearchImage: SharedSearchImage?

    /// Wraps a shared image so it can drive a `.sheet(item:)`.
    private struct SharedSearchImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

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
                Tab("Wines", systemImage: "wineglass", value: 1) {
                    NavigationStack {
                        WinesListView()
                    }
                }
                Tab("Sommelier", systemImage: "sparkles", value: 2) {
                    NavigationStack {
                        SommelierView()
                    }
                }
                Tab("Profile", systemImage: "person.crop.circle", value: 4) {
                    NavigationStack {
                        ProfileView()
                    }
                }
            }

            // Floating Action Button — New Wine. Hidden on the AI Sommelier tab (value 2), whose
            // chat input bar occupies the bottom-right where the FAB would sit.
            if selectedTab != 2 {
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
        .sheet(isPresented: $showDeepLinkStats) {
            NavigationStack {
                StatsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button { showDeepLinkStats = false } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showDeepLinkJoinRequests) {
            NavigationStack {
                JoinRequestsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button { showDeepLinkJoinRequests = false } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Close")
                        }
                    }
            }
        }
        .sheet(item: $sharedSearchImage) { shared in
            LogTastingView(preselectedScanImage: shared.image, didSave: $didSaveTasting)
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
        case .joinRequests:
            selectedTab = 3 // Social tab
            showDeepLinkJoinRequests = true
        case .stats:
            showDeepLinkStats = true
        case .searchPhoto:
            if let image = Self.readSharedPhoto() {
                sharedSearchImage = SharedSearchImage(image: image)
            }
        }
    }

    /// App Group shared with the Share Extension. Must match both targets' entitlement.
    private static let appGroupId = "group.dev.stephantromer.winetrail"
    private static let sharedImageFileName = "shared-wine-photo.jpg"

    /// Reads (and clears) the image the Share Extension stashed in the shared container.
    private static func readSharedPhoto() -> UIImage? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return nil }

        let fileURL = container.appendingPathComponent(sharedImageFileName)
        guard let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) else { return nil }

        // Consume it so a later launch doesn't re-open the same photo.
        try? FileManager.default.removeItem(at: fileURL)
        return image
    }
}

#Preview {
    MainTabView()
}
