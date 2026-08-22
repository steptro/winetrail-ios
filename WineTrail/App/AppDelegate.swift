import UIKit
import FirebaseCore
import FirebaseMessaging
import DatadogCore
import DatadogLogs

class AppDelegate: NSObject, UIApplicationDelegate {

    /// Set by the app once the service layer is initialised.
    /// Used to forward FCM token refreshes to the backend.
    var deviceService: DeviceService?

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
                    env: "production"
                    site: .eu1,
                    service: "WineTrail",
                    version: appVersion
                ),
                trackingConsent: .granted
            )
            Logs.enable()
        }

        Messaging.messaging().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task { await deviceService?.onTokenRefresh(token) }
    }
}
