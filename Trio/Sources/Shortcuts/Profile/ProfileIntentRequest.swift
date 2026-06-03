import CoreData
import Foundation

/// Bridges App Intents to the AdaptProfile / ProfileScheduler providers.
final class ProfileIntentRequest: BaseIntentsRequest {
    private lazy var adaptProvider = AdaptProfile.Provider(resolver: resolver)
    private lazy var schedulerProvider = ProfileScheduler.Provider(resolver: resolver)

    // MARK: - Listing

    func fetchAllProfiles() async -> [ProfileEntity] {
        let items = await adaptProvider.fetchAll()
        return items.map { ProfileEntity(id: $0.id, name: $0.name) }
    }

    func fetchProfiles(ids: [UUID]) async -> [ProfileEntity] {
        let items = await adaptProvider.fetchAll()
        let wanted = Set(ids)
        return items.filter { wanted.contains($0.id) }.map { ProfileEntity(id: $0.id, name: $0.name) }
    }

    // MARK: - Immediate activation

    /// Activate a profile right now for the given non-zero duration.
    ///
    /// Shortcuts only support timed activations, so `durationMinutes` is required.
    /// Timed activations never trigger pump sync (the active profile's basal
    /// schedule is restored on revert via the anchor), so `.needsPumpConfirm`
    /// is not expected — if returned it surfaces as a generic error.
    ///
    /// Returns `nil` on success, or an error message on failure.
    @MainActor func activateProfile(id: UUID, durationMinutes: Int) async -> String? {
        let outcome = await adaptProvider.activate(
            id: id,
            durationMinutes: durationMinutes,
            confirmedPumpSync: true,
            skipPumpSync: false
        )
        switch outcome {
        case .success: return nil
        case let .failed(msg),
             let .pumpSyncFailed(msg): return msg
        case .needsPumpConfirm: return String(localized: "Pump confirmation required — activate from the app")
        }
    }

    // MARK: - One-shot scheduled activation

    /// Persist a one-off schedule that fires at `fireAt` and activates the given profile.
    /// The existing `ProfileScheduleFirer` background sweep picks it up and runs it.
    func scheduleOnce(
        profileID: UUID,
        fireAt: Date,
        duration: ProfileSchedule.Duration,
        name: String?
    ) async -> Bool {
        var draft = ProfileScheduleDraft()
        draft.profileID = profileID
        draft.repeatRule = .once(fireAt)
        draft.firesAt = []
        draft.duration = duration
        draft.name = name ?? ""
        let id = await schedulerProvider.saveNewSchedule(draft)
        return id != nil
    }
}
