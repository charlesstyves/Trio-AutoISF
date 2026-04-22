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
    let orderPosition: Int16
    /// Name of the profile this one was created from. `nil` for the seeded Default profile.
    let sourceProfileName: String?
    /// Therapy percentage applied at creation. 100 = unchanged.
    let appliedPercent: Decimal
    /// `true` when the profile's algorithm preferences differ from its source profile.
    /// Ignored when `sourceProfileName` is nil.
    let preferencesChangedFromSource: Bool
    /// `true` when the profile's glucose targets differ from its source profile.
    let targetsChangedFromSource: Bool
    /// Profile that will become active when a timed activation expires. Only meaningful on the
    /// currently-active item while `expiresAt != nil`.
    let previousProfileID: UUID?
}

/// Full decoded content of a stored profile, used to seed the draft editor in edit mode.
struct LoadedProfileContent {
    let id: UUID
    let name: String
    let preferences: Preferences
    let therapy: TherapyBundle
    let sourceProfileID: UUID?
    let sourceProfileName: String?
    let appliedPercent: Decimal
}

/// Outcome of `AdaptProfileProvider.activate`. The `.needsPumpConfirm` case is returned when an
/// indefinite activation would change the pump's scheduled basal; the caller should present a
/// confirmation dialog and retry with `confirmedPumpSync: true`.
enum ActivationOutcome: Equatable {
    case success
    case needsPumpConfirm
    case pumpSyncFailed(String)
    case failed(String)
}

protocol AdaptProfileProvider: Provider {
    func fetchAll() async -> [AdaptProfileListItem]
    func rename(id: UUID, to newName: String) async
    func delete(id: UUID) async

    /// Persist the ordered list's `orderPosition` back to Core Data.
    func applyOrdering(_ orderedIDs: [UUID]) async

    /// Pump-supported basal rates (concentration-adjusted). nil when no pump manager is active —
    /// caller should fall back to rounding to a default increment.
    var supportedBasalRates: [Decimal]? { get }

    /// Persist a new profile snapshot. Returns the new id, or nil on failure.
    func saveNewProfile(
        name: String,
        preferences: Preferences,
        therapy: TherapyBundle,
        sourceProfileID: UUID?,
        appliedPercent: Decimal
    ) async -> UUID?

    /// Update an existing profile's name, preferences, and therapy. If the profile is the active
    /// one, `ActiveProfileMirror` will pick up the subsequent scope writes — we only persist to
    /// the snapshot here.
    func updateProfile(
        id: UUID,
        name: String,
        preferences: Preferences,
        therapy: TherapyBundle
    ) async -> Bool

    /// Load a profile's editable content for the draft editor hub.
    func loadProfileContent(id: UUID) async -> LoadedProfileContent?

    /// Activate a stored profile. `durationMinutes == nil` means indefinite. When indefinite and the
    /// target basal differs from live, pump sync is required — set `confirmedPumpSync = true` after
    /// the user approves the "Save to pump" dialog.
    func activate(id: UUID, durationMinutes: Int?, confirmedPumpSync: Bool) async -> ActivationOutcome
}
