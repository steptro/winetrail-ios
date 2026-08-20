import SwiftUI
import OpenAPIRuntime

/// Full detail view for a single tasting entry.
///
/// Displays all tasting fields — wine info, rating, photo gallery, notes, food pairing,
/// occasion, price, date, and location. Provides edit and delete actions via toolbar buttons.
struct TastingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TastingService.self) private var tastingService

    let tasting: Tasting
    let viewModel: TimelineViewModel

    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var isDeleting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.largeSpacing) {
                wineHeader
                ratingSection
                photoGallery
                detailsSection
                metadataSection
            }
            .padding(Theme.spacing)
        }
        .navigationTitle("Tasting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Actions")
                }
            }
        }
        .alert("Delete Tasting", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTasting()
            }
        } message: {
            Text("Are you sure you want to delete this tasting? This action cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditTastingView(tasting: tasting)
        }
    }

    // MARK: - Wine Header

    @ViewBuilder
    private var wineHeader: some View {
        HStack(spacing: Theme.smallSpacing) {
            if let color = tasting.wine.color {
                WineColorIndicator(color: color, size: 16)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tasting.wine.name)
                    .font(Theme.titleFont)

                if let producer = tasting.wine.producer, !producer.isEmpty {
                    Text(producer)
                        .font(Theme.subheadlineFont)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: Theme.smallSpacing) {
                    if let region = tasting.wine.regionName, !region.isEmpty {
                        Text(region)
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                    if let country = tasting.wine.country, !country.isEmpty {
                        if tasting.wine.regionName != nil {
                            Text("·")
                                .font(Theme.captionFont)
                                .foregroundStyle(.tertiary)
                        }
                        Text(country)
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }

                if let vintage = tasting.vintage {
                    Text("Vintage \(String(vintage))")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Rating

    @ViewBuilder
    private var ratingSection: some View {
        HStack {
            Text("Rating")
                .font(Theme.headlineFont)
            Spacer()
            RatingView(rating: Int(tasting.rating))
        }
    }

    // MARK: - Photo Gallery

    @ViewBuilder
    private var photoGallery: some View {
        if !tasting.photos.isEmpty {
            VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                Text("Photos")
                    .font(Theme.headlineFont)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.smallSpacing) {
                        ForEach(tasting.photos) { photo in
                            AsyncImage(url: URL(string: photo.url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(.quaternary)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                            .frame(width: 240, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            .accessibilityLabel("Tasting photo")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Details Section

    @ViewBuilder
    private var detailsSection: some View {
        let hasDetails = (tasting.notes != nil && !tasting.notes!.isEmpty)
            || (tasting.foodPairing != nil && !tasting.foodPairing!.isEmpty)
            || (tasting.occasion != nil && !tasting.occasion!.isEmpty)
            || (tasting.price != nil && !tasting.price!.isEmpty)

        if hasDetails {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                Text("Details")
                    .font(Theme.headlineFont)

                if let notes = tasting.notes, !notes.isEmpty {
                    detailRow(icon: "note.text", title: "Notes", value: notes)
                }
                if let food = tasting.foodPairing, !food.isEmpty {
                    detailRow(icon: "fork.knife", title: "Food Pairing", value: food)
                }
                if let occasion = tasting.occasion, !occasion.isEmpty {
                    detailRow(icon: "party.popper", title: "Occasion", value: occasion)
                }
                if let price = tasting.price, !price.isEmpty {
                    detailRow(icon: "tag", title: "Price", value: price)
                }
            }
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.bodyFont)
        }
    }

    // MARK: - Metadata Section

    @ViewBuilder
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Label(tasting.tastingDate, systemImage: "calendar")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)

            if let location = tasting.location {
                if let name = location.locationName, !name.isEmpty {
                    Label(name, systemImage: "mappin")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, Theme.smallSpacing)
    }

    // MARK: - Actions

    private func deleteTasting() {
        isDeleting = true
        Task {
            await viewModel.deleteTasting(id: tasting.id)
            dismiss()
        }
    }
}
