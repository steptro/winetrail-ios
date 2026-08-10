import Foundation
import OpenAPIRuntime

/// Client-side wine sort options with display names.
/// Maps to the generated `Components.Schemas.WineSortOption` for API calls.
enum WineSort: String, CaseIterable, Identifiable {
    case lastTasted
    case averageRating
    case timesDrunk
    case name

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lastTasted: return "Last Tasted"
        case .averageRating: return "Rating"
        case .timesDrunk: return "Times Drunk"
        case .name: return "Name"
        }
    }

    /// Maps to the generated API sort option. Returns nil for client-only sorts (like name).
    var apiSortOption: Components.Schemas.WineSortOption? {
        switch self {
        case .lastTasted: return .LAST_TASTED
        case .averageRating: return .AVERAGE_RATING
        case .timesDrunk: return .TIMES_DRUNK
        case .name: return nil // Name sort not supported by API — handled client-side
        }
    }
}
