import SwiftUI
import OpenAPIRuntime

/// Edit an existing tasting entry using the same wizard layout as LogTastingView.
///
/// Pre-fills all steps with the tasting's current data. The wine step is read-only
/// (can't change the wine). On save, sends an `UpdateTastingRequest`.
struct EditTastingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TastingService.self) private var tastingService
    @Environment(LocationService.self) private var locationService

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
    @State private var vintageYear: Int?
    @State private var useGPS: Bool

    @State private var isSaving = false
    @State private var error: String?
    @State private var currentStep: WizardStep = .wine

    enum WizardStep: Int, CaseIterable {
        case wine = 0
        case rating = 1
        case details = 2
        case location = 3

        var title: String {
            switch self {
            case .wine: "Wine"
            case .rating: "Rating"
            case .details: "Details"
            case .location: "Location"
            }
        }

        var question: String {
            switch self {
            case .wine: "Your wine"
            case .rating: "How was it?"
            case .details: "What else stood out?"
            case .location: "Where were you?"
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
        _price = State(initialValue: tasting.price ?? "")
        _currency = State(initialValue: tasting.currency ?? "EUR")
        _locationName = State(initialValue: tasting.location?.locationName ?? "")
        _tastingDate = State(initialValue: Self.parseDate(tasting.tastingDate) ?? Date())
        _vintageYear = State(initialValue: tasting.vintage.map { Int($0) })
        _useGPS = State(initialValue: false)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            stepProgressBar

            // Question title
            stepHeader

            // Step content
            stepContent

            Spacer(minLength: 0)

            // Bottom buttons
            bottomButtons
        }
        .navigationTitle("Edit Tasting")
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
        .alert("Error", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) { error = nil }
        } message: {
            if let error { Text(error) }
        }
    }

    // MARK: - Step Progress Bar

    private var stepProgressBar: some View {
        VStack(spacing: 6) {
            Text("Step \(currentStep.rawValue + 1) of \(WizardStep.allCases.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.wineAccent.opacity(0.15))
                        .frame(height: 3)
                    Capsule()
                        .fill(Color.wineAccent)
                        .frame(
                            width: geo.size.width * CGFloat(currentStep.rawValue + 1) / CGFloat(WizardStep.allCases.count),
                            height: 3
                        )
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

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
            wineStep.tag(WizardStep.wine)
            ratingStep.tag(WizardStep.rating)
            detailsStep.tag(WizardStep.details)
            locationStep.tag(WizardStep.location)
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

    // MARK: - Step 1: Wine (Read-only)

    @ViewBuilder
    private var wineStep: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "wineglass.fill")
                        .font(.title2)
                        .foregroundStyle(tasting.wine.color?.accentColor ?? .wineAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tasting.wine.name)
                            .font(Theme.headlineFont)
                        if let producer = tasting.wine.producer, !producer.isEmpty {
                            Text(producer)
                                .font(Theme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Vintage") {
                Picker("Vintage", selection: $vintageYear) {
                    Text("None").tag(nil as Int?)
                    ForEach((1900...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                        Text(String(year)).tag(year as Int?)
                    }
                }
                .tint(.wineAccent)
            }
        }
        .tint(.wineAccent)
    }

    // MARK: - Step 2: Rating

    @ViewBuilder
    private var ratingStep: some View {
        VStack(spacing: Theme.spacing) {
            RatingView(rating: rating, ratingBinding: $rating, starSize: .title)
                .padding(.top, 12)

            WineBottleSlider(rating: $rating)
                .frame(width: 120, height: 260)
                .padding(.vertical, 8)

            Text("Drag to rate")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 3: Details

    @ViewBuilder
    private var detailsStep: some View {
        Form {
            Section("Tasting") {
                TextField("Tasting notes", text: $notes, axis: .vertical)
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
                    Picker("", selection: $currency) {
                        Text("EUR").tag("EUR")
                        Text("USD").tag("USD")
                        Text("GBP").tag("GBP")
                        Text("CHF").tag("CHF")
                    }
                    .pickerStyle(.menu)
                    .tint(.wineAccent)
                    .labelsHidden()
                    .frame(width: 80)
                }
                DatePicker("Date", selection: $tastingDate, in: ...Date(), displayedComponents: .date)
                    .tint(.wineAccent)
            }
        }
        .tint(.wineAccent)
    }

    // MARK: - Step 4: Location

    @ViewBuilder
    private var locationStep: some View {
        Form {
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

        let request = Components.Schemas.UpdateTastingRequest(
            rating: Int32(rating.rounded()),
            notes: notes.isEmpty ? nil : notes,
            foodPairing: foodPairing.isEmpty ? nil : foodPairing,
            occasion: occasion.isEmpty ? nil : occasion,
            price: price.isEmpty ? nil : price,
            currency: price.isEmpty ? nil : currency,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName.isEmpty ? nil : locationName,
            tastingDate: dateFormatter.string(from: tastingDate),
            vintage: vintageYear.map { Int32($0) }
        )

        do {
            _ = try await tastingService.updateTasting(id: tasting.id, request)
            NotificationCenter.default.post(name: .tastingDidChange, object: nil)
            dismiss()
        } catch {
            print("[EditTasting] Failed to update tasting: \(error)")
            self.error = "Something went wrong. Please try again."
        }

        isSaving = false
    }

    // MARK: - Helpers

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }
}
