import Foundation
import OpenAPIRuntime

// MARK: - Identifiable Conformances for SwiftUI

extension Components.Schemas.TastingDto: Identifiable {}

extension Components.Schemas.WineWithStats: Identifiable {}

extension Components.Schemas.PhotoDto: Identifiable {}

extension Components.Schemas.LocationPin: Identifiable {
    public var id: String { "\(latitude)-\(longitude)" }
}
