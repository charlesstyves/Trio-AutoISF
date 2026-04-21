import Combine
import CoreData
import Foundation

enum AdaptProfile {
    enum Config {}
}

/// Lightweight, ObservableObject-friendly view of a `ProfileStored` row. Decoupled from Core Data
/// object lifetime — SwiftUI lists render these, mutations go through `AdaptProfileProvider`.
struct AdaptProfileListItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let createdAt: Date
    let isActive: Bool
    let expiresAt: Date?
}

protocol AdaptProfileProvider: Provider {
    func fetchAll() async -> [AdaptProfileListItem]
    func rename(id: UUID, to newName: String) async
    func delete(id: UUID) async

    /// Pump-supported basal rates (concentration-adjusted). nil when no pump manager is active —
    /// caller should fall back to rounding to a default increment.
    var supportedBasalRates: [Decimal]? { get }

    /// Persist a new profile snapshot. Returns the new id, or nil on failure.
    func saveNewProfile(name: String, preferences: Preferences, therapy: TherapyBundle) async -> UUID?
}
