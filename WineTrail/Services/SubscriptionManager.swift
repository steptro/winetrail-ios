import Foundation
import Observation
import RevenueCat

/// Owns the RevenueCat SDK: configuration, identity sync, and the current
/// entitlement state that gates paid features (the AI Sommelier / recommendations).
///
/// Identity is aligned to the backend's internal user id (the same id the
/// RevenueCat webhook resolves against when syncing entitlements server-side),
/// so entitlements follow the account across devices and reinstalls. Call
/// `configure()` once at launch, then `signIn(userId:)` when the account and its
/// internal id are known, and `signOut()` only on an actual sign-out.
///
/// Sign-in and sign-out are deliberately SEPARATE calls: resolving the internal
/// id requires an async `/me` fetch that can fail or lag, and a failed resolve
/// must never be mistaken for a sign-out — logging out mid-session churns the
/// RevenueCat identity and cancels any in-flight purchase.
@MainActor @Observable
final class SubscriptionManager {
    /// Whether the current user holds the `winetrail_pro` entitlement.
    private(set) var isPro: Bool = false

    /// True until the first `CustomerInfo` has been resolved, so callers can
    /// show a neutral loading state instead of flashing the paywall.
    private(set) var isLoading: Bool = true

    /// The app user id RevenueCat is currently logged in as, if any. This is the
    /// backend's internal user id, not the Firebase uid.
    private(set) var appUserID: String?

    private var isConfigured = false

    /// Long-lived observer of RevenueCat's `customerInfo` updates. Keeps `isPro` live so a
    /// mid-session change (notably an expiry) flips the app out of Pro without waiting for a
    /// relaunch or an explicit `refresh()`. Retained so the stream is not torn down.
    private var customerInfoObserver: Task<Void, Never>?

    /// Guards against concurrent identity changes (e.g. a launch sync racing an
    /// auth-change sync) that could interleave logIn/logOut and cancel a purchase.
    private var isSyncingIdentity = false

    /// Kicks off the post-configuration work (entitlement refresh + debug diagnostics).
    /// The SDK itself is configured earlier in `AppDelegate.didFinishLaunching`, before any view
    /// or paywall can touch `Purchases.shared`; this only runs the follow-up that needs the app's
    /// own state. Safe to call once at app startup; no-ops if it has already run.
    func configure() {
        guard !isConfigured else { return }
        isConfigured = true

        // Defensive: if for some reason the SDK was not configured in AppDelegate, do it here so
        // the refresh below has a configured client rather than logging "not configured".
        if !Purchases.isConfigured {
            #if DEBUG
            Purchases.logLevel = .debug
            #else
            Purchases.logLevel = .warn
            #endif
            Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        }

        Task {
            await refresh()
            #if DEBUG
            await logOfferingsDiagnostics()
            #endif
        }

        observeCustomerInfo()
    }

    /// Subscribes to RevenueCat's `customerInfo` updates so entitlement changes (renewals and,
    /// crucially, expirations) are reflected in `isPro` live — the SDK caches `CustomerInfo`, so
    /// without this an expiry that happened mid-session keeps showing Pro until the next relaunch
    /// or explicit refresh. Idempotent: re-subscribing cancels any prior observer first.
    private func observeCustomerInfo() {
        customerInfoObserver?.cancel()
        customerInfoObserver = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
    }

    /// Logs RevenueCat in as the given internal user id, so entitlements follow
    /// the account. No-ops when already logged in as that id (so it is safe to
    /// call repeatedly on auth ticks) and when a sign-in is already in flight.
    ///
    /// Only call this once the internal id is known — never with a placeholder
    /// on a failed `/me` fetch. A failed resolve should simply not call this,
    /// leaving the current identity untouched.
    func signIn(userId: String) async {
        guard isConfigured else { return }
        guard userId != appUserID else { return }
        guard !isSyncingIdentity else { return }

        isSyncingIdentity = true
        defer { isSyncingIdentity = false }

        do {
            let (info, _) = try await Purchases.shared.logIn(userId)
            appUserID = userId
            apply(info)
        } catch {
            Log.error("RevenueCat sign-in failed", error: error)
        }
    }

    /// Sets the RevenueCat subscriber attributes for the current user, so the customer is
    /// identifiable in the dashboard and reachable via the FCM push token.
    ///
    /// Name and email use RevenueCat's reserved setters (`$displayName` / `$email`). The FCM token
    /// is stored as a custom attribute `fcm_token` — RevenueCat's iOS SDK has no reserved setter for
    /// FCM (`$fcmTokens` is populated by other SDKs / the REST API; `setPushToken` takes the raw
    /// APNs `Data`, which is not what Firebase Messaging hands us).
    ///
    /// Safe to call with any subset present; nil/empty values are skipped rather than clearing.
    func setUserAttributes(displayName: String?, email: String?, fcmToken: String?) {
        guard isConfigured else { return }

        let attribution = Purchases.shared.attribution

        if let displayName, !displayName.isEmpty {
            attribution.setDisplayName(displayName)
        }
        if let email, !email.isEmpty {
            attribution.setEmail(email)
        }
        if let fcmToken, !fcmToken.isEmpty {
            attribution.setAttributes(["fcm_token": fcmToken])
        }
    }

    /// Returns RevenueCat to an anonymous id on an actual sign-out. No-ops when
    /// already anonymous. Call this ONLY when the user genuinely signs out —
    /// never as the fallback for a failed id resolve.
    func signOut() async {
        guard isConfigured else { return }
        guard appUserID != nil else { return }
        guard !isSyncingIdentity else { return }

        isSyncingIdentity = true
        defer { isSyncingIdentity = false }

        do {
            let info = try await Purchases.shared.logOut()
            appUserID = nil
            apply(info)
        } catch {
            Log.error("RevenueCat sign-out failed", error: error)
        }
    }

    /// Re-reads the latest `CustomerInfo` and updates `isPro`.
    func refresh() async {
        guard isConfigured else { return }

        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
        } catch {
            Log.error("Failed to fetch RevenueCat customer info", error: error)
            isLoading = false
        }
    }

    private func apply(_ info: CustomerInfo) {
        isPro = info.entitlements[AppConfig.proEntitlementID]?.isActive == true
        isLoading = false
    }

    #if DEBUG
    /// Logs what RevenueCat actually returns for offerings so a configuration
    /// error (code 23) can be diagnosed: whether the current offering exists,
    /// how many packages/products it resolved from the App Store, and the
    /// underlying reason when the fetch fails.
    private func logOfferingsDiagnostics() async {
        Log.debug("RevenueCat: fetching offerings…")
        do {
            let offerings = try await Purchases.shared.offerings()

            Log.debug("RevenueCat: \(offerings.all.count) offering(s) total: \(Array(offerings.all.keys)); current = \(offerings.current?.identifier ?? "nil")")

            if let current = offerings.current {
                let productIDs = current.availablePackages.map { $0.storeProduct.productIdentifier }
                Log.debug("RevenueCat current offering '\(current.identifier)': \(current.availablePackages.count) package(s), products: \(productIDs)")
                if current.availablePackages.isEmpty {
                    Log.error("RevenueCat offering has NO products — App Store returned none. Check the Paid Apps Agreement is Active, the product IDs match, and allow time for propagation.")
                }
            } else {
                Log.error("RevenueCat has no CURRENT offering. In the RevenueCat dashboard, create an Offering, add your products as packages, and mark it Current.")
            }
        } catch {
            let ns = error as NSError
            Log.error("RevenueCat offerings fetch FAILED (this is the error 23 cause): domain=\(ns.domain) code=\(ns.code) userInfo=\(ns.userInfo)", error: error)
        }
    }
    #endif
}
