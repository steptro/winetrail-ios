import SwiftUI

/// A reusable placeholder view shown when no photos are available.
/// Displays a gradient in the wine's accent colour with a wine glass icon overlay.
struct WinePlaceholderView: View {
    var color: Components.Schemas.WineColor?
    var height: CGFloat = 200

    private var accentColor: Color {
        color?.accentColor ?? .wineAccent
    }

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.25),
                        accentColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: height)
            .overlay {
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(accentColor.opacity(0.5))
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        WinePlaceholderView(color: .RED)
        WinePlaceholderView(color: .WHITE)
        WinePlaceholderView(color: .SPARKLING, height: 120)
    }
}
