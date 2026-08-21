import SwiftUI

/// A vertical wine bottle slider where the fill level represents the rating (1–5).
/// The user drags vertically on the bottle to fill/empty it. Haptic feedback on each
/// half-star increment.
struct WineBottleSlider: View {
    @Binding var rating: Double
    let range: ClosedRange<Double> = 0.5...5.0

    @State private var isDragging = false

    /// Fill percentage (0.0–1.0) derived from the rating.
    private var fillPercent: CGFloat {
        CGFloat((rating - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    var body: some View {
        GeometryReader { geo in
            let bottleHeight = geo.size.height

            ZStack(alignment: .bottom) {
                // Bottle outline
                WineBottleShape()
                    .stroke(Color.wineAccent.opacity(0.3), lineWidth: 2)

                // Bottle fill
                WineBottleShape()
                    .fill(
                        LinearGradient(
                            colors: [.wineAccent.opacity(0.9), .wineAccent.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .mask(
                        VStack(spacing: 0) {
                            Spacer()
                            Rectangle()
                                .frame(height: bottleHeight * fillPercent)
                        }
                    )
                    .animation(.easeOut(duration: 0.15), value: rating)

                // Rating label overlay
                VStack {
                    Spacer()
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(.bottom, bottleHeight * fillPercent * 0.4 + 20)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let normalised = 1.0 - (value.location.y / bottleHeight)
                        let clamped = min(max(normalised, 0), 1)
                        let newRating = range.lowerBound + Double(clamped) * (range.upperBound - range.lowerBound)
                        let snapped = (newRating * 2).rounded() / 2

                        if snapped != rating {
                            UISelectionFeedbackGenerator().selectionChanged()
                            rating = snapped
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .scaleEffect(isDragging ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isDragging)
        }
        .accessibilityElement()
        .accessibilityLabel("Wine bottle rating slider")
        .accessibilityValue("\(String(format: "%.1f", rating)) out of 5")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                rating = min(rating + 0.5, range.upperBound)
            case .decrement:
                rating = max(rating - 0.5, range.lowerBound)
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Wine Bottle Shape

/// A custom shape drawing a realistic wine bottle silhouette with cork, neck, shoulder, body, and punt.
struct WineBottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let centerX = w / 2

        // Proportions
        let capTop: CGFloat = 0
        let capBottom: CGFloat = h * 0.04
        let lipTop: CGFloat = h * 0.04
        let lipBottom: CGFloat = h * 0.06
        let neckTop: CGFloat = h * 0.06
        let neckBottom: CGFloat = h * 0.32
        let shoulderBottom: CGFloat = h * 0.42
        let bodyBottom: CGFloat = h * 0.94
        let baseBottom: CGFloat = h

        let capWidth: CGFloat = w * 0.14
        let lipWidth: CGFloat = w * 0.18
        let neckWidth: CGFloat = w * 0.13
        let bodyWidth: CGFloat = w * 0.40

        // Cap (top of bottle)
        path.move(to: CGPoint(x: centerX - capWidth, y: capTop))
        path.addLine(to: CGPoint(x: centerX - capWidth, y: capBottom))

        // Lip bulge
        path.addLine(to: CGPoint(x: centerX - lipWidth, y: lipTop))
        path.addLine(to: CGPoint(x: centerX - lipWidth, y: lipBottom))
        path.addLine(to: CGPoint(x: centerX - neckWidth, y: neckTop))

        // Neck (long and thin)
        path.addLine(to: CGPoint(x: centerX - neckWidth, y: neckBottom))

        // Shoulder (smooth curve from neck to body)
        path.addCurve(
            to: CGPoint(x: centerX - bodyWidth, y: shoulderBottom),
            control1: CGPoint(x: centerX - neckWidth, y: neckBottom + (shoulderBottom - neckBottom) * 0.6),
            control2: CGPoint(x: centerX - bodyWidth, y: neckBottom + (shoulderBottom - neckBottom) * 0.7)
        )

        // Body (slightly tapered — wider in middle)
        let bodyMidY = (shoulderBottom + bodyBottom) / 2
        path.addCurve(
            to: CGPoint(x: centerX - bodyWidth * 0.98, y: bodyBottom),
            control1: CGPoint(x: centerX - bodyWidth * 1.02, y: bodyMidY),
            control2: CGPoint(x: centerX - bodyWidth * 0.98, y: bodyBottom - 20)
        )

        // Base (flat with subtle punt suggestion)
        path.addLine(to: CGPoint(x: centerX - bodyWidth * 0.85, y: baseBottom))
        path.addLine(to: CGPoint(x: centerX + bodyWidth * 0.85, y: baseBottom))
        path.addLine(to: CGPoint(x: centerX + bodyWidth * 0.98, y: bodyBottom))

        // Right body
        path.addCurve(
            to: CGPoint(x: centerX + bodyWidth, y: shoulderBottom),
            control1: CGPoint(x: centerX + bodyWidth * 0.98, y: bodyBottom - 20),
            control2: CGPoint(x: centerX + bodyWidth * 1.02, y: bodyMidY)
        )

        // Right shoulder
        path.addCurve(
            to: CGPoint(x: centerX + neckWidth, y: neckBottom),
            control1: CGPoint(x: centerX + bodyWidth, y: neckBottom + (shoulderBottom - neckBottom) * 0.7),
            control2: CGPoint(x: centerX + neckWidth, y: neckBottom + (shoulderBottom - neckBottom) * 0.6)
        )

        // Right neck
        path.addLine(to: CGPoint(x: centerX + neckWidth, y: neckTop))

        // Right lip
        path.addLine(to: CGPoint(x: centerX + lipWidth, y: lipBottom))
        path.addLine(to: CGPoint(x: centerX + lipWidth, y: lipTop))
        path.addLine(to: CGPoint(x: centerX + capWidth, y: capBottom))

        // Right cap
        path.addLine(to: CGPoint(x: centerX + capWidth, y: capTop))

        // Close top
        path.addLine(to: CGPoint(x: centerX - capWidth, y: capTop))

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var rating: Double = 3.0

    VStack(spacing: 20) {
        WineBottleSlider(rating: $rating)
            .frame(width: 100, height: 260)

        RatingView(rating: rating, starSize: .title2, showValue: true)
    }
    .padding(40)
}
