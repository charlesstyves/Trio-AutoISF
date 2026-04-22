import CoreData
import Foundation

/// Re-entrancy guard: `activate()` can take a couple of seconds (pump sync paths
/// and Core Data writes), and the timer fires every 5s. Without a flag a slow
/// activate could overlap with the next tick's check.
@MainActor private var profileExpirationSweepInFlight: Bool = false

extension Home.StateModel {
    /// Auto-expiration sweep for the active timed profile, run on the 5-second
    /// `timerDate` tick. Mirrors how Override / TempTarget chips refresh:
    /// the tick re-renders the Home adjustment area AND gives us a hook to
    /// flip Core Data state so the `@FetchRequest` for `activeProfile` stops
    /// returning a stale row.
    ///
    /// If the active profile's `expiresAt` has passed:
    ///  - With an anchor (`previousProfileID`): re-activate it indefinitely via
    ///    `AdaptProfile.Provider.activate`. The anchor is, by construction, the
    ///    last indefinite profile (its basal is already on the pump), so the
    ///    pump sync is pre-confirmed — same contract as `revertActiveProfile()`.
    ///  - Without an anchor: clear `isActive` / `expiresAt` in place. No pump
    ///    write (timed activations never touched the pump anyway).
    @MainActor func checkExpiredProfileAndAutoRevert() async {
        guard !profileExpirationSweepInFlight else { return }
        guard let resolver = resolver else { return }
        profileExpirationSweepInFlight = true
        defer { profileExpirationSweepInFlight = false }

        let context = CoreDataStack.shared.newTaskContext()

        struct Expired {
            let objectID: NSManagedObjectID
            let previousID: UUID?
        }

        let expired: Expired? = await context.perform {
            let req = ProfileStored.fetchRequest()
            req.predicate = NSPredicate(format: "isActive == %@", true as NSNumber)
            req.fetchLimit = 1
            guard let active = try? context.fetch(req).first,
                  let expiresAt = active.expiresAt,
                  expiresAt <= Date()
            else { return nil }
            return Expired(objectID: active.objectID, previousID: active.previousProfileID)
        }
        guard let expired = expired else { return }

        if let previousID = expired.previousID {
            let provider = AdaptProfile.Provider(resolver: resolver)
            _ = await provider.activate(id: previousID, durationMinutes: nil, confirmedPumpSync: true)
            return
        }

        // No anchor — just deactivate in place so the chip stops showing.
        await context.perform {
            guard let profile = try? context.existingObject(with: expired.objectID) as? ProfileStored else { return }
            profile.isActive = false
            profile.expiresAt = nil
            try? context.save()
        }
    }
}
