import Foundation
import UIKit
import Observation

/// ViewModel for the Log Tasting feature.
///
/// Manages debounced wine search (300ms), form state for all tasting fields,
/// and the save flow (validate → create tasting → upload photos).
@MainActor @Observable
final class LogTastingViewModel {
    private let wineService: WineService
    private let journalService: JournalService
    private let photoService: PhotoService
    private let locationService: LocationService

    // MARK: - Search State

    /// The current wine search query text.
    var searchQuery = ""

    /// Results from the debounced wine search.
    var searchResults: [WineSearch] = []

    /// The wine selected by the user from search results.
    var selectedWine: WineSearch?

    /// The wine ID for user-created wines (used when externalSource/externalId are not available).
    var selectedWineId: String?

    /// Stats for the selected wine (if the user has tasted it before).
    var selectedWineStats: Components.Schemas.UserWineStats?

    /// Whether a search request is in progress.
    var isSearching = false

    /// Whether the user has performed at least one search.
    var hasSearched = false

    private var searchTask: Task<Void, Never>?

    // MARK: - Form State

    /// Rating from 0.5 to 5.0 in half-star increments. Defaults to 3.0.
    var rating: Double = 3.0

    /// Optional tasting notes.
    var notes: String = ""

    /// Optional food pairing description.
    var foodPairing: String = ""

    /// Optional occasion description.
    var occasion: String = ""

    /// Optional price paid.
    var price: String = ""

    /// Currency code (ISO 4217). Defaults to EUR.
    var currency: String = "EUR"

    /// Optional vintage year text (parsed to Int32 on save).
    var vintageText: String = ""

    /// Optional vintage year selected from picker.
    var vintageYear: Int?

    /// Optional location name (manual entry).
    var locationName: String = ""

    /// Whether to capture GPS coordinates on save.
    var useGPS = false

    /// Date of the tasting (defaults to today).
    var tastingDate = Date()

    /// Photos selected by the user for upload.
    var selectedImages: [UIImage] = []

    // MARK: - UI State

    /// Whether a save operation is in progress.
    var isSaving = false

    /// User-facing error message, if any.
    var error: String?

    /// The saved tasting returned from the backend on success.
    var savedTasting: Tasting?

    /// Whether the form can be submitted (wine selected and not currently saving).
    var canSave: Bool {
        selectedWine != nil && !isSaving
    }

    // MARK: - Initialization

    init(
        wineService: WineService,
        journalService: JournalService,
        photoService: PhotoService,
        locationService: LocationService
    ) {
        self.wineService = wineService
        self.journalService = journalService
        self.photoService = photoService
        self.locationService = locationService
    }

    // MARK: - Wine Search

    /// Searches for wines matching the current query.
    /// Called explicitly when the user taps the search button.
    func search() {
        searchTask?.cancel()

        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            do {
                let locale = Locale.current.language.languageCode?.identifier ?? "en"
                let results = try await wineService.search(query: trimmed, locale: locale)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                guard !Task.isCancelled else { return }
                Log.error("Wine search failed", error: error)
                searchResults = []
            }
            isSearching = false
            hasSearched = true
        }
    }

    /// Selects a wine from search results and clears the search state.
    func selectWine(_ wine: WineSearch) {
        selectedWine = wine
        selectedWineStats = nil
        searchResults = []
        searchQuery = wine.name
        // Look up stats for this wine if it has a wineId (user has tasted it before)
        if let wineId = wine.wineId {
            Task {
                await loadWineStats(wineId: wineId)
            }
        }
    }

    /// Loads stats for a wine by its ID from the dedicated stats endpoint.
    private func loadWineStats(wineId: String) async {
        do {
            let stats = try await journalService.getWineStats(wineId: wineId)
            selectedWineStats = stats
        } catch {
            Log.error("Failed to load wine stats", error: error)
        }
    }

    /// Clears the currently selected wine to allow re-searching.
    func clearSelection() {
        selectedWine = nil
        selectedWineId = nil
        selectedWineStats = nil
        searchQuery = ""
        searchResults = []
        hasSearched = false
    }

    // MARK: - Save Tasting

    /// Validates form state, creates the tasting on the backend, and uploads any photos.
    ///
    /// On success, sets `savedTasting` which the view can observe to dismiss.
    /// On failure, sets `error` with a user-facing message.
    func saveTasting() async {
        guard let wine = selectedWine else {
            error = "Please select a wine."
            return
        }

        isSaving = true
        error = nil

        do {
            // Resolve GPS coordinates if enabled
            var latitude: Double?
            var longitude: Double?
            if useGPS {
                let coord = try await locationService.getCurrentLocation()
                latitude = coord.latitude
                longitude = coord.longitude
            }

            // Format tasting date as yyyy-MM-dd
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")

            // Build the request body
            let request = CreateTastingBody(
                wineId: wine.wineId ?? selectedWineId,
                externalSource: wine.externalSource,
                externalId: wine.externalId,
                rating: rating,
                notes: notes.isEmpty ? nil : notes,
                foodPairing: foodPairing.isEmpty ? nil : foodPairing,
                occasion: occasion.isEmpty ? nil : occasion,
                price: Double(price).map { (($0 * 100).rounded() / 100) },
                currency: price.isEmpty ? nil : currency,
                latitude: latitude,
                longitude: longitude,
                locationName: locationName.isEmpty ? nil : locationName,
                tastingDate: dateFormatter.string(from: tastingDate),
                vintage: vintageYear.map { Int32($0) }
            )

            // Create the tasting
            let tasting = try await journalService.createTasting(request)

            // Upload photos if any were selected
            if !selectedImages.isEmpty {
                _ = try await photoService.uploadPhotos(
                    tastingId: tasting.id,
                    images: selectedImages
                )
                WineAnalytics.logPhotoUploaded(tastingId: tasting.id, count: selectedImages.count)
            }

            WineAnalytics.logTastingCreated(wineId: tasting.wine.id, rating: Double(tasting.rating))
            savedTasting = tasting
        } catch {
            Log.error("Failed to save tasting", error: error)
            self.error = "Something went wrong. Please try again."
        }

        isSaving = false
    }

    // MARK: - Photo Management

    /// Adds an image to the selected photos (max 5).
    func addImage(_ image: UIImage) {
        guard selectedImages.count < 5 else { return }
        selectedImages.append(image)
    }

    /// Removes an image at the given index.
    func removeImage(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
    }

    /// Whether additional photos can be added.
    var canAddPhoto: Bool {
        selectedImages.count < 5
    }
}
