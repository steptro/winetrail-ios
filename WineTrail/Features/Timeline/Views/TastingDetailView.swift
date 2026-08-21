import SwiftUI
import OpenAPIRuntime

/// Full detail view for a single tasting entry.
///
/// Displays all tasting fields — wine info, rating, photo gallery, notes, food pairing,
/// occasion, price, date, and location. Provides edit and delete actions via toolbar buttons.
struct TastingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TastingService.self) private var tastingService

    @State private var tasting: Tasting
    let viewModel: TimelineViewModel

    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var isDeleting = false

    init(tasting: Tasting, viewModel: TimelineViewModel) {
        _tasting = State(initialValue: tasting)
        self.viewModel = viewModel
    }

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
        .refreshable {
            await reloadTasting()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .navigationTitle("Details")
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
        .alert("Delete Wine", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTasting()
            }
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                EditTastingView(tasting: tasting)
            }
        }
        .onChange(of: showEditSheet) { _, isPresented in
            if !isPresented {
                Task { await reloadTasting() }
            }
        }
    }

    // MARK: - Reload

    private func reloadTasting() async {
        do {
            tasting = try await tastingService.getTasting(id: tasting.id)
        } catch {
            // If reload fails, keep showing the old data
            print("[TastingDetail] Failed to reload tasting: \(error)")
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
            RatingView(rating: Double(tasting.rating))
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
                            .accessibilityLabel("Wine photo")
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
            || (tasting.price != nil)

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
                if let price = tasting.price {
                    let symbol = Self.currencySymbol(for: tasting.currency ?? "EUR")
                    detailRow(icon: "tag", title: "Price", value: "\(symbol)\(String(format: "%.2f", price))")
                }
            }
        }
    }

    private static func currencySymbol(for code: String) -> String {
        let locale = NSLocale(localeIdentifier: code)
        if let symbol = locale.displayName(forKey: .currencySymbol, value: code), symbol != code {
            return symbol
        }
        // Fallback for common codes
        switch code {
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        case "CHF": return "CHF "
        default: return "\(code) "
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


#Preview {
    let authService = AuthService()
    let apiClient = APIClient(serverURL: URL(string: "https://api.winetrail.app")!, authService: authService)
    let tastingService = TastingService(apiClient: apiClient)

    NavigationStack {
        TastingDetailView(
            tasting: Components.Schemas.TastingDto(
                id: "preview-1",
                wine: Components.Schemas.WineSummary(
                    id: "wine-1",
                    name: "Barolo DOCG 2018",
                    producer: "Marchesi di Barolo",
                    regionName: "Barolo",
                    country: "IT",
                    color: .RED
                ),
                rating: 4,
                notes: "Deep garnet with aromas of tar and roses. Full-bodied with firm tannins.",
                foodPairing: "Braised short ribs",
                occasion: "Anniversary dinner",
                price: 45.0,
                currency: "EUR",
                location: Components.Schemas.LocationData(
                    latitude: 44.6094,
                    longitude: 7.9414,
                    locationName: "Enoteca Barolo"
                ),
                tastingDate: "2026-07-20",
                vintage: 2018,
                photos: [],
                createdAt: Date(),
                updatedAt: Date()
            ),
            viewModel: TimelineViewModel(tastingService: tastingService)
        )
    }
    .environment(tastingService)
    .environment(LocationService())
}
