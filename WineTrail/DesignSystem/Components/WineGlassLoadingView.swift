import SwiftUI

/// An animated wine glass that fills up, used as a branded loading indicator.
/// The glass fills from bottom to top with a wave animation in the wine accent color.
struct WineGlassLoadingView: View {
    @State private var fillLevel: CGFloat = 0
    @State private var waveOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Glass outline
            Image(systemName: "wineglass")
                .font(.system(size: 40))
                .foregroundStyle(.wineAccent.opacity(0.3))

            // Filled glass (masked to fill level)
            Image(systemName: "wineglass.fill")
                .font(.system(size: 40))
                .foregroundStyle(.wineAccent)
                .mask(
                    VStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .frame(height: 40 * fillLevel)
                    }
                    .frame(height: 40)
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                fillLevel = 1.0
            }
        }
    }
}

#Preview {
    WineGlassLoadingView()
        .frame(width: 100, height: 100)
}
