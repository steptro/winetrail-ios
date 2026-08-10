import SwiftUI

/// Central design-system theme providing typography, spacing, and corner radius constants.
/// Uses system fonts (San Francisco) with a clear hierarchy optimized for iOS 26 Liquid Glass.
enum Theme {
    // MARK: - Typography

    /// Large titles — screen headers and prominent headings.
    static let titleFont: Font = .largeTitle.weight(.bold)

    /// Headlines — section headers and card titles.
    static let headlineFont: Font = .headline.weight(.semibold)

    /// Body — primary content text.
    static let bodyFont: Font = .body

    /// Caption — metadata, timestamps, and secondary information.
    static let captionFont: Font = .caption.weight(.regular)

    /// Subheadline — supporting text below headlines.
    static let subheadlineFont: Font = .subheadline

    // MARK: - Spacing

    /// Standard spacing between elements (16pt).
    static let spacing: CGFloat = 16

    /// Compact spacing for tighter layouts (8pt).
    static let smallSpacing: CGFloat = 8

    /// Generous spacing for section separation (24pt).
    static let largeSpacing: CGFloat = 24

    // MARK: - Corner Radius

    /// Default corner radius for cards and containers (12pt).
    static let cornerRadius: CGFloat = 12

    /// Smaller corner radius for badges and compact elements (8pt).
    static let smallCornerRadius: CGFloat = 8
}
