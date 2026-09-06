import SwiftUI
import PhotosUI
import OpenAPIRuntime

/// Edit an existing tasting entry using a 3-step wizard layout matching LogTastingView.
///
/// Pre-fills all steps with the tasting's current data. The wine display is read-only
/// (can't change the wine). On save, sends an `UpdateTastingRequest`.
struct EditTastingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(JournalService.self) private var journalService
    @Environment(LocationService.self) private var locationService
    @Environment(PhotoService.self) private var photoService

    let tasting: Tasting

    // MARK: - Form State

    @State private var rating: Double
    @State private var notes: String
    @State private var foodPairing: String
    @State private var occasion: String
    @State private var price: String
    @State private var currency: String
    @State private var locationName: String
    @State private var tastingDate: Date
    @State private var vintageText: String
    @State private var useGPS: Bool
    @State private var selectedImages: [UIImage] = []
    @State private var photosToDelete: Set<String> = []
    @State private var autoDetectedLocation: String?

    @State private var isSaving = false
    @State private var error: String?
    @State private var currentStep: WizardStep = .wineAndRating

    enum WizardStep: Int, CaseIterable {
        case wineAndRating = 0
        case details = 1

        var title: String {
            switch self {
            case .wineAndRating: "Wine & Rating"
            case .details: "Details"
            }
        }

        var question: String {
            switch self {
            case .wineAndRating: "Which wine did you have?"
            case .details: "Capture the moment"
            }
        }

        var next: WizardStep? { WizardStep(rawValue: rawValue + 1) }
        var previous: WizardStep? { WizardStep(rawValue: rawValue - 1) }
    }

    // MARK: - Initialization

    init(tasting: Tasting) {
        self.tasting = tasting
        _rating = State(initialValue: Double(tasting.rating))
        _notes = State(initialValue: tasting.notes ?? "")
        _foodPairing = State(initialValue: tasting.foodPairing ?? "")
        _occasion = State(initialValue: tasting.occasion ?? "")
        _price = State(initialValue: tasting.price.map { String(format: "%.2f", $0) } ?? "")
        _currency = State(initialValue: tasting.currency ?? "EUR")
        _locationName = State(initialValue: tasting.location?.locationName ?? "")
        _tastingDate = State(initialValue: Self.parseDate(tasting.tastingDate) ?? Date())
        _vintageText = State(initialValue: tasting.vintage.map { String($0) } ?? "")
        _useGPS = State(initialValue: false)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Question title
                stepHeader

                // Step content
                stepContent

                Spacer(minLength: 0)

                // Bottom buttons
                bottomButtons
            }
        }
        .navigationTitle("Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button {
                        Task { await save() }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.wineAccent)
                }
            }
        }
        .errorAlert($error)
        .task {
            await autoDetectLocationIfNeeded()
        }
    }

    // MARK: - Step Progress Bar

    // MARK: - Step Header

    private var stepHeader: some View {
        Text(currentStep.question)
            .font(.title2.weight(.bold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        TabView(selection: $currentStep) {
            wineAndRatingStep.tag(WizardStep.wineAndRating)
            detailsStep.tag(WizardStep.details)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.25), value: currentStep)
    }

    // MARK: - Bottom Buttons

    @ViewBuilder
    private var bottomButtons: some View {
        VStack(spacing: 10) {
            if let next = currentStep.next {
                Button {
                    dismissKeyboard()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { currentStep = next }
                } label: {
                    Text("Next")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(.wineAccent, in: Capsule())
                }
            } else {
                Button {
                    Task { await save() }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(.wineAccent, in: Capsule())
                }
            }

            if let previous = currentStep.previous {
                Button {
                    dismissKeyboard()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { currentStep = previous }
                } label: {
                    Text("Back")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Step 1: Wine & Rating

    @ViewBuilder
    private var wineAndRatingStep: some View {
        ScrollView {
            VStack(spacing: Theme.spacing) {
                // Read-only wine display
                HStack(spacing: 12) {
                    Image(systemName: "wineglass.fill")
                        .font(.title)
                        .foregroundStyle(tasting.wine.color?.accentColor ?? .wineAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tasting.wine.name)
                            .font(Theme.headlineFont)
                        if let producer = tasting.wine.producer, !producer.isEmpty {
                            Text(producer)
                                .font(Theme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                        if let region = tasting.wine.regionName {
                            Text(region)
                                .font(Theme.captionFont)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .padding(.horizontal, Theme.spacing)

                // Rating
                RatingView(rating: rating, ratingBinding: $rating, starSize: .title)
                    .padding(.top, 8)

                WineBottleSlider(rating: $rating)
                    .frame(width: 70, height: 220)
                    .padding(.vertical, 4)

                Text("Drag to rate")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)

                Image(systemName: "arrow.up.and.down")
                    .font(.caption)
                    .foregroundStyle(.wineAccent.opacity(0.6))
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Step 2: Details (Photos + Notes + Food + Occasion + Price + Date + Vintage)

    @ViewBuilder
    private var detailsStep: some View {
        let existingPhotos = tasting.photos.filter { !photosToDelete.contains($0.id) }

        Form {
            // Photos section
            Section {
                // Existing photos
                if !existingPhotos.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                        Text("Current photos")
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.smallSpacing) {
                                ForEach(existingPhotos, id: \.id) { photo in
                                    ZStack(alignment: .topTrailing) {
                                        CachedAsyncImage(url: URL(string: photo.url)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(.quaternary)
                                        }
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))

                                        Button {
                                            _ = withAnimation {
                                                photosToDelete.insert(photo.id)
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.white)
                                                .background(Circle().fill(.black.opacity(0.5)))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                        }
                    }
                }

                // New photos
                PhotoPickerView(selectedImages: $selectedImages, existingPhotoCount: existingPhotos.count)
            } header: {
                Text("Photos")
            }

            Section("Vintage") {
                TextField("e.g. 2019", text: $vintageText)
                    .keyboardType(.numberPad)
                    .onChange(of: vintageText) { _, newValue in
                        vintageText = String(newValue.prefix(4).filter(\.isNumber))
                    }
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Pairing & Occasion") {
                TextField("Food pairing", text: $foodPairing)
                TextField("Occasion", text: $occasion)
            }

            Section("Purchase") {
                HStack {
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                        .onChange(of: price) { _, newValue in
                            price = sanitizePrice(newValue)
                        }
                    Picker("", selection: $currency) {
                        Text("EUR").tag("EUR")
                        Text("USD").tag("USD")
                        Text("GBP").tag("GBP")
                        Text("CHF").tag("CHF")
                        Text("AUD").tag("AUD")
                        Text("CAD").tag("CAD")
                        Text("NZD").tag("NZD")
                        Text("JPY").tag("JPY")
                        Text("ZAR").tag("ZAR")
                    }
                    .pickerStyle(.menu)
                    .tint(.wineAccent)
                    .labelsHidden()
                    .frame(width: 80)
                }
            }

            // Location section
            Section("Location") {
                if locationService.authorizationStatus == .authorizedWhenInUse ||
                   locationService.authorizationStatus == .authorizedAlways {
                    Toggle("Use current location", isOn: $useGPS)
                        .tint(.wineAccent)
                } else if locationService.authorizationStatus == .notDetermined {
                    Button {
                        Task { await locationService.requestPermission() }
                    } label: {
                        Label("Enable Location Access", systemImage: "location")
                    }
                    .foregroundStyle(.wineAccent)
                } else {
                    Label("Location access denied", systemImage: "location.slash")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
                TextField("Location name", text: $locationName)
            }
        }
        .tint(.wineAccent)
    }

    // MARK: - Auto-Detect Location

    private func autoDetectLocationIfNeeded() async {
        let hasPermission = locationService.authorizationStatus == .authorizedWhenInUse ||
                            locationService.authorizationStatus == .authorizedAlways
        let hasExistingLocation = tasting.location?.locationName != nil && !(tasting.location?.locationName ?? "").isEmpty

        guard hasPermission, !hasExistingLocation else { return }

        useGPS = true
        if (try? await locationService.getCurrentLocation()) != nil {
            autoDetectedLocation = "Location detected"
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        error = nil

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        var latitude = tasting.location?.latitude
        var longitude = tasting.location?.longitude

        if useGPS {
            if let coord = try? await locationService.getCurrentLocation() {
                latitude = coord.latitude
                longitude = coord.longitude
            }
        }

        let vintageYear: Int? = if let year = Int(vintageText), year >= 1900, year <= Calendar.current.component(.year, from: Date()) {
            year
        } else {
            nil
        }

        let request = Components.Schemas.UpdateJournalEntryRequest(
            rating: rating,
            notes: notes.isEmpty ? nil : notes,
            foodPairing: foodPairing.isEmpty ? nil : foodPairing,
            occasion: occasion.isEmpty ? nil : occasion,
            price: Double(price).map { (($0 * 100).rounded() / 100) },
            currency: price.isEmpty ? nil : currency,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName.isEmpty ? nil : locationName,
            tastingDate: nil,
            vintage: vintageYear.map { Int32($0) }
        )

        do {
            _ = try await journalService.updateTasting(id: tasting.id, request)

            // Delete photos marked for removal
            for photoId in photosToDelete {
                try await photoService.deletePhoto(id: photoId)
            }

            // Upload new photos if any were added
            if !selectedImages.isEmpty {
                _ = try await photoService.uploadPhotos(
                    tastingId: tasting.id,
                    images: selectedImages
                )
            }

            WineAnalytics.logTastingEdited(tastingId: tasting.id)
            NotificationCenter.default.post(name: .tastingDidChange, object: nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            Log.error("Failed to update tasting", error: error)
            self.error = "Something went wrong. Please try again."
        }

        isSaving = false
    }

    // MARK: - Helpers

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Sanitizes price input to allow only digits and at most one decimal separator with 2 fractional digits.
    private func sanitizePrice(_ input: String) -> String {
        let separators: [Character] = [".", ","]
        var result = ""
        var foundSeparator = false
        var decimals = 0

        for char in input {
            if char.isNumber {
                if foundSeparator {
                    guard decimals < 2 else { continue }
                    decimals += 1
                }
                result.append(char)
            } else if separators.contains(char) && !foundSeparator {
                foundSeparator = true
                result.append(".")
            }
        }
        return result
    }

    private static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }
}


#Preview {
    NavigationStack {
        EditTastingView(
            tasting: Components.Schemas.JournalEntryDto(
                id: "preview-1",
                wine: Components.Schemas.WineSummary(
                    id: "wine-1",
                    name: "Château Margaux 2015",
                    producer: "Château Margaux",
                    regionName: "Bordeaux",
                    country: "FR",
                    color: .RED
                ),
                rating: 4,
                notes: "Complex and elegant",
                foodPairing: "Grilled lamb",
                occasion: "Birthday dinner",
                price: 95.0,
                currency: "EUR",
                location: Components.Schemas.LocationData(
                    latitude: 48.8566,
                    longitude: 2.3522,
                    locationName: "Le Comptoir, Paris"
                ),
                tastingDate: "2026-08-10",
                vintage: 2015,
                photos: [],
                likeCount: 2,
                commentCount: 1,
                likedByMe: true,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }
    .environment(JournalService(apiClient: APIClient(
        serverURL: AppConfig.serverURL,
        authService: AuthService()
    )))
    .environment(LocationService())
}
