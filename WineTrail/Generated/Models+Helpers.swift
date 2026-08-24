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

// MARK: - JournalEntryDto Display Helpers

extension Components.Schemas.JournalEntryDto {
    var tastingDateFormatted: String {
        return tastingDate
    }
}
