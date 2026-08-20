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

    @State private var viewModel: LogTastingViewModel?
    @State private var currentStep: WizardStep = .wine
    @State private var shakeWineSection = false

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
            case .wine: "Which wine did you have?"
            case .rating: "How was it?"
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let viewModel {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Button("Save") {
                                Task { await viewModel.saveTasting() }
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(.wineAccent)
                            .disabled(!viewModel.canSave)
                        }
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = LogTastingViewModel(
                    wineService: wineService,
                    tastingService: tastingService,
                    photoService: photoService,
                    locationService: locationService
                )
            }
        }
        .onChange(of: viewModel?.savedTasting?.id) { _, tastingId in
            if tastingId != nil { dismiss() }
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
                }
                .modifier(FilledButtonModifier())
            } else {
                Button {
                    Task { await viewModel.saveTasting() }
                } label: {
                    Text("Save")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .modifier(FilledButtonModifier())
                .disabled(!viewModel.canSave)
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

    // MARK: - Step 1: Wine

    @ViewBuilder
    private func wineStep(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(spacing: 16) {
                // Search card
                glassCard {
                    if let wine = viewModel.selectedWine {
                        selectedWineRow(wine: wine, viewModel: viewModel)
                    } else {
                        VStack(spacing: 12) {
                            HStack {
                                TextField("Search wines...", text: $vm.searchQuery)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.plain)
                                    .onSubmit { viewModel.search() }
                                Button {
                                    viewModel.search()
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.wineAccent)
                                }
                                .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                            if viewModel.isSearching {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Searching...")
                                        .font(Theme.captionFont)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }

                            ForEach(viewModel.searchResults, id: \.name) { wine in
                                Button {
                                    viewModel.selectWine(wine)
                                } label: {
                                    wineResultRow(wine: wine)
                                }
                                if wine.name != viewModel.searchResults.last?.name {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                // Separate "Create wine manually" button
                if viewModel.selectedWine == nil {
                    NavigationLink {
                        CreateWineView(selectedWine: $vm.selectedWine, selectedWineId: $vm.selectedWineId)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Create wine manually")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.wineAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .modifier(OutlineButtonModifier())
                }

                // Vintage picker (shown once wine is selected)
                if viewModel.selectedWine != nil {
                    glassCard {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar")
                                .foregroundStyle(.wineAccent)
                                .frame(width: 20)
                            Text("Vintage")
                                .font(Theme.bodyFont)
                            Spacer()
                            Picker("", selection: $vm.vintageYear) {
                                Text("None").tag(nil as Int?)
                                ForEach((1900...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                                    Text(String(year)).tag(year as Int?)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.wineAccent)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
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
        ScrollView {
            VStack(spacing: 16) {
                glassCard {
                    VStack(spacing: Theme.largeSpacing) {
                        Text("\(viewModel.rating)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(.wineAccent)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: viewModel.rating)

                        Text("out of 10")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Slider(
                            value: Binding(
                                get: { Double(viewModel.rating) },
                                set: { newValue in
                                    let newRating = Int(newValue)
                                    if newRating != viewModel.rating {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                    }
                                    viewModel.rating = newRating
                                }
                            ),
                            in: 1...10,
                            step: 1
                        )
                        .tint(.wineAccent)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Rating: \(viewModel.rating) out of 10")
                    .accessibilityValue("\(viewModel.rating)")
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }

    // MARK: - Step 3: Details

    @ViewBuilder
    private func detailsStep(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        Form {
            Section("Tasting") {
                TextField("Tasting notes", text: $vm.notes, axis: .vertical)
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

    // MARK: - Step 4: Location

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
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            } else {
                content
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
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
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
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
        HStack {
            if let color = wine.color {
                WineColorIndicator(color: color)
            }
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
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func wineResultRow(wine: WineSearch) -> some View {
        HStack(spacing: Theme.smallSpacing) {
            if let color = wine.color {
                WineColorIndicator(color: color)
            }
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
