import SwiftUI

/// Log Tasting screen for recording a new wine tasting.
///
/// Presents a form with wine search, rating slider (1-10), and optional fields
/// (notes, food pairing, occasion, price, location, date). Uses environment-injected
/// services and creates the LogTastingViewModel on appear.
struct LogTastingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WineService.self) private var wineService
    @Environment(TastingService.self) private var tastingService
    @Environment(PhotoService.self) private var photoService
    @Environment(LocationService.self) private var locationService

    @State private var viewModel: LogTastingViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    formContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Log Tasting")
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

    // MARK: - Form Content

    @ViewBuilder
    private func formContent(viewModel: LogTastingViewModel) -> some View {
        Form {
            wineSection(viewModel: viewModel)
            ratingSection(viewModel: viewModel)
            detailsSection(viewModel: viewModel)
            locationSection(viewModel: viewModel)
        }
    }

    // MARK: - Wine Search Section

    @ViewBuilder
    private func wineSection(viewModel: LogTastingViewModel) -> some View {
        Section("Wine") {
            if let wine = viewModel.selectedWine {
                selectedWineRow(wine: wine, viewModel: viewModel)
            } else {
                @Bindable var vm = viewModel
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

                if viewModel.isSearching {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching...")
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(viewModel.searchResults, id: \.name) { wine in
                    Button {
                        viewModel.selectWine(wine)
                    } label: {
                        wineResultRow(wine: wine)
                    }
                }
            }
        }
    }

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
        }
    }

    // MARK: - Rating Section

    @ViewBuilder
    private func ratingSection(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        Section("Rating") {
            HStack {
                Text("\(viewModel.rating)")
                    .font(Theme.titleFont)
                    .foregroundStyle(.wineAccent)
                    .frame(minWidth: 30)
                Slider(
                    value: Binding(
                        get: { Double(viewModel.rating) },
                        set: { viewModel.rating = Int($0) }
                    ),
                    in: 1...10,
                    step: 1
                )
                .tint(.wineAccent)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Rating: \(viewModel.rating) out of 10")
            .accessibilityValue("\(viewModel.rating)")
        }
    }

    // MARK: - Details Section (Optional)

    @ViewBuilder
    private func detailsSection(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        Section("Details (Optional)") {
            TextField("Tasting notes", text: $vm.notes, axis: .vertical)
                .lineLimit(3...6)
            TextField("Food pairing", text: $vm.foodPairing)
            TextField("Occasion", text: $vm.occasion)
            TextField("Price", text: $vm.price)
                .keyboardType(.decimalPad)
            TextField("Vintage (e.g. 2020)", text: $vm.vintageText)
                .keyboardType(.numberPad)
            DatePicker("Date", selection: $vm.tastingDate, displayedComponents: .date)
        }
    }

    // MARK: - Location Section

    @ViewBuilder
    private func locationSection(viewModel: LogTastingViewModel) -> some View {
        @Bindable var vm = viewModel
        Section("Location (Optional)") {
            if locationService.authorizationStatus == .authorizedWhenInUse ||
               locationService.authorizationStatus == .authorizedAlways {
                Toggle("Use current location", isOn: $vm.useGPS)
            } else if locationService.authorizationStatus == .notDetermined {
                Button("Enable Location Access") {
                    Task { await locationService.requestPermission() }
                }
            } else {
                Label("Location access denied", systemImage: "location.slash")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            }
            TextField("Location name", text: $vm.locationName)
        }
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
