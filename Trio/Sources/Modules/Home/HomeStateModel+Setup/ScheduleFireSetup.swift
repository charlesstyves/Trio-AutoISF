import CoreData
import Foundation

/// Re-entrancy guard. `provider.activate` can take a couple of seconds on the pump-sync path, and
/// the timer fires every 5s — without a flag a slow activation could overlap with the next tick's
/// sweep and cause a double-fire.
@MainActor private var scheduleFireSweepInFlight: Bool = false

extension Home.StateModel {
    /// Schedule-firing sweep, run on the 5-second `timerDate` tick. Mirrors
    /// `checkExpiredProfileAndAutoRevert()`.
    ///
    /// For every enabled `ProfileScheduleStored`: if the next fire computed from the stored
    /// `lastFiredAt` (or createdAt, if never fired) is in the past, activate the target profile for
    /// the schedule's duration and stamp `lastFiredAt = occurrence`. Missed fires during sleep are
    /// reconciled on the next tick — same mechanism as the expiry sweep.
    ///
    /// **Prototype scope:** only timed (`.hours`) schedules fire automatically. Indefinite and
    /// `.untilNext` schedules require user confirmation at fire time (pump-save dialog) and are
    /// skipped here; they will be handled in PR 5 via actionable local notifications.
    @MainActor func checkDueSchedulesAndFire() async {
        guard !scheduleFireSweepInFlight else { return }
        guard let resolver = resolver else { return }
        scheduleFireSweepInFlight = true
        defer { scheduleFireSweepInFlight = false }

        let context = CoreDataStack.shared.newTaskContext()
        let now = Date()

        struct DueFire {
            let scheduleID: UUID
            let profileID: UUID
            let occurrence: Date
            let duration: ProfileSchedule.Duration
            let isOnce: Bool
            let objectID: NSManagedObjectID
        }

        let due: [DueFire] = await context.perform {
            let request = ProfileScheduleStored.fetch(.enabledSchedule)
            let rows = (try? context.fetch(request)) ?? []
            return rows.compactMap { row -> DueFire? in
                guard let sid = row.id,
                      let pid = row.profileID,
                      let rule = row.rule,
                      let duration = row.duration
                else { return nil }
                let anchor = row.lastFiredAt ?? row.createdAt ?? .distantPast
                guard let next = rule.nextFire(after: anchor), next <= now else { return nil }
                let isOnce: Bool = {
                    if case .once = rule.repeatRule { return true }
                    return false
                }()
                return DueFire(
                    scheduleID: sid,
                    profileID: pid,
                    occurrence: next,
                    duration: duration,
                    isOnce: isOnce,
                    objectID: row.objectID
                )
            }
            .sorted { $0.occurrence < $1.occurrence }
        }

        guard !due.isEmpty else { return }

        let provider = AdaptProfile.Provider(resolver: resolver)

        for fire in due {
            switch fire.duration {
            case let .hours(h):
                let outcome = await provider.activate(
                    id: fire.profileID,
                    durationMinutes: h * 60,
                    confirmedPumpSync: true
                )
                if outcome != .success {
                    debug(.coreData, "Schedule \(fire.scheduleID) fire failed: \(outcome)")
                    continue
                }
            case .indefinite,
                 .untilNext:
                debug(
                    .coreData,
                    "Schedule \(fire.scheduleID) indefinite fire skipped — Flow B not yet implemented"
                )
                continue
            }

            await context.perform {
                guard let row = try? context.existingObject(with: fire.objectID) as? ProfileScheduleStored
                else { return }
                row.lastFiredAt = fire.occurrence
                if fire.isOnce {
                    row.enabled = false
                }
                try? context.save()
            }
        }
    }
}
