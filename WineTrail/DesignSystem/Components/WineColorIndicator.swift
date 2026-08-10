import SwiftUI
import OpenAPIRuntime

/// A small colored circle indicating a wine's color category.
/// Uses the wine color accent palette defined in Colors.swift.
struct WineColorIndicator: View {
    let color: Components.Schemas.WineColor
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(color.accentColor)
            .frame(width: size, height: size)
            .accessibilityLabel(color.displayName)
    }
}

#Preview {
    HStack(spacing: 12) {
        WineColorIndicator(color: .RED)
        WineColorIndicator(color: .WHITE)
        WineColorIndicator(color: .ROSE)
        WineColorIndicator(color: .ORANGE)
        WineColorIndicator(color: .SPARKLING)
    }
    .padding()
}
