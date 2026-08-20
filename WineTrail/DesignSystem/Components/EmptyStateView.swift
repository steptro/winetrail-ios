import SwiftUI

/// A reusable empty state view shown when no data is available.
/// Uses `ContentUnavailableView` (iOS 17+) for a native, consistent appearance
/// across timeline, wines list, map, and stats screens.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            if let message {
                Text(message)
            }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.wineAccent)
            }
        }
    }
}

#Preview("With action") {
    EmptyStateView(
        icon: "wineglass",
        title: "No Tastings Yet",
        message: "Log your first wine to start your diary.",
        actionTitle: "New Wine",
        action: {}
    )
}

#Preview("Without action") {
    EmptyStateView(
        icon: "map",
        title: "No Map Data",
        message: "Your tasting locations will appear here."
    )
}
