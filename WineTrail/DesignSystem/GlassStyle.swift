import SwiftUI

// MARK: - Liquid Glass Styling

/// A view modifier that applies Liquid Glass styling to floating action buttons.
/// Uses iOS 26's `.glassEffect` for the translucent material appearance
/// consistent with the system tab bar and navigation bar treatment.
struct GlassButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title2.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(.wineAccent)
            .clipShape(Circle())
            .glassEffect(.regular.interactive())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

/// A view modifier that applies Liquid Glass styling to secondary floating elements
/// (e.g., filter chips, layer toggles on the map screen).
struct GlassChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies the standard Liquid Glass floating action button style.
    /// Use this on the "+" button overlay in MainTabView.
    func glassButtonStyle() -> some View {
        modifier(GlassButtonStyle())
    }

    /// Applies a Liquid Glass chip/badge style for secondary floating controls.
    func glassChipStyle() -> some View {
        modifier(GlassChipStyle())
    }
}

// MARK: - Notes
//
// iOS 26 automatically applies Liquid Glass material to:
// - TabView tab bars
// - NavigationStack navigation bars
// - Toolbars
//
// No additional configuration is needed for those system elements.
// The modifiers in this file are for CUSTOM floating elements that
// should match the system glass aesthetic (e.g., the FAB, map overlays).
