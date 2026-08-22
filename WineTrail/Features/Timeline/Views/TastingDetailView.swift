import SwiftUI
import OpenAPIRuntime

/// Full detail view for a single wine entry, designed as a journal page.
///
/// Hero photo at the top (edge-to-edge), wine identity block, prominent star rating,
/// blockquote-style notes, metadata pills, and a floating edit button.
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
            VStack(alignment: .leading, spacing: 0) {
                // Hero photo carousel
                heroPhoto

                VStack(alignment: .leading, spacing: Theme.largeSpacing) {
                    // Wine identity
                    wineIdentity

                    // Star rating
                    starRating

                    // Notes (blockquote style)
                    notesSection

                    // Metadata pills
                    metadataPills
                }
                .padding(.horizontal, Theme.spacing)
                .padding(.top, Theme.spacing)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        .refreshable {
            await reloadTasting()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
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
                    Label("Contextual", systemImage: "ellipsis")
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
            Log.error("Failed to reload tasting", error: error)
        }
    }

    // MARK: - Hero Photo

    @ViewBuilder
    private var heroPhoto: some View {
        if !tasting.photos.isEmpty {
            TabView {
                ForEach(tasting.photos, id: \.id) { photo in
                    AsyncImage(url: URL(string: photo.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.quaternary)
                            .overlay { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: tasting.photos.count > 1 ? .automatic : .never))
            .frame(height: 320)
        } else {
            WinePlaceholderView(color: tasting.wine.color)
        }
    }

    // MARK: - Wine Identity

    @ViewBuilder
    private var wineIdentity: some View {
        NavigationLink {
            WineDetailView(wine: Components.Schemas.UserWineStats(
                wine: tasting.wine,
                timesDrunk: 0,
                averageRating: Double(tasting.rating)
            ))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wineglass.fill")
                    .font(.title)
                    .foregroundStyle(tasting.wine.color?.accentColor ?? .wineAccent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tasting.wine.name + (tasting.vintage.map { " (\($0))" } ?? ""))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        if let country = tasting.wine.country, !country.isEmpty {
                            Text(Self.flag(for: country))
                        }
                        if let producer = tasting.wine.producer, !producer.isEmpty {
                            Text(producer)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let region = tasting.wine.regionName, !region.isEmpty {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(region)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Star Rating

    @ViewBuilder
    private var starRating: some View {
        HStack {
            RatingView(rating: Double(tasting.rating), starSize: .title2)
            Spacer()
        }
    }

    // MARK: - Notes (Blockquote)

    @ViewBuilder
    private var notesSection: some View {
        if let notes = tasting.notes, !notes.isEmpty {
            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Metadata Pills

    @ViewBuilder
    private var metadataPills: some View {
        let pills = buildPills()

        if !pills.isEmpty {
            let columns = [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ]

            LazyVGrid(columns: columns, spacing: Theme.smallSpacing) {
                ForEach(pills, id: \.label) { pill in
                    VStack(spacing: 4) {
                        Image(systemName: pill.icon)
                            .font(.title3)
                            .foregroundStyle(.wineAccent)
                            .frame(height: 24)
                        Text(pill.label)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(height: 16)
                        Text(pill.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(height: 14)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(Theme.smallSpacing)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private struct MetadataPill {
        let icon: String
        let title: String
        let label: String
    }

    private func buildPills() -> [MetadataPill] {
        var pills: [MetadataPill] = []

        pills.append(MetadataPill(icon: "calendar", title: "Date", label: formattedDate))

        if let location = tasting.location, let name = location.locationName, !name.isEmpty {
            pills.append(MetadataPill(icon: "mappin", title: "Location", label: name))
        }

        if let food = tasting.foodPairing, !food.isEmpty {
            pills.append(MetadataPill(icon: "fork.knife", title: "Pairing", label: food))
        }

        if let occasion = tasting.occasion, !occasion.isEmpty {
            pills.append(MetadataPill(icon: "party.popper", title: "Occasion", label: occasion))
        }

        if let price = tasting.price {
            let symbol = Self.currencySymbol(for: tasting.currency ?? "EUR")
            pills.append(MetadataPill(icon: "tag", title: "Price", label: "\(symbol)\(String(format: "%.2f", price))"))
        }

        return pills
    }

    private var formattedDate: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = inputFormatter.date(from: tasting.tastingDate) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "dd MMM yyyy"
            outputFormatter.locale = Locale.current
            return outputFormatter.string(from: date)
        }
        return tasting.tastingDate
    }

    // MARK: - Actions

    private func deleteTasting() {
        isDeleting = true
        Task {
            await viewModel.deleteTasting(id: tasting.id)
            dismiss()
        }
    }

    // MARK: - Helpers

    private static func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }

    private static func currencySymbol(for code: String) -> String {
        let locale = NSLocale(localeIdentifier: code)
        if let symbol = locale.displayName(forKey: .currencySymbol, value: code), symbol != code {
            return symbol
        }
        switch code {
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        case "CHF": return "CHF "
        default: return "\(code) "
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
                notes: "Deep garnet with aromas of tar and roses. Full-bodied with firm tannins and a long, complex finish.",
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
