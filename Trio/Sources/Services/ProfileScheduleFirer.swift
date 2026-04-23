import CoreData
import Foundation
import Swinject

/// App-lifetime service that fires due `ProfileScheduleStored` rows. Registered in
/// `ServiceAssembly` with container scope and resolved at startup so the sweep loop outlives any
/// view. This replaces an earlier attempt that ran the check inside `Home.StateModel`'s 5-second
/// timer — that only worked while Home was visible, so navigating into Settings halted firing.
///
/// The loop sleeps for `sweepInterval` between checks. A re-entrancy guard prevents overlap while
/// `provider.activate()` is in flight on the pump-sync path.
///
/// **Prototype scope:** only timed (`.hours`) schedules fire automatically. Indefinite and
/// `.untilNext` require user-confirmed pump save and are deferred to PR 5 (actionable local
/// notifications). Once-schedules auto-disable after firing.
final class ProfileScheduleFirer {
    private let resolver: Resolver
    private let coreDataStack = CoreDataStack.shared

    /// Time between sweeps. Testing: 5s. Production target: 15s. TODO: restore 15s before ship.
    private let sweepInterval: TimeInterval = 5

    private var loopTask: Task<Void, Never>?
    private var sweepInFlight = false

    init(resolver: Resolver) {
        self.resolver = resolver
        debug(.coreData, "ProfileScheduleFirer init — starting sweep loop")
        startLoop()
    }

    deinit {
        loopTask?.cancel()
    }

    private func startLoop() {
        loopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await sweep()
                try? await Task.sleep(nanoseconds: UInt64(sweepInterval * 1_000_000_000))
            }
        }
    }

    private func sweep() async {
        guard !sweepInFlight else {
            debug(.coreData, "ProfileScheduleFirer: sweep skipped (in flight)")
            return
        }
        sweepInFlight = true
        defer { sweepInFlight = false }

        let context = coreDataStack.newTaskContext()
        let now = Date()
        debug(.coreData, "ProfileScheduleFirer: sweep tick @ \(now)")

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
            debug(.coreData, "ProfileScheduleFirer: \(rows.count) enabled schedules in store")
            return rows.compactMap { row -> DueFire? in
                guard let sid = row.id,
                      let pid = row.profileID,
                      let rule = row.rule,
                      let duration = row.duration
                else {
                    debug(.coreData, "ProfileScheduleFirer: row decode failed (id/profile/rule/duration)")
                    return nil
                }
                let anchor = row.lastFiredAt ?? row.createdAt ?? .distantPast
                let nextMaybe = rule.nextFire(after: anchor)
                debug(
                    .coreData,
                    "ProfileScheduleFirer: schedule \(sid) anchor=\(anchor) next=\(String(describing: nextMaybe)) now=\(now)"
                )
                guard let next = nextMaybe, next <= now else { return nil }
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
        debug(.coreData, "ProfileScheduleFirer: \(due.count) due — firing")

        let provider = AdaptProfile.Provider(resolver: resolver)

        for fire in due {
            switch fire.duration {
            case let .minutes(m):
                debug(.coreData, "ProfileScheduleFirer: activating \(fire.profileID) for \(m) min")
                let outcome = await provider.activate(
                    id: fire.profileID,
                    durationMinutes: m,
                    confirmedPumpSync: true
                )
                debug(.coreData, "ProfileScheduleFirer: activate outcome = \(outcome)")
                if outcome != .success { continue }
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
                if fire.isOnce {
                    // Once-schedules are not editable; deleting after fire is cleaner than
                    // leaving a disabled row cluttering the list.
                    context.delete(row)
                    debug(.coreData, "ProfileScheduleFirer: deleted one-off \(fire.scheduleID) after fire")
                } else {
                    row.lastFiredAt = fire.occurrence
                    debug(.coreData, "ProfileScheduleFirer: stamped lastFiredAt=\(fire.occurrence) on \(fire.scheduleID)")
                }
                try? context.save()
            }
        }

        // Wake anyone watching the schedule list (Profiles root Upcoming section + Schedules
        // management screen) so deleted / stamped rows disappear immediately instead of lingering
        // until the next manual refresh.
        await MainActor.run {
            Foundation.NotificationCenter.default.post(name: .didUpdateProfileSchedules, object: nil)
        }
    }
}
