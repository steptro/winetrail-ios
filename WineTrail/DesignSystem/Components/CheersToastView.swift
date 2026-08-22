import SwiftUI

/// A full-screen celebratory overlay shown after successfully saving a tasting.
/// Features clinking glasses animation, the rating stars, and a blurred background.
struct CheersToastView: View {
    var rating: Double = 3.0

    @State private var isVisible = false
    @State private var scale: CGFloat = 0.5
    @State private var glassRotation: Double = 0
    @State private var glassOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Full-screen blur background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(isVisible ? 1 : 0)

            // Content
            VStack(spacing: 16) {
                // Clinking glasses with animation
                HStack(spacing: -8) {
                    Text("🍷")
                        .font(.system(size: 50))
                        .rotationEffect(.degrees(-glassRotation))
                        .offset(x: glassOffset)
                    Text("🍷")
                        .font(.system(size: 50))
                        .rotationEffect(.degrees(glassRotation))
                        .offset(x: -glassOffset)
                }

                Text("Cheers!")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)

                // Show rating stars
                RatingView(rating: rating, starSize: .title3)
            }
            .scaleEffect(scale)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            // Fade in + scale up
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isVisible = true
                scale = 1.0
            }

            // Clink animation
            withAnimation(.easeInOut(duration: 0.3).delay(0.3)) {
                glassRotation = 15
                glassOffset = 4
            }
            withAnimation(.easeInOut(duration: 0.2).delay(0.6)) {
                glassRotation = 0
                glassOffset = 0
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isVisible = false
                    scale = 0.8
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color(.systemBackground)
        CheersToastView(rating: 4.2)
    }
}
