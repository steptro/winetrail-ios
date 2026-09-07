import SwiftUI

/// New Wine wizard — a step-by-step flow for recording a wine tasting.
///
/// Steps: Wine & Rating → Details → Location.
/// The user can save at any step once a wine is selected (the only required field).
/// Dark, warm premium design with glass card surfaces.
struct LogTastingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WineService.self) private var wineService
    @Environment(JournalService.self) private var journalService
    @Environment(PhotoService.self) private var photoService
    @Environment(LocationService.self) private var locationService
    @Environment(SocialService.self) private var socialService

    /// Optional pre-selected wine (e.g. from "Log Again" on wine detail page).
    var preselectedWine: WineSearch?

    /// When set, this new entry joins an existing shared tasting (the "Add my rating" flow).
    var sharedTastingId: String?

    /// Optional vintage to pre-fill (e.g. from the friend's post in the "Add my rating" flow).
    var preselectedVintage: Int?

    /// Optional fields pre-filled from the friend's post in the "Add my rating" flow.
    var preselectedFoodPairing: String?
    var preselectedOccasion: String?
    var preselectedLocationName: String?
    var preselectedLatitude: Double?
    var preselectedLongitude: Double?

    @State private var viewModel: LogTastingViewModel?
    @State private var currentStep: WizardStep = .wineAndRating
    @State private var shakeWineSection = false
    @State private var showCheers = false

    @State private var showScanCamera = false
    @State private var isScanning = false
    @State private var scanWarning: String?
    @State private var scanFoundNoText = false
    @State private var showTagFriends = false
    @State private var isLocationLocked = false

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

        var next: WizardStep? {
            WizardStep(rawValue: rawValue + 1)
        }

        var previous: WizardStep? {
            WizardStep(rawValue: rawValue - 1)
        }
    }

    // MARK: - Background Colors

    private static let cardBorder = Color(.separator).opacity(0.3)

    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle warm background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                Group {
                    if let viewModel {
                        VStack(spacing: 0) {
                            stepHeader
                            stepContent(viewModel: viewModel)
                            Spacer(minLength: 0)
                            bottomButtons(viewModel: viewModel)
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
            .navigationTitle("New Wine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = LogTastingViewModel(
                    wineService: wineService,
                    journalService: journalService,
                    photoService: photoService,
                    locationService: locationService,
                    socialService: socialService
                )
                if let preselectedWine {
                    vm.selectWine(preselectedWine)
                }
                vm.sharedTastingId = sharedTastingId
                if let preselectedVintage {
                    vm.vintageText = String(preselectedVintage)
                }
                if let preselectedFoodPairing { vm.foodPairing = preselectedFoodPairing }
                if let preselectedOccasion { vm.occasion = preselectedOccasion }
                if let preselectedLocationName { vm.locationName = preselectedLocationName }
                if let preselectedLatitude, let preselectedLongitude {
                    vm.copiedLatitude = preselectedLatitude
                    vm.copiedLongitude = preselectedLongitude
                }
                // Lock the copied location (name + coordinates) behind an Edit affordance.
                if preselectedLocationName != nil || preselectedLatitude != nil {
                    isLocationLocked = true
                }
                viewModel = vm
            }
        }
        .onChange(of: viewModel?.savedTasting?.id) { _, tastingId in
            if tastingId != nil {
                showCheers = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: showErrorBinding) {
            Button("OK", role: .cancel) {
                viewModel?.error = nil
            }
        } message: {
            if let error = viewModel?.error {
                Text(error)
            }
        }
        .overlay {
            if showCheers {
                CheersToastView(rating: viewModel?.rating ?? 3.0)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var showErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.error != nil },
            set: { if !$0 { viewModel?.error = nil } }
        )
    }

    // MARK: - Step Header

    private var stepHeader: some View {
        VStack(spacing: 6) {
            Text(currentStep.question)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Step Progress Bar

    // MARK: - Step Content

    @ViewBuilder
    private func stepContent(viewModel: LogTastingViewModel) -> some View {
        TabView(selection: Binding(
            get: { currentStep },
            set: { newStep in
                // Prevent swiping past step 1 without selecting a wine
                if currentStep == .wineAndRating && newStep.rawValue > WizardStep.wineAndRating.rawValue && viewModel.selectedWine == nil {
                    withAnimation(.default) { shakeWineSection = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        shakeWineSection = false
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    return
                }
                currentStep = newStep
            }
        )) {
            wineAndRatingStep(viewModel: viewModel)
                .tag(WizardStep.wineAndRating)
            detailsStep(viewModel: viewModel)
                .tag(WizardStep.details)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.25), value: currentStep)
    }

    // MARK: - Bottom Buttons

    @ViewBuilder
    private func bottomButtons(viewModel: LogTastingViewModel) -> some View {
        VStack(spacing: 10) {
            // Next / Save button (primary, filled)
            if let next = currentStep.next {
                Button {
                    attemptNext(viewModel: viewModel, next: next)
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
                    Task { await viewModel.saveTasting() }
                } label: {
                    Group {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(.wineAccent, in: Capsule())
                }
                .disabled(viewModel.isSaving || !viewModel.canSave)
            }

            // Back button (secondary, glass outline)
            if let previous = currentStep.previous {
                Button {
                    dismissKeyboardAndTransition(to: previous)
                } label: {
                    Text("Back")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .modifier(OutlineButtonModifier())
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Navigation Helpers

    private func attemptNext(viewModel: LogTastingViewModel, next: WizardStep) {
        if currentStep == .wineAndRating && viewModel.selectedWine == nil {
            withAnimation(.default) { shakeWineSection = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shakeWineSection = false
            }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        dismissKeyboardAndTransition(to: next)
    }

    private func dismissKeyboardAndTransition(to step: WizardStep) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { currentStep = step }
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

    // MARK: - Step 1: Wine & Rating

    @ViewBuilder
    private func wineAndRatingStep(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(spacing: 20) {
                // Wine selection section
                glassCard {
                    if let wine = viewModel.selectedWine {
                        selectedWineRow(wine: wine, viewModel: viewModel)
                    } else {
                        VStack(spacing: 12) {
                            HStack {
                                TextField("Search wines...", text: $vm.searchQuery)
                                    .autocorrectionDisabled()
                                    .onSubmit { viewModel.search() }
                                Button {
                                    viewModel.search()
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                }
                                .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                            }

                            // Prominent primary action: scan a label.
                            Button {
                                scanWarning = nil
                                scanFoundNoText = false
                                showScanCamera = true
                            } label: {
                                Label("Scan Label", systemImage: "camera.viewfinder")
                                    .font(Theme.bodyFont.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.wineAccent)
                            .disabled(isScanning)

                            if isScanning {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Reading label...")
                                        .font(Theme.captionFont)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let scanWarning {
                                Label(scanWarning, systemImage: "exclamationmark.triangle")
                                    .font(Theme.captionFont)
                                    .foregroundStyle(.orange)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityLabel("Scan warning: \(scanWarning)")

                                // No readable text: offer a manual-create shortcut.
                                if scanFoundNoText {
                                    NavigationLink {
                                        CreateWineView(selectedWine: $vm.selectedWine, selectedWineId: $vm.selectedWineId)
                                    } label: {
                                        Label("Add Manually", systemImage: "plus.circle")
                                            .font(Theme.bodyFont.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.wineSecondary)
                                }
                            }

                            if viewModel.isSearching {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Searching...")
                                        .font(Theme.captionFont)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Recent wines section
                            if !viewModel.recentWines.isEmpty && viewModel.searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionLabel("Recent")
                                    ForEach(viewModel.recentWines, id: \.name) { wine in
                                        Button {
                                            // A recent pick isn't the scanned bottle — drop the scan photo.
                                            viewModel.discardPendingScanImage()
                                            viewModel.selectWine(wine)
                                        } label: {
                                            wineResultRow(wine: wine)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            // Search results
                            if !viewModel.searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionLabel("Results")
                                    ForEach(viewModel.searchResults, id: \.name) { wine in
                                        Button {
                                            // Selecting a scanned match attaches the label photo.
                                            viewModel.consumePendingScanImage()
                                            viewModel.selectWine(wine)
                                        } label: {
                                            wineResultRow(wine: wine)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            // Fallback: only offer manual entry when a search or scan
                            // produced nothing to pick.
                            let hasSearched = !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
                            if !viewModel.isSearching && !isScanning
                                && viewModel.searchResults.isEmpty
                                && !scanFoundNoText
                                && (hasSearched || scanWarning != nil) {
                                Divider()
                                NavigationLink {
                                    CreateWineView(selectedWine: $vm.selectedWine, selectedWineId: $vm.selectedWineId)
                                } label: {
                                    Label("Add Manually", systemImage: "plus.circle")
                                        .font(Theme.bodyFont.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.bordered)
                                .tint(.wineSecondary)
                            }

                        }
                    }
                }

                // Rating section (shown once wine is selected)
                if viewModel.selectedWine != nil {
                    VStack(spacing: Theme.spacing) {
                        sectionLabel("Rating")

                        RatingView(rating: viewModel.rating, ratingBinding: $vm.rating, starSize: .title)

                        WineBottleSlider(rating: $vm.rating)
                            .frame(width: 70, height: 220)
                            .padding(.vertical, 4)

                        Text("Drag the wine level to rate")
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
        .tint(.wineAccent)
        .fullScreenCover(isPresented: $showScanCamera) {
            LabelScanCameraView { image in
                showScanCamera = false
                guard let image else { return }
                scanLabel(image, viewModel: viewModel)
            }
            .ignoresSafeArea()
        }
        .offset(x: shakeWineSection ? -8 : 0)
        .animation(
            shakeWineSection
                ? .default.repeatCount(3, autoreverses: true).speed(6)
                : .default,
            value: shakeWineSection
        )
    }

    // MARK: - Step 2: Details (Photo + Notes/Food/Occasion/Price/Date/Vintage)

    @ViewBuilder
    private func detailsStep(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        Form {
            // Photo section
            // Reuse photos from the shared tasting (Add my rating flow), selected by default.
            if viewModel.sharedTastingId != nil, !viewModel.sharedTastingPhotos.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.smallSpacing) {
                            ForEach(viewModel.sharedTastingPhotos, id: \.id) { photo in
                                let isSelected = viewModel.selectedSharedPhotoIds.contains(photo.id)
                                Button {
                                    viewModel.toggleSharedPhoto(photo.id)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        CachedAsyncImage(url: URL(string: photo.url)) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle().fill(.quaternary)
                                        }
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                                                .strokeBorder(isSelected ? Color.wineAccent : Color.clear, lineWidth: 3)
                                        )
                                        .opacity(isSelected ? 1.0 : 0.5)

                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18))
                                            .foregroundStyle(isSelected ? Color.wineAccent : Color.white)
                                            .background(Circle().fill(.black.opacity(0.4)))
                                            .offset(x: 4, y: -4)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Photos from this tasting")
                } footer: {
                    Text("Selected photos are copied to your entry. Tap to include or exclude.")
                }
            }

            Section("Photo") {
                PhotoPickerView(
                    selectedImages: $vm.selectedImages,
                    existingPhotoCount: vm.selectedSharedPhotoIds.count
                )
            }

            Section("Vintage") {
                TextField("e.g. 2024", text: $vm.vintageText)
                    .keyboardType(.numberPad)
            }

            // Tagging only applies when creating a new post, not when adding your rating
            // to an existing shared tasting.
            if vm.sharedTastingId == nil {
                Section {
                    Button {
                        showTagFriends = true
                    } label: {
                        HStack {
                            Label("Tag Friends", systemImage: "person.2")
                                .foregroundStyle(.primary)
                            Spacer()
                            if vm.taggedFriendIds.isEmpty {
                                Text("None")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(vm.taggedFriendIds.count) tagged")
                                    .foregroundStyle(.wineAccent)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } footer: {
                    Text("Tagged friends are notified and can add their own rating to this wine.")
                }
            }

            Section("Notes") {
                TextField("Notes", text: $vm.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Pairing & Occasion") {
                TextField("Food pairing", text: $vm.foodPairing)
                TextField("Occasion", text: $vm.occasion)
            }

            Section("Purchase") {
                HStack {
                    TextField("Price", text: $vm.price)
                        .keyboardType(.decimalPad)
                        .onChange(of: vm.price) { _, newValue in
                            vm.price = sanitizePrice(newValue)
                        }
                    Picker("", selection: $vm.currency) {
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
                if isLocationLocked {
                    HStack {
                        Label(vm.locationName.isEmpty ? "Shared tasting location" : vm.locationName,
                              systemImage: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Edit") {
                            // Clear the copied location (name + coordinates) and switch to manual entry.
                            vm.locationName = ""
                            vm.copiedLatitude = nil
                            vm.copiedLongitude = nil
                            isLocationLocked = false
                        }
                        .font(Theme.captionFont)
                        .foregroundStyle(.wineAccent)
                    }
                } else {
                    if locationService.authorizationStatus == .authorizedWhenInUse ||
                       locationService.authorizationStatus == .authorizedAlways {
                        Toggle("Use current location", isOn: $vm.useGPS)
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

                    TextField("Location name", text: $vm.locationName)
                }
            }
        }
        .tint(.wineAccent)
        .sheet(isPresented: $showTagFriends) {
            TagFriendsView(selectedFriendIds: $vm.taggedFriendIds)
        }
    }

    // MARK: - Glass Card Container

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .modifier(GlassCardModifier())
    }

    private struct GlassCardModifier: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 26, *) {
                content
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            } else {
                content
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
                    )
            }
        }
    }

    // MARK: - Field Helpers

    @ViewBuilder
    private func iconField(icon: String, placeholder: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        HStack(alignment: axis == .vertical ? .top : .center, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.wineAccent)
                .frame(width: 20)
                .padding(.top, axis == .vertical ? 4 : 0)
            if axis == .vertical {
                TextField(placeholder, text: text, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
            } else {
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.wineAccent)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: - Button Modifiers

    private struct FilledButtonModifier: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 26, *) {
                content
                    .foregroundStyle(.white)
                    .background(.wineAccent, in: Capsule())
                    .glassEffect(.regular.interactive(), in: Capsule())
            } else {
                content
                    .foregroundStyle(.white)
                    .background(.wineAccent, in: Capsule())
            }
        }
    }

    private struct OutlineButtonModifier: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 26, *) {
                content
                    .foregroundStyle(.secondary)
                    .glassEffect(.regular.interactive(), in: Capsule())
            } else {
                content
                    .foregroundStyle(.secondary)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    // MARK: - Shared Subviews

    @ViewBuilder
    private func selectedWineRow(wine: WineSearch, viewModel: LogTastingViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "wineglass.fill")
                    .font(.title3)
                    .foregroundStyle(wine.color?.accentColor ?? .wineAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wine.name)
                        .font(Theme.headlineFont)
                    if let producer = wine.producer {
                        Text(producer)
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if viewModel.sharedTastingId == nil {
                    Button("Change") {
                        viewModel.clearSelection()
                    }
                    .font(Theme.captionFont)
                    .foregroundStyle(.wineAccent)
                }
            }

            // Wine stats (if user has tasted this wine before)
            if let stats = viewModel.selectedWineStats {
                HStack(spacing: 16) {
                    Label("\(stats.timesDrunk) times", systemImage: "wineglass")
                    Label(String(format: "%.1f avg", stats.averageRating), systemImage: "star.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func wineResultRow(wine: WineSearch) -> some View {
        HStack(spacing: Theme.smallSpacing) {
            Image(systemName: "wineglass.fill")
                .font(.title3)
                .foregroundStyle(wine.color?.accentColor ?? .wineAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(wine.name)
                    .font(Theme.bodyFont)
                    .foregroundStyle(.primary)
                if let producer = wine.producer {
                    Text(producer)
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Label Scanning

    private func scanLabel(_ image: UIImage, viewModel: LogTastingViewModel) {
        isScanning = true
        scanWarning = nil
        scanFoundNoText = false
        // Clear any previous results so a re-scan doesn't show stale hits.
        viewModel.searchResults = []
        viewModel.searchQuery = ""
        viewModel.pendingScanImage = nil
        Task {
            defer { isScanning = false }
            do {
                let result = try await WineLabelScanner.scan(image)
                Log.info("Wine label scan result — producer: \(result.producer ?? "nil"), name: \(result.name ?? "nil"), vintage: \(result.vintage.map(String.init) ?? "nil"), confident: \(result.isConfident), query: \"\(result.searchQuery)\", rawLines: \(result.rawLines)")
                let query = result.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !result.isConfident || query.isEmpty {
                    scanWarning = "Couldn't confidently identify the wine from the label. Check or edit the search text below."
                }
                // Prefill the parsed vintage if the field is still empty.
                if let vintage = result.vintage, viewModel.vintageText.trimmingCharacters(in: .whitespaces).isEmpty {
                    viewModel.vintageText = String(vintage)
                }
                // Keep the scanned photo pending; it's attached once the user picks the matched wine.
                if !query.isEmpty {
                    viewModel.pendingScanImage = image
                    viewModel.searchQuery = query
                    viewModel.search()
                }
            } catch WineLabelScanner.ScanError.noTextFound {
                scanFoundNoText = true
                scanWarning = "No readable text found on the label. Try again with a clearer, well-lit photo."
            } catch {
                Log.error("Wine label scan failed", error: error)
                scanWarning = "Couldn't read the label. Try again or search by name."
            }
        }
    }
}

#Preview {
    LogTastingView()
        .environment(WineService(apiClient: APIClient(
            serverURL: AppConfig.serverURL,
            authService: AuthService()
        )))
        .environment(JournalService(apiClient: APIClient(
            serverURL: AppConfig.serverURL,
            authService: AuthService()
        )))
        .environment(PhotoService(apiClient: APIClient(
            serverURL: AppConfig.serverURL,
            authService: AuthService()
        )))
        .environment(LocationService())
        .environment(SocialService(apiClient: APIClient(
            serverURL: AppConfig.serverURL,
            authService: AuthService()
        )))
}
