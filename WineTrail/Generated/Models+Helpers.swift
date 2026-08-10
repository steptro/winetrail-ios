import Foundation
import SwiftUI
import OpenAPIRuntime

// MARK: - WineColor Display Helpers

extension Components.Schemas.WineColor {
    var displayName: String {
        switch self {
        case .RED: return "Red"
        case .WHITE: return "White"
        case .ROSE: return "Rosé"
        case .ORANGE: return "Orange"
        case .SPARKLING: return "Sparkling"
        }
    }

    var accentColor: Color {
        switch self {
        case .RED: return .wineRed
        case .WHITE: return .wineGold
        case .ROSE: return .wineRose
        case .ORANGE: return .wineOrange
        case .SPARKLING: return .wineSparkling
        }
    }
}

// MARK: - TastingDto Display Helpers

extension Components.Schemas.TastingDto {
    var tastingDateFormatted: String {
        // The date comes as ISO date string "yyyy-MM-dd"
        return tastingDate
    }
}
