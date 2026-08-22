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
                        let snapped = (newRating * 10).rounded() / 10

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
                rating = min(rating + 0.1, range.upperBound)
            case .decrement:
                rating = max(rating - 0.1, range.lowerBound)
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Wine Bottle Shape

/// A wine bottle shape derived from an SVG silhouette, normalized to fit any rect.
struct WineBottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.4156, y: h * 0.0004))
        path.addCurve(to: CGPoint(x: w * 0.3738, y: h * 0.0012), control1: CGPoint(x: w * 0.4115, y: h * 0.0005), control2: CGPoint(x: w * 0.3928, y: h * 0.0009))
        path.addCurve(to: CGPoint(x: w * 0.3265, y: h * 0.013), control1: CGPoint(x: w * 0.3321, y: h * 0.0018), control2: CGPoint(x: w * 0.3324, y: h * 0.0018))
        path.addCurve(to: CGPoint(x: w * 0.3195, y: h * 0.0229), control1: CGPoint(x: w * 0.3242, y: h * 0.0173), control2: CGPoint(x: w * 0.321, y: h * 0.0217))
        path.addCurve(to: CGPoint(x: w * 0.3145, y: h * 0.0373), control1: CGPoint(x: w * 0.3178, y: h * 0.0241), control2: CGPoint(x: w * 0.3157, y: h * 0.0305))
        path.addCurve(to: CGPoint(x: w * 0.3175, y: h * 0.0541), control1: CGPoint(x: w * 0.3128, y: h * 0.0475), control2: CGPoint(x: w * 0.3134, y: h * 0.0504))
        path.addCurve(to: CGPoint(x: w * 0.3178, y: h * 0.108), control1: CGPoint(x: w * 0.3233, y: h * 0.0596), control2: CGPoint(x: w * 0.3233, y: h * 0.0671))
        path.addCurve(to: CGPoint(x: w * 0.2999, y: h * 0.2426), control1: CGPoint(x: w * 0.3064, y: h * 0.1892), control2: CGPoint(x: w * 0.3014, y: h * 0.2268))
        path.addCurve(to: CGPoint(x: w * 0.2401, y: h * 0.2879), control1: CGPoint(x: w * 0.2973, y: h * 0.2681), control2: CGPoint(x: w * 0.2935, y: h * 0.2711))
        path.addCurve(to: CGPoint(x: w * 0.1384, y: h * 0.322), control1: CGPoint(x: w * 0.1688, y: h * 0.3104), control2: CGPoint(x: w * 0.16, y: h * 0.3132))
        path.addCurve(to: CGPoint(x: w * 0.0172, y: h * 0.4016), control1: CGPoint(x: w * 0.0786, y: h * 0.3458), control2: CGPoint(x: w * 0.04, y: h * 0.3711))
        path.addCurve(to: CGPoint(x: w * 0.0009, y: h * 0.6969), control1: CGPoint(x: w * 0.0, y: h * 0.4246), control2: CGPoint(x: w * 0.0009, y: h * 0.4067))
        path.addLine(to: CGPoint(x: w * 0.0009, y: h * 0.9629))
        path.addLine(to: CGPoint(x: w * 0.0085, y: h * 0.9706))
        path.addCurve(to: CGPoint(x: w * 0.0625, y: h * 0.9981), control1: CGPoint(x: w * 0.0202, y: h * 0.9832), control2: CGPoint(x: w * 0.0415, y: h * 0.994))
        path.addLine(to: CGPoint(x: w * 0.0721, y: h * 1.0))
        path.addLine(to: CGPoint(x: w * 0.4985, y: h * 1.0))
        path.addCurve(to: CGPoint(x: w * 0.9346, y: h * 0.9984), control1: CGPoint(x: w * 0.9173, y: h * 1.0), control2: CGPoint(x: w * 0.9255, y: h * 1.0))
        path.addCurve(to: CGPoint(x: w * 0.9904, y: h * 0.9712), control1: CGPoint(x: w * 0.9544, y: h * 0.9952), control2: CGPoint(x: w * 0.9769, y: h * 0.9842))
        path.addLine(to: CGPoint(x: w * 0.9982, y: h * 0.9637))
        path.addLine(to: CGPoint(x: w * 0.9991, y: h * 0.7023))
        path.addCurve(to: CGPoint(x: w * 0.9968, y: h * 0.4305), control1: CGPoint(x: w * 1.0, y: h * 0.5106), control2: CGPoint(x: w * 0.9991, y: h * 0.4382))
        path.addCurve(to: CGPoint(x: w * 0.8414, y: h * 0.3146), control1: CGPoint(x: w * 0.9828, y: h * 0.3866), control2: CGPoint(x: w * 0.929, y: h * 0.3465))
        path.addCurve(to: CGPoint(x: w * 0.79, y: h * 0.2978), control1: CGPoint(x: w * 0.8312, y: h * 0.3109), control2: CGPoint(x: w * 0.8081, y: h * 0.3034))
        path.addCurve(to: CGPoint(x: w * 0.7132, y: h * 0.2713), control1: CGPoint(x: w * 0.7395, y: h * 0.2823), control2: CGPoint(x: w * 0.7231, y: h * 0.2766))
        path.addCurve(to: CGPoint(x: w * 0.696, y: h * 0.2207), control1: CGPoint(x: w * 0.7024, y: h * 0.2656), control2: CGPoint(x: w * 0.7015, y: h * 0.2625))
        path.addCurve(to: CGPoint(x: w * 0.6872, y: h * 0.1547), control1: CGPoint(x: w * 0.6942, y: h * 0.2073), control2: CGPoint(x: w * 0.6904, y: h * 0.1777))
        path.addCurve(to: CGPoint(x: w * 0.6799, y: h * 0.0558), control1: CGPoint(x: w * 0.6735, y: h * 0.0537), control2: CGPoint(x: w * 0.6741, y: h * 0.0615))
        path.addCurve(to: CGPoint(x: w * 0.6837, y: h * 0.0372), control1: CGPoint(x: w * 0.6843, y: h * 0.0514), control2: CGPoint(x: w * 0.6849, y: h * 0.0485))
        path.addCurve(to: CGPoint(x: w * 0.679, y: h * 0.0221), control1: CGPoint(x: w * 0.6828, y: h * 0.0298), control2: CGPoint(x: w * 0.6808, y: h * 0.023))
        path.addCurve(to: CGPoint(x: w * 0.6726, y: h * 0.0136), control1: CGPoint(x: w * 0.6773, y: h * 0.0212), control2: CGPoint(x: w * 0.6744, y: h * 0.0174))
        path.addCurve(to: CGPoint(x: w * 0.665, y: h * 0.0042), control1: CGPoint(x: w * 0.6709, y: h * 0.0098), control2: CGPoint(x: w * 0.6673, y: h * 0.0056))
        path.addCurve(to: CGPoint(x: w * 0.6381, y: h * 0.0012), control1: CGPoint(x: w * 0.6606, y: h * 0.0019), control2: CGPoint(x: w * 0.6598, y: h * 0.0017))
        path.addCurve(to: CGPoint(x: w * 0.4156, y: h * 0.0004), control1: CGPoint(x: w * 0.6113, y: h * 0.0007), control2: CGPoint(x: w * 0.4261, y: h * 0.0))
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
