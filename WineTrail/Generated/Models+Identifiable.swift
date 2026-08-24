import Foundation
import OpenAPIRuntime

// MARK: - Identifiable Conformances for SwiftUI

extension Components.Schemas.JournalEntryDto: Identifiable {}

extension Components.Schemas.UserWineStats: Identifiable {
    public var id: String { wine.id }
}

extension Components.Schemas.PhotoDto: Identifiable {}

extension Components.Schemas.LocationPin: Identifiable {
    public var id: String { "\(latitude)-\(longitude)" }
}
