import SwiftUI

/// New Wine wizard — a step-by-step flow for recording a wine tasting.
///
/// Steps: Wine → Rating → Details → Location.
/// The user can save at any step once a wine is selected (the only required field).
/// Dark, warm premium design with glass card surfaces.
struct LogTastingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WineService.self) private var wineService
    @Environment(TastingService.self) private var tastingService
    @Environment(PhotoService.self) private var photoService
    @Environment(LocationService.self) private var locationService

    /// Optional pre-selected wine (e.g. from "Log Again" on wine detail page).
    var preselectedWine: WineSearch?

    @State private var viewModel: LogTastingViewModel?
    @State private var currentStep: WizardStep = .wine
    @State private var shakeWineSection = false
    @State private var showCheers = false

    enum WizardStep: Int, CaseIterable {
        case wine = 0
        case rating = 1
        case photo = 2
        case details = 3
        case location = 4

        var title: String {
            switch self {
            case .wine: "Wine"
            case .rating: "Rating"
            case .photo: "Photo"
            case .details: "Details"
            case .location: "Location"
            }
        }

        var question: String {
            switch self {
            case .wine: "Which wine did you have?"
            case .rating: "How was it?"
            case .photo: "Got a photo?"
            case .details: "What else stood out?"
            case .location: "Where were you?"
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
                            stepProgressBar
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
                ToolbarItem(placement: .confirmationAction) {
                    if let viewModel {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Button {
                                Task { await viewModel.saveTasting() }
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.wineAccent)
                            .disabled(!viewModel.canSave)
                        }
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = LogTastingViewModel(
                    wineService: wineService,
                    tastingService: tastingService,
                    photoService: photoService,
                    locationService: locationService
                )
                if let preselectedWine {
                    vm.selectWine(preselectedWine)
                    currentStep = .rating
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

    // MARK: - Step Content

    @ViewBuilder
    private func stepContent(viewModel: LogTastingViewModel) -> some View {
        TabView(selection: Binding(
            get: { currentStep },
            set: { newStep in
                // Prevent swiping past step 1 without selecting a wine
                if currentStep == .wine && newStep.rawValue > WizardStep.wine.rawValue && viewModel.selectedWine == nil {
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
            wineStep(viewModel: viewModel)
                .tag(WizardStep.wine)
            ratingStep(viewModel: viewModel)
                .tag(WizardStep.rating)
            photoStep(viewModel: viewModel)
                .tag(WizardStep.photo)
            detailsStep(viewModel: viewModel)
                .tag(WizardStep.details)
            locationStep(viewModel: viewModel)
                .tag(WizardStep.location)
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
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(.wineAccent, in: Capsule())
                }
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
        if currentStep == .wine && viewModel.selectedWine == nil {
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

    // MARK: - Step 1: Wine

    @ViewBuilder
    private func wineStep(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        Form {
            if let wine = viewModel.selectedWine {
                Section {
                    selectedWineRow(wine: wine, viewModel: viewModel)
                }

                Section("Vintage") {
                    Picker("Vintage", selection: $vm.vintageYear) {
                        Text("None").tag(nil as Int?)
                        ForEach((1900...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year as Int?)
                        }
                    }
                    .tint(.wineAccent)
                }
            } else {
                Section {
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
                }

                if viewModel.isSearching {
                    Section {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching...")
                                .font(Theme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !viewModel.searchResults.isEmpty {
                    Section("Results") {
                        ForEach(viewModel.searchResults, id: \.name) { wine in
                            Button {
                                viewModel.selectWine(wine)
                            } label: {
                                wineResultRow(wine: wine)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        CreateWineView(selectedWine: $vm.selectedWine, selectedWineId: $vm.selectedWineId)
                    } label: {
                        Label("Create wine manually", systemImage: "plus.circle")
                            .foregroundStyle(.wineAccent)
                    }
                }
            }
        }
        .tint(.wineAccent)
        .offset(x: shakeWineSection ? -8 : 0)
        .animation(
            shakeWineSection
                ? .default.repeatCount(3, autoreverses: true).speed(6)
                : .default,
            value: shakeWineSection
        )
    }

    // MARK: - Step 2: Rating

    @ViewBuilder
    private func ratingStep(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        VStack(spacing: Theme.spacing) {
            // Interactive star display
            RatingView(rating: viewModel.rating, ratingBinding: $vm.rating, starSize: .title)
                .padding(.top, 12)

            // Wine bottle vertical slider
            WineBottleSlider(rating: $vm.rating)
                .frame(width: 70, height: 260)
                .padding(.vertical, 8)

            Text("Drag to rate")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Step 3: Photo

    @ViewBuilder
    private func photoStep(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(spacing: 16) {
                glassCard {
                    PhotoPickerView(selectedImages: $vm.selectedImages)
                }

                if viewModel.selectedImages.isEmpty {
                    Text("You can skip this step — photos are optional.")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }

    // MARK: - Step 4: Details

    @ViewBuilder
    private func detailsStep(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        Form {
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
                    }
                    .pickerStyle(.menu)
                    .tint(.wineAccent)
                    .labelsHidden()
                    .frame(width: 80)
                }
                DatePicker("Date", selection: $vm.tastingDate, in: ...Date(), displayedComponents: .date)
                    .tint(.wineAccent)
            }
        }
        .tint(.wineAccent)
    }

    // MARK: - Step 5: Location

    @ViewBuilder
    private func locationStep(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        Form {
            Section("Location") {
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
        .tint(.wineAccent)
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
                Button("Change") {
                    viewModel.clearSelection()
                }
                .font(Theme.captionFont)
                .foregroundStyle(.wineAccent)
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
    }
}

#Preview {
    LogTastingView()
        .environment(WineService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
        .environment(TastingService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
        .environment(PhotoService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
        .environment(LocationService())
}
