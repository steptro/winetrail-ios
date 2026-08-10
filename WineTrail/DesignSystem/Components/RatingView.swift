import SwiftUI

/// A compact rating badge for displaying a 1–10 wine tasting score.
///
/// Shows a star icon alongside the numeric rating, tinted by quality tier:
/// - 1–3: red (poor)
/// - 4–5: orange (below average)
/// - 6–7: yellow (good)
/// - 8–10: green (excellent)
///
/// Designed to fit comfortably in list rows and card layouts.
struct RatingView: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(ratingColor)

            Text("\(clampedRating)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(ratingColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(ratingColor.opacity(0.12))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating: \(clampedRating) out of 10")
    }

    // MARK: - Private

    private var clampedRating: Int {
        min(max(rating, 1), 10)
    }

    private var ratingColor: Color {
        switch clampedRating {
        case 1...3: return .red
        case 4...5: return .orange
        case 6...7: return .yellow
        case 8...10: return .green
        default: return .gray
        }
    }
}

// MARK: - Previews

#Preview("All Ratings") {
    VStack(spacing: 8) {
        ForEach(1...10, id: \.self) { score in
            HStack {
                Text("Score \(score)")
                    .frame(width: 80, alignment: .leading)
                RatingView(rating: score)
            }
        }
    }
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
            RatingView(rating: 9)
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
            RatingView(rating: 3)
        }
    }
}
