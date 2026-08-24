import Foundation
import OpenAPIRuntime

// MARK: - Type Aliases for Generated OpenAPI Schema Types

typealias JournalEntry = Components.Schemas.JournalEntryDto
typealias FeedJournalEntry = Components.Schemas.FeedJournalEntryDto
typealias WineSummary = Components.Schemas.WineSummary
typealias WineSearch = Components.Schemas.WineSearchDto
typealias WineStats = Components.Schemas.UserWineStats
typealias Stats = Components.Schemas.UserStats
typealias MapResponse = Components.Schemas.MapData
typealias LocationPin = Components.Schemas.LocationPin
typealias Photo = Components.Schemas.PhotoDto
typealias CreateJournalEntryBody = Components.Schemas.CreateJournalEntryRequest

// MARK: - Backwards Compatibility

/// Kept for transitional period — prefer `JournalEntry`
typealias Tasting = Components.Schemas.JournalEntryDto
typealias CreateTastingBody = Components.Schemas.CreateJournalEntryRequest
