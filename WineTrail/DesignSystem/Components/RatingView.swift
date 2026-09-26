import SwiftUI

/// A star rating view showing 1–5 stars with half-star support.
///
/// Displays filled, half-filled, and empty stars based on the rating value.
/// Rating is stored as a Double (e.g., 3.5 = three and a half stars).
/// When a `Binding` is provided via the interactive initializer, tapping a star sets the rating.
struct RatingView: View {
    /// Rating value from 0.5 to 5.0 (half-star increments).
    let rating: Double

    /// Optional binding for interactive mode (tapping stars changes rating).
    var ratingBinding: Binding<Double>?

    /// Size of each star.
    var starSize: Font = .body

    /// Whether to show the numeric value next to the stars.
    var showValue: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                starImage(for: index)
            }
            if showValue {
                Text(String(format: "%.1f", clampedRating))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
        // In interactive mode, let the user drag horizontally across the stars to set the rating
        // in half-star steps — not just tap. The gesture writes the SAME binding the bottle slider
        // uses, so the stars and the bottle stay in lockstep. The overlay measures only the star
        // row (matching its frame), so the numeric value label, when shown, is outside the drag
        // region and the full travel maps cleanly across the five stars.
        .overlay { starDragOverlay }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating: \(String(format: "%.1f", clampedRating)) out of 5 stars")
    }

    /// Transparent hit area over the star row that turns a horizontal drag into a half-star rating.
    /// Present only in interactive mode; the star row includes the trailing value label (when
    /// shown), so we scale against the five-star width by trimming that label's approximate width.
    @ViewBuilder
    private var starDragOverlay: some View {
        if let binding = ratingBinding {
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let starsWidth = showValue ? max(geo.size.width - valueLabelWidth, 1) : geo.size.width
                                let fraction = min(max(value.location.x / starsWidth, 0), 1)

                                // Map across five stars, snap to the nearest half-star, clamp 0.5…5.0.
                                let snapped = (fraction * 5.0 * 2).rounded() / 2
                                let newRating = min(max(snapped, 0.5), 5.0)

                                if newRating != binding.wrappedValue {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    binding.wrappedValue = newRating
                                }
                            }
                    )
            }
        }
    }

    /// Approximate width the numeric value label occupies (font .caption + 4pt leading padding),
    /// trimmed from the drag region when `showValue` is on so the drag maps only across the stars.
    private var valueLabelWidth: CGFloat { 32 }

    private var clampedRating: Double {
        min(max(rating, 0), 5)
    }

    private func starImage(for index: Int) -> some View {
        let threshold = Double(index)
        let fillAmount = min(max(clampedRating - (threshold - 1), 0), 1)

        return ZStack {
            Image(systemName: "star")
                .foregroundStyle(.wineAccent.opacity(0.3))

            Image(systemName: "star.fill")
                .foregroundStyle(.wineAccent)
                .mask(
                    GeometryReader { geo in
                        Rectangle()
                            .frame(width: geo.size.width * fillAmount)
                    }
                )
        }
        .font(starSize)
    }
}


#Preview("Half Stars") {
    VStack(spacing: 12) {
        RatingView(rating: 1.0)
        RatingView(rating: 2.5)
        RatingView(rating: 3.5)
        RatingView(rating: 4.0)
        RatingView(rating: 5.0)
        RatingView(rating: 3.5, starSize: .title2, showValue: true)
    }
    .padding()
}

#Preview("Interactive") {
    @Previewable @State var rating: Double = 3.0
    RatingView(rating: rating, ratingBinding: $rating, starSize: .title)
        .padding()
}

#Preview("In Context") {
    List {
        HStack {
            VStack(alignment: .leading) {
                Text("Château Margaux 2015")
                    .font(.headline)
                Text("Bordeaux, France")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            RatingView(rating: 4.5)
        }
        HStack {
            VStack(alignment: .leading) {
                Text("Table Wine")
                    .font(.headline)
                Text("Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            RatingView(rating: 2.0)
        }
    }
}
