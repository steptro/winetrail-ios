import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct WineTrailApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // MARK: - Service Graph

    private let authService: AuthService
    private let apiClient: APIClient
    private let deviceService: DeviceService
    private let journalService: JournalService
    private let wineService: WineService
    private let photoService: PhotoService
    private let statsService: StatsService
    private let mapService: MapService
    private let locationService: LocationService
    private let profileService: ProfileService
    private let socialService: SocialService
    private let socialState: SocialState
    private let blockStore: BlockStore
    private let moderationService: ModerationService
    private let agreementStore: AgreementStore
    private let subscriptionManager: SubscriptionManager
    private let assistantService: AssistantService
    private let appState: AppState

    init() {
        FirebaseApp.configure()

        let auth = AuthService()
        auth.startListening()

        let serverURL = AppConfig.serverURL
        let api = APIClient(serverURL: serverURL, authService: auth)

        let device = DeviceService(apiClient: api)
        let journal = JournalService(apiClient: api)
        let wine = WineService(apiClient: api)
        let photo = PhotoService(apiClient: api)
        let stats = StatsService(apiClient: api)
        let map = MapService(apiClient: api)
        let location = LocationService()
        let profile = ProfileService(apiClient: api)
        let social = SocialService(apiClient: api)
        let socialSt = SocialState(socialService: social)
        let blocks = BlockStore()
        let moderation = ModerationService(apiClient: api, blockStore: blocks)
        let agreement = AgreementStore()
        let subscriptions = MainActor.assumeIsolated { SubscriptionManager() }
        let assistant = MainActor.assumeIsolated { AssistantService(authService: auth) }
        let state = AppState(authService: auth, journalService: journal, profileService: profile, agreementStore: agreement)

        self.authService = auth
        self.apiClient = api
        self.deviceService = device
        self.journalService = journal
        self.wineService = wine
        self.photoService = photo
        self.statsService = stats
        self.mapService = map
        self.locationService = location
        self.profileService = profile
        self.socialService = social
        self.socialState = socialSt
        self.blockStore = blocks
        self.moderationService = moderation
        self.agreementStore = agreement
        self.subscriptionManager = subscriptions
        self.assistantService = assistant
        self.appState = state
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(apiClient)
                .environment(deviceService)
                .environment(journalService)
                .environment(wineService)
                .environment(photoService)
                .environment(statsService)
                .environment(mapService)
                .environment(locationService)
                .environment(profileService)
                .environment(socialService)
                .environment(socialState)
                .environment(blockStore)
                .environment(moderationService)
                .environment(agreementStore)
                .environment(subscriptionManager)
                .environment(assistantService)
                .environment(appState)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL, let deepLink = DeepLink.from(url: url) {
                        appState.pendingDeepLink = deepLink
                    }
                }
                .onOpenURL { url in
                    if let deepLink = DeepLink.from(url: url) {
                        appState.pendingDeepLink = deepLink
                    }
                }
                .task {
                    // Configure RevenueCat before auth resolves so its identity
                    // can be aligned to the Firebase uid as soon as it's known.
                    subscriptionManager.configure()

                    // Wire up AppDelegate → DeviceService for FCM token forwarding
                    delegate.deviceService = deviceService
                    delegate.appState = appState
                    delegate.socialState = socialState

                    // Wait for Firebase auth state to be determined, then route accordingly
                    while authService.isLoading {
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                    await appState.determineInitialRoute()

                    // Align the RevenueCat identity with the signed-in account so
                    // entitlements follow the user across devices and reinstalls.
                    // Keyed on the backend's internal user id (what the RevenueCat
                    // webhook resolves against), not the Firebase uid.
                    await syncSubscriptionIdentity()

                    // Register FCM token on every launch to keep it fresh
                    if authService.isAuthenticated {
                        await deviceService.registerTokenOnLaunch()
                        delegate.scheduleBackgroundRefresh()
                        // Sync the authoritative block list so blocked content stays hidden.
                        await moderationService.refreshBlockedUsers()
                    }
                }
                .onChange(of: authService.currentUser?.uid) { _, _ in
                    // Follow genuine sign-in / sign-out transitions only.
                    Task { await syncSubscriptionIdentity() }
                }
        }
    }

    /// Aligns RevenueCat's identity with the auth state: signs in with the backend's
    /// internal user id when authenticated, signs out only when actually signed out.
    ///
    /// A failed `/me` fetch while still authenticated does NOTHING — it must never fall
    /// through to a sign-out, which would churn the RevenueCat identity and cancel any
    /// in-flight purchase.
    private func syncSubscriptionIdentity() async {
        guard authService.isAuthenticated else {
            await subscriptionManager.signOut()
            return
        }

        do {
            let profile = try await profileService.getProfile()
            await subscriptionManager.signIn(userId: profile.id.lowercased())

            // Identify the customer in RevenueCat and store the FCM token for engagement.
            subscriptionManager.setUserAttributes(
                displayName: profile.displayName,
                email: profile.email,
                fcmToken: deviceService.currentFCMToken
            )
        } catch {
            // Transient: leave the current RevenueCat identity untouched and try again
            // on the next auth tick / launch, rather than logging out.
            Log.error("Failed to resolve internal user id for RevenueCat identity", error: error)
        }
    }
}
