import Foundation
import UIKit
import Observation
import CoreLocation
import Combine

/// ViewModel for the Log Tasting feature.
///
/// Manages debounced wine search (300ms), form state for all tasting fields,
/// recent wines, auto-location detection, and the save flow (validate → create tasting → upload photos).
@MainActor @Observable
final class LogTastingViewModel {
    private let wineService: WineService
    private let journalService: JournalService
    private let photoService: PhotoService
    private let locationService: LocationService
    private let socialService: SocialService

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
    // MARK: - Recent Wines

    /// The last 5 unique wines the user logged, loaded on init.
    var recentWines: [WineSearch] = []

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

    /// Vintage year as text input (parsed to Int32 on save).
    var vintageText: String = ""

    /// Optional location name (manual entry).
    var locationName: String = ""

    /// Whether to capture GPS coordinates on save. Defaults to true if auto-detected.
    var useGPS = false

    /// Coordinates copied from a friend's shared post (the "Add my rating" flow).
    /// Used verbatim on save when GPS is off, so the copied location includes its pin.
    var copiedLatitude: Double?
    var copiedLongitude: Double?

    /// Date of the tasting (defaults to today).
    var tastingDate = Date()

    /// Photos selected by the user for upload.
    var selectedImages: [UIImage] = []

    /// A label photo captured via scan, attached to the tasting once the user
    /// selects the matched wine. Cleared on selection or a new scan.
    var pendingScanImage: UIImage?

    /// Friends tagged on this post. When non-empty on a fresh post, the backend mints a
    /// shared tasting so tagged friends can add their own rating.
    var taggedFriendIds: [String] = []

    /// When set, this entry joins an existing shared tasting (the "Add my rating" flow).
    /// The backend enforces that the wine matches the shared tasting's wine.
    var sharedTastingId: String? {
        didSet {
            guard sharedTastingId != oldValue, sharedTastingId != nil else { return }
            Task { await loadSharedTastingPhotos() }
        }
    }

    /// Photos from the shared tasting, offered for reuse in the "Add my rating" flow.
    var sharedTastingPhotos: [Components.Schemas.PhotoUploadDto] = []

    /// IDs of shared-tasting photos the user chose to copy onto their entry.
    /// Defaults to all of them (shown selected by default), user can deselect.
    var selectedSharedPhotoIds: Set<String> = []

    // MARK: - Location State

    /// Auto-detected GPS coordinate from background location fetch.
    var autoDetectedCoordinate: CLLocationCoordinate2D?

    private var locationTask: Task<Void, Never>?

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

    /// Clears the auto-detected location and disables GPS.
    func clearAutoDetectedLocation() {
        autoDetectedCoordinate = nil
        useGPS = false
        locationTask?.cancel()
    }

    // MARK: - Initialization

    init(
        wineService: WineService,
        journalService: JournalService,
        photoService: PhotoService,
        locationService: LocationService,
        socialService: SocialService
    ) {
        self.wineService = wineService
        self.journalService = journalService
        self.photoService = photoService
        self.locationService = locationService
        self.socialService = socialService

        // Load recent wines on init
        Task {
            await loadRecentWines()
        }

        // Start auto-location detection if permission is granted
        startAutoLocationDetection()
    }

    // MARK: - Recent Wines

    /// Fetches the last 5 unique wines from the journal timeline.
    func loadRecentWines() async {
        do {
            let timeline = try await journalService.getTimeline(page: 0, size: 10)
            var seen = Set<String>()
            var unique: [WineSearch] = []
            for tasting in timeline.content {
                let key = tasting.wine.id
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                unique.append(WineSearch(
                    wineId: tasting.wine.id,
                    name: tasting.wine.name,
                    producer: tasting.wine.producer,
                    region: tasting.wine.regionName,
                    country: tasting.wine.country,
                    color: tasting.wine.color
                ))
                if unique.count >= 5 { break }
            }
            recentWines = unique
        } catch {
            Log.error("Failed to load recent wines", error: error)
        }
    }

    // MARK: - Auto Location Detection

    /// Starts a background GPS fetch when authorization is already granted. Safe to call
    /// after the user grants permission (e.g. the first-time prompt on New Wine).
    func startAutoLocationDetectionIfAuthorized() {
        startAutoLocationDetection()
    }

    /// Starts background GPS fetch if location permission is already granted.
    private func startAutoLocationDetection() {
        let status = locationService.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }

        // Default to using location when permission is available
        useGPS = true

        locationTask = Task {
            do {
                let coord = try await locationService.getCurrentLocation()
                guard !Task.isCancelled else { return }
                autoDetectedCoordinate = coord
            } catch {
                Log.error("Auto location detection failed", error: error)
            }
        }
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

    /// Attaches the pending scanned label photo (from a successful scan match) and clears it.
    func consumePendingScanImage() {
        if let scanned = pendingScanImage {
            addImage(scanned)
            pendingScanImage = nil
        }
    }

    /// Discards the pending scanned photo without attaching it (e.g. the user picked
    /// a recent wine rather than the scanned match).
    func discardPendingScanImage() {
        pendingScanImage = nil
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
            // Resolve GPS coordinates
            var latitude: Double?
            var longitude: Double?
            if useGPS {
                if let autoCoord = autoDetectedCoordinate {
                    latitude = autoCoord.latitude
                    longitude = autoCoord.longitude
                } else {
                    let coord = try await locationService.getCurrentLocation()
                    latitude = coord.latitude
                    longitude = coord.longitude
                }
            } else if let copiedLatitude, let copiedLongitude {
                // Location copied from a shared post — send the pin so name + coordinates stay consistent.
                latitude = copiedLatitude
                longitude = copiedLongitude
            }

            // Parse vintage from text
            let parsedVintage: Int32? = {
                let trimmed = vintageText.trimmingCharacters(in: .whitespaces)
                guard let value = Int(trimmed) else { return nil }
                return Int32(value)
            }()

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
                tastingDate: nil,
                vintage: parsedVintage,
                taggedUserIds: taggedFriendIds.isEmpty ? nil : taggedFriendIds,
                sharedTastingId: sharedTastingId
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

            // Copy selected photos from the shared tasting onto this entry (respect the 5-photo cap).
            if sharedTastingId != nil, !selectedSharedPhotoIds.isEmpty {
                let remaining = max(5 - selectedImages.count, 0)
                let idsToCopy = sharedTastingPhotos
                    .map { $0.id }
                    .filter { selectedSharedPhotoIds.contains($0) }
                    .prefix(remaining)
                if !idsToCopy.isEmpty {
                    try await photoService.copySharedTastingPhotos(
                        entryId: tasting.id,
                        photoIds: Array(idsToCopy)
                    )
                }
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

    /// Loads the shared tasting's existing photos and selects them all by default.
    func loadSharedTastingPhotos() async {
        guard let sharedTastingId else { return }
        do {
            let photos = try await socialService.getSharedTastingPhotos(sharedTastingId: sharedTastingId)
            sharedTastingPhotos = photos
            selectedSharedPhotoIds = Set(photos.map { $0.id })
        } catch {
            Log.error("Failed to load shared tasting photos", error: error)
        }
    }

    /// Toggles whether a shared-tasting photo will be copied onto the new entry.
    func toggleSharedPhoto(_ photoId: String) {
        if selectedSharedPhotoIds.contains(photoId) {
            selectedSharedPhotoIds.remove(photoId)
        } else {
            selectedSharedPhotoIds.insert(photoId)
        }
    }
}
