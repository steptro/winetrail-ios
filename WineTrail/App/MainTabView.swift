import SwiftUI

/// Main tab-based navigation container with Timeline, Wines, Map, and Stats tabs.
/// Each tab wraps its content in a NavigationStack for drill-down navigation.
/// A floating "+" button overlays the tab bar to trigger New Wine from any tab.
struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showLogTasting = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Timeline", systemImage: "list.bullet", value: 0) {
                    NavigationStack {
                        TimelineView()
                    }
                }
                Tab("Wines", systemImage: "wineglass", value: 1) {
                    NavigationStack {
                        WinesListView()
                    }
                }
                Tab("Map", systemImage: "map", value: 2) {
                    NavigationStack {
                        MapView()
                    }
                }
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
    }
}

#Preview {
    MainTabView()
}
