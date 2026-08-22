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
                    .onTapGesture {
                        if let binding = ratingBinding {
                            let newRating = Double(index)
                            if newRating != binding.wrappedValue {
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                            binding.wrappedValue = newRating
                        }
                    }
            }
            if showValue {
                Text(String(format: "%.1f", clampedRating))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating: \(String(format: "%.1f", clampedRating)) out of 5 stars")
    }

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

// MARK: - Previews

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
