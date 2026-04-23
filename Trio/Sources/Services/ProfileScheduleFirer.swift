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

    /// Time between sweeps. 15s gives tight reconciliation on foreground after a missed fire
    /// without excess CPU / CoreData pressure while idle.
    private let sweepInterval: TimeInterval = 15

    private var loopTask: Task<Void, Never>?
    private var sweepInFlight = false

    init(resolver: Resolver) {
        self.resolver = resolver
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
        guard !sweepInFlight else { return }
        sweepInFlight = true
        defer { sweepInFlight = false }

        let context = coreDataStack.newTaskContext()
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
