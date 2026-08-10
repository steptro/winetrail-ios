import SwiftUI

// MARK: - Wine Trail Color Palette

extension Color {
    // MARK: Primary

    // NOTE: `wineAccent` is auto-generated from the WineAccent color asset.
    // Do not redeclare it here.

    // MARK: Wine Color Accents
    // Fixed-value accent colors used for wine-type indicators and badges.
    // These intentionally stay constant across light/dark mode for recognizability.

    /// Deep red for RED wines
    static let wineRed = Color(red: 0.5, green: 0.1, blue: 0.15)

    /// Warm gold for WHITE wines
    static let wineGold = Color(red: 0.8, green: 0.7, blue: 0.3)

    /// Soft pink for ROSÉ wines
    static let wineRose = Color(red: 0.9, green: 0.5, blue: 0.5)

    /// Amber-orange for ORANGE wines
    static let wineOrange = Color(red: 0.9, green: 0.55, blue: 0.2)

    /// Pale champagne for SPARKLING wines
    static let wineSparkling = Color(red: 0.85, green: 0.82, blue: 0.6)

    // MARK: Semantic Colors
    // System colors that automatically adapt to light/dark mode and
    // work well with iOS 26 Liquid Glass translucency.

    /// Primary burgundy — for tinting elements where asset catalog color isn't available
    static let winePrimary = Color(red: 0.45, green: 0.1, blue: 0.2)

    /// App background — uses system default for Liquid Glass compatibility
    static let wineBackground = Color(.systemBackground)

    /// Secondary background for grouped content
    static let wineSecondaryBackground = Color(.secondarySystemBackground)

    /// Primary text color — adapts to dark mode
    static let wineText = Color(.label)

    /// Secondary text color for subtitles and metadata
    static let wineSecondaryText = Color(.secondaryLabel)
}



// MARK: - ShapeStyle Convenience

extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {
    static var wineRed: SwiftUI.Color { Color.wineRed }
    static var wineGold: SwiftUI.Color { Color.wineGold }
    static var wineRose: SwiftUI.Color { Color.wineRose }
    static var wineOrange: SwiftUI.Color { Color.wineOrange }
    static var wineSparkling: SwiftUI.Color { Color.wineSparkling }
    static var winePrimary: SwiftUI.Color { Color.winePrimary }
    static var wineBackground: SwiftUI.Color { Color.wineBackground }
    static var wineSecondaryBackground: SwiftUI.Color { Color.wineSecondaryBackground }
    static var wineText: SwiftUI.Color { Color.wineText }
    static var wineSecondaryText: SwiftUI.Color { Color.wineSecondaryText }
}
