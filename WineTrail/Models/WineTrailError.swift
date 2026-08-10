import Foundation
import HTTPTypes

/// Typed errors for the WineTrail app, providing user-facing messages and structured error handling.
enum WineTrailError: LocalizedError {
    case networkUnavailable
    case unauthorized
    case forbidden
    case notFound
    case validationFailed(message: String)
    case serverError
    case photoTooLarge
    case photoLimitReached
    case locationPermissionDenied
    case locationUnavailable
    case unknown(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection. Please check your network and try again."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You don't have permission to perform this action."
        case .notFound:
            return "The requested item could not be found."
        case .validationFailed(let message):
            return message
        case .serverError:
            return "Something went wrong on our end. Please try again later."
        case .photoTooLarge:
            return "The photo is too large. Please choose a smaller image."
        case .photoLimitReached:
            return "Maximum 5 photos per tasting."
        case .locationPermissionDenied:
            return "Location access is required to tag your location. Enable it in Settings."
        case .locationUnavailable:
            return "Unable to determine your location. Please try again or enter a location name manually."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
}

// MARK: - Error Mapping

extension WineTrailError {
    /// Maps an HTTP response status to the appropriate WineTrailError case.
    static func from(httpStatus: HTTPResponse.Status, message: String? = nil) -> WineTrailError {
        switch httpStatus.code {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 400:
            return .validationFailed(message: message ?? "Invalid request.")
        case 413:
            return .photoTooLarge
        case 422:
            return .photoLimitReached
        case 500...599:
            return .serverError
        default:
            return .unknown(underlying: nil)
        }
    }

    /// Maps a URL/network-level error to WineTrailError.
    static func from(error: Error) -> WineTrailError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorDataNotAllowed:
                return .networkUnavailable
            default:
                return .unknown(underlying: error)
            }
        }
        return .unknown(underlying: error)
    }
}
