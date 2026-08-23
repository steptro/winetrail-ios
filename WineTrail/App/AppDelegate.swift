import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import DatadogCore
import DatadogLogs

class AppDelegate: NSObject, UIApplicationDelegate {

    /// Set by the app once the service layer is initialised.
    /// Used to forward FCM token refreshes to the backend.
    var deviceService: DeviceService?

    /// Set by the app to handle deep link routing from push notifications.
    var appState: AppState?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Datadog Logging
        let datadogToken = Bundle.main.object(forInfoDictionaryKey: "DATADOG_CLIENT_TOKEN") as? String ?? ""
        
        if !datadogToken.isEmpty {
            // Attach app version to all logs
            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
            
            Datadog.initialize(
                with: Datadog.Configuration(
                    clientToken: datadogToken,
                    env: "production",
                    site: .eu1,
                    service: "WineTrail",
                    version: appVersion
                ),
                trackingConsent: .granted
            )
            Logs.enable()
        }

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Handle silent push notifications (e.g. friend_request_sync)
        let type = userInfo["type"] as? String
        if type == "friend_request_sync" {
            NotificationCenter.default.post(name: .friendRequestsDidChange, object: nil)
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task { await deviceService?.onTokenRefresh(token) }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Called when a notification is tapped (app in background or terminated).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = DeepLink.from(userInfo: userInfo) {
            Task { @MainActor in
                appState?.pendingDeepLink = deepLink
            }
        }
        completionHandler()
    }

    /// Called when a notification arrives while app is in foreground — show it as a banner.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
