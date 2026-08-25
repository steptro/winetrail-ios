import SwiftUI

/// A reusable empty state view shown when no data is available.
/// Uses `ContentUnavailableView` (iOS 17+) for a native, consistent appearance
/// across timeline, wines list, map, and stats screens.
struct EmptyStateView<ActionLabel: View>: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var actionLabel: ActionLabel? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            if let message {
                Text(message)
            }
        } actions: {
            if let action {
                Button(action: action) {
                    if let actionLabel {
                        actionLabel
                            .font(.headline)
                    } else if let actionTitle {
                        Text(actionTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.wineAccent)
            }
        }
    }
}

// MARK: - Convenience initializer for string-only action

extension EmptyStateView where ActionLabel == Never {
    init(icon: String, title: String, message: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.actionLabel = nil
        self.action = action
    }
}

#Preview("With action") {
    EmptyStateView(
        icon: "wineglass",
        title: "No Wines Yet",
        message: "Log your first wine to start your diary.",
        actionTitle: "New Wine",
        action: {}
    )
}

#Preview("With label action") {
    EmptyStateView(
        icon: "person.2",
        title: "No Friends Yet",
        message: "Add friends to see their wine tastings here.",
        actionLabel: Label("Add Friends", systemImage: "plus"),
        action: {}
    )
}

#Preview("Without action") {
    EmptyStateView<Never>(
        icon: "map",
        title: "No Map Data",
        message: "Your wine locations will appear here."
    )
}
