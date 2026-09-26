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

    /// True while offerings are being fetched from RevenueCat/App Store, so a paywall surface can
    /// show a neutral loader before deciding between the paywall and the generic error.
    private(set) var offeringsLoading: Bool = true

    /// True when the offerings fetch failed or returned no purchasable products (RevenueCat error
    /// 23 and its kin). Drives a GENERIC "couldn't load subscriptions" message in the UI — the
    /// underlying RevenueCat error is only ever logged (to Datadog), never shown to the user.
    private(set) var offeringsFailed: Bool = false

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
            await loadOfferings()
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

    /// Fetches offerings up front and records whether they loaded, so the paywall surfaces can
    /// show a GENERIC error instead of RevenueCat's own when the fetch fails (notably error 23:
    /// the App Store returned no products for the current offering).
    ///
    /// The underlying RevenueCat error — domain, code, and full `userInfo` (which carries
    /// `rc_root_error` / the readable code) — is logged via `Log.error`, so it ships to Datadog on
    /// TestFlight and production. This is the diagnostic path that does NOT need the Xcode console
    /// or another deploy: the real reason lands in Datadog. It is never shown to the user.
    func loadOfferings() async {
        guard isConfigured else { return }

        offeringsLoading = true

        do {
            let offerings = try await Purchases.shared.offerings()

            guard let current = offerings.current else {
                offeringsFailed = true
                offeringsLoading = false
                Log.error("RevenueCat has no CURRENT offering. Offerings present: \(Array(offerings.all.keys))")
                return
            }

            let productIDs = current.availablePackages.map { $0.storeProduct.productIdentifier }

            if current.availablePackages.isEmpty {
                offeringsFailed = true
                offeringsLoading = false
                Log.error("RevenueCat current offering '\(current.identifier)' has NO products — the App Store returned none (error 23 territory). Check product IDs, availability per storefront, and allow time for propagation.")
                return
            }

            offeringsFailed = false
            offeringsLoading = false
            Log.info("RevenueCat offerings loaded: current='\(current.identifier)', \(current.availablePackages.count) package(s), products=\(productIDs)")
        } catch {
            offeringsFailed = true
            offeringsLoading = false

            // Ship the underlying RevenueCat error to Datadog: domain, code, and the full userInfo
            // (rc_root_error / readable_error_code live here). This is what tells 'no products for
            // offering' apart from an auth/key/network failure — without another deploy.
            let ns = error as NSError
            Log.error(
                "RevenueCat offerings fetch failed (likely the subscription-load error users hit)",
                error: error,
                attributes: [
                    "rc_domain": ns.domain,
                    "rc_code": ns.code,
                    "rc_userInfo": String(describing: ns.userInfo)
                ]
            )
        }
    }
}
