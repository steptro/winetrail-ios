import Foundation
import FirebaseAnalytics

/// Lightweight wrapper for Firebase Analytics event logging.
/// Centralizes all event names and parameters for consistency.
enum WineAnalytics {

    // MARK: - Tasting Events

    static func logTastingCreated(wineId: String, rating: Double) {
        Analytics.logEvent("tasting_created", parameters: [
            "wine_id": wineId,
            "rating": rating
        ])
    }

    static func logTastingEdited(tastingId: String) {
        Analytics.logEvent("tasting_edited", parameters: [
            "tasting_id": tastingId
        ])
    }

    static func logTastingDeleted(tastingId: String) {
        Analytics.logEvent("tasting_deleted", parameters: [
            "tasting_id": tastingId
        ])
    }

    // MARK: - Social Events

    static func logLike(tastingId: String) {
        Analytics.logEvent("tasting_liked", parameters: [
            "tasting_id": tastingId
        ])
    }

    static func logComment(tastingId: String) {
        Analytics.logEvent("comment_added", parameters: [
            "tasting_id": tastingId
        ])
    }

    static func logFriendRequestSent(receiverId: String) {
        Analytics.logEvent("friend_request_sent", parameters: [
            "receiver_id": receiverId
        ])
    }

    static func logFriendRequestAccepted() {
        Analytics.logEvent("friend_request_accepted", parameters: nil)
    }

    // MARK: - Navigation Events

    static func logScreenView(name: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name
        ])
    }

    // MARK: - Wine Events

    static func logWineCreated(wineId: String) {
        Analytics.logEvent("wine_created", parameters: [
            "wine_id": wineId
        ])
    }

    static func logPhotoUploaded(tastingId: String, count: Int) {
        Analytics.logEvent("photo_uploaded", parameters: [
            "tasting_id": tastingId,
            "count": count
        ])
    }

    // MARK: - Onboarding

    static func logOnboardingCompleted(username: String) {
        Analytics.logEvent("onboarding_completed", parameters: [
            "username": username
        ])
    }

    static func logSignUp(method: String) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    static func logLogin(method: String) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: method
        ])
    }
}
