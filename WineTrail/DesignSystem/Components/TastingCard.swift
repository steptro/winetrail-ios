import SwiftUI
import OpenAPIRuntime

/// A timeline card that displays a tasting entry with wine info, rating, photo, date, and location.
///
/// Photos bleed to the card edges as hero images. Wine info and metadata overlay below.
struct TastingCard: View {
    let tasting: Components.Schemas.JournalEntryDto

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero photo (full-width bleed to card edges)
            if let firstPhoto = tasting.photos.first {
                CachedAsyncImage(url: URL(string: firstPhoto.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                }
                .frame(height: 180)
                .clipped()
                .accessibilityLabel("Wine photo")
            }

            VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                // Wine info row: glass icon, name, producer, and rating
                HStack {
                    Image(systemName: "wineglass.fill")
                        .font(.title3)
                        .foregroundStyle(tasting.wine.color?.accentColor ?? .wineAccent)

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

                    RatingView(rating: Double(tasting.rating))
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
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Wine: \(tasting.wine.name)")
    }
}


#Preview {
    VStack(spacing: 16) {
        TastingCard(tasting: Components.Schemas.JournalEntryDto(
            id: "preview-1",
            wine: Components.Schemas.WineSummary(
                id: "wine-1",
                name: "Château Margaux 2015",
                producer: "Château Margaux",
                regionName: "Bordeaux",
                country: "FR",
                color: .RED
            ),
            rating: 5,
            notes: "Exceptional complexity",
            tastingDate: "2026-08-15",
            photos: [],
            likeCount: 3,
            commentCount: 1,
            likedByMe: false,
            createdAt: Date(),
            updatedAt: Date()
        ))

        TastingCard(tasting: Components.Schemas.JournalEntryDto(
            id: "preview-2",
            wine: Components.Schemas.WineSummary(
                id: "wine-2",
                name: "Cloudy Bay Sauvignon Blanc",
                producer: "Cloudy Bay",
                regionName: "Marlborough",
                country: "NZ",
                color: .WHITE
            ),
            rating: 3,
            tastingDate: "2026-08-10",
            photos: [],
            likeCount: 0,
            commentCount: 0,
            likedByMe: false,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
    .padding()
}
