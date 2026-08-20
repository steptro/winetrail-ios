import SwiftUI

/// A celebratory toast overlay shown after successfully saving a tasting.
/// Shows clinking glasses emoji with a "Cheers!" message and fades out.
struct CheersToastView: View {
    @State private var isVisible = false
    @State private var scale: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 12) {
            Text("🥂")
                .font(.system(size: 56))

            Text("Cheers!")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .scaleEffect(scale)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isVisible = true
                scale = 1.0
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Auto-dismiss after 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
        CheersToastView()
    }
}
