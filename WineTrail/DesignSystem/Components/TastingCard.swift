import SwiftUI
import OpenAPIRuntime

/// A timeline card that displays a tasting entry with wine info, rating, photo, date, and location.
///
/// Shows:
/// - Wine color indicator + wine name + producer
/// - Rating badge (1–10 scale)
/// - First photo thumbnail (if available)
/// - Date and location metadata
struct TastingCard: View {
    let tasting: Components.Schemas.TastingDto

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            // Top row: wine color, name, producer, and rating
            HStack {
                if let color = tasting.wine.color {
                    WineColorIndicator(color: color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(tasting.wine.name)
                        .font(Theme.headlineFont)
                        .lineLimit(1)

                    if let producer = tasting.wine.producer, !producer.isEmpty {
                        Text(producer)
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                RatingView(rating: Int(tasting.rating))
            }

            // Photo thumbnail (first photo if available)
            if let firstPhoto = tasting.photos.first {
                AsyncImage(url: URL(string: firstPhoto.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                .accessibilityLabel("Tasting photo")
            }

            // Bottom row: date and location
            HStack {
                Label(tasting.tastingDate, systemImage: "calendar")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)

                Spacer()

                if let location = tasting.location, let name = location.locationName {
                    Label(name, systemImage: "mappin")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(Theme.spacing)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tasting of \(tasting.wine.name)")
    }
}
