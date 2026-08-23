import SwiftUI
import FirebaseCore

@main
struct WineTrailApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // MARK: - Service Graph

    private let authService: AuthService
    private let apiClient: APIClient
    private let deviceService: DeviceService
    private let tastingService: TastingService
    private let wineService: WineService
    private let photoService: PhotoService
    private let statsService: StatsService
    private let mapService: MapService
    private let locationService: LocationService
    private let profileService: ProfileService
    private let socialService: SocialService
    private let socialState: SocialState
    private let appState: AppState

    init() {
        FirebaseApp.configure()

        let auth = AuthService()
        auth.startListening()

//        let serverURL = URL(string: "http://localhost:8091")!
         let serverURL = URL(string: "https://winetrail.stephantromer.dev")!
        let api = APIClient(serverURL: serverURL, authService: auth)

        let device = DeviceService(apiClient: api)
        let tasting = TastingService(apiClient: api)
        let wine = WineService(apiClient: api)
        let photo = PhotoService(apiClient: api)
        let stats = StatsService(apiClient: api)
        let map = MapService(apiClient: api)
        let location = LocationService()
        let profile = ProfileService(apiClient: api)
        let social = SocialService(apiClient: api)
        let socialSt = SocialState(socialService: social)
        let state = AppState(authService: auth, tastingService: tasting, profileService: profile)

        self.authService = auth
        self.apiClient = api
        self.deviceService = device
        self.tastingService = tasting
        self.wineService = wine
        self.photoService = photo
        self.statsService = stats
        self.mapService = map
        self.locationService = location
        self.profileService = profile
        self.socialService = social
        self.socialState = socialSt
        self.appState = state
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(apiClient)
                .environment(deviceService)
                .environment(tastingService)
                .environment(wineService)
                .environment(photoService)
                .environment(statsService)
                .environment(mapService)
                .environment(locationService)
                .environment(profileService)
                .environment(socialService)
                .environment(socialState)
                .environment(appState)
                .task {
                    // Wire up AppDelegate → DeviceService for FCM token forwarding
                    delegate.deviceService = deviceService
                    delegate.appState = appState

                    // Wait for Firebase auth state to be determined, then route accordingly
                    while authService.isLoading {
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                    await appState.determineInitialRoute()

                    // Register FCM token on every launch to keep it fresh
                    if authService.isAuthenticated {
                        await deviceService.registerTokenOnLaunch()
                    }
                }
        }
    }
}
