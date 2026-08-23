import Foundation
import DatadogLogs

/// Centralized logger that sends logs to both the console and Datadog.
/// Use this instead of `print()` for all app logging.
enum Log {
    private static let logger: LoggerProtocol = {
        let l = Logger.create(
            with: Logger.Configuration(
                name: "winetrail",
                networkInfoEnabled: true,
                remoteLogThreshold: .info
            )
        )
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        l.addAttribute(forKey: "build_number", value: buildNumber)
        return l
    }()

    /// Debug-level log (local only, not sent to Datadog).
    static func debug(_ message: String, attributes: [String: any Encodable] = [:]) {
        #if DEBUG
        print("🐛 [DEBUG] \(message)")
        #endif
        logger.debug(message, attributes: attributes)
    }

    /// Info-level log (sent to Datadog).
    static func info(_ message: String, attributes: [String: any Encodable] = [:]) {
        #if DEBUG
        print("ℹ️ [INFO] \(message)")
        #endif
        logger.info(message, attributes: attributes)
    }

    /// Warning-level log (sent to Datadog).
    static func warn(_ message: String, attributes: [String: any Encodable] = [:]) {
        #if DEBUG
        print("⚠️ [WARN] \(message)")
        #endif
        logger.warn(message, attributes: attributes)
    }

    /// Error-level log (sent to Datadog).
    static func error(_ message: String, error: Error? = nil, attributes: [String: any Encodable] = [:]) {
        #if DEBUG
        print("❌ [ERROR] \(message)\(error.map { " — \($0)" } ?? "")")
        #endif
        logger.error(message, error: error, attributes: attributes)
    }
}
