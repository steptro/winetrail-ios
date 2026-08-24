import SwiftUI

/// Main tab-based navigation container with Journal, Wines, Social, Stats, and Profile tabs.
/// Each tab wraps its content in a NavigationStack for drill-down navigation.
/// A floating "+" button overlays the tab bar to trigger New Wine from any tab.
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(JournalService.self) private var journalService
    @Environment(SocialState.self) private var socialState

    @State private var selectedTab = 0
    @State private var showLogTasting = false
    @State private var deepLinkTasting: Tasting?

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
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
                Tab("Social", systemImage: "person.2", value: 2) {
                    NavigationStack {
                        SocialFeedView()
                    }
                }
                .badge(socialState.pendingRequestCount)
                Tab("Stats", systemImage: "chart.bar", value: 3) {
                    NavigationStack {
                        StatsView()
                    }
                }
                Tab("Profile", systemImage: "person.crop.circle", value: 4) {
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
            NotificationCenter.default.post(name: .tastingDidChange, object: nil)
        }) {
            LogTastingView()
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
        .onChange(of: appState.pendingDeepLink) { _, deepLink in
            guard let deepLink else { return }
            handleDeepLink(deepLink)
            appState.pendingDeepLink = nil
        }
        .tint(.wineAccent)
        .task {
            await socialState.refreshPendingCount()
        }
        .onChange(of: selectedTab) { _, _ in
            Task { await socialState.refreshPendingCount() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendRequestsDidChange)) { _ in
            Task { await socialState.refreshPendingCount() }
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
            selectedTab = 2 // Social tab
        }
    }
}

#Preview {
    MainTabView()
}
