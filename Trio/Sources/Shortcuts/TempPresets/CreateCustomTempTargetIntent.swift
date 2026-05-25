import AppIntents
import CoreData
import Foundation
import UIKit

/// Create and activate a fully custom Temp Target — no preset selection required.
/// Target value is interpreted in the user's configured glucose unit (mg/dL or mmol/L).
///
/// `name` and `startTime` are mandatory. The start time must be a date+time within
/// the next 24 hours (now ... now + 24 h).
struct CreateCustomTempTargetIntent: AppIntent {
    static var title: LocalizedStringResource = "Create a Temporary Target"

    static var description = IntentDescription(
        "Create and activate a Temporary Target with name, target value, duration and start time (start within the next 24 h)"
    )

    @Parameter(
        title: "Name",
        description: "Name shown in history",
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "Name for this Temp Target?"))
    ) var name: String

    @Parameter(
        title: "Target value",
        description: "Target glucose value in the unit configured in Trio (mg/dL or mmol/L)",
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "Target value?"))
    ) var targetValue: Double

    @Parameter(
        title: "Duration (minutes)",
        description: "How long the Temp Target should run (5–1440 min)",
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "Duration in minutes?")),
        inclusiveRange: (5, 1440)
    ) var durationMinutes: Int

    @Parameter(
        title: "Start time",
        description: "When the Temp Target begins. Must be within the next 24 hours.",
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "When should the Temp Target start?"))
    ) var startTime: Date

    @Parameter(
        title: "Confirm Before applying",
        description: "If toggled, you will need to confirm before applying",
        default: true
    ) var confirmBeforeApplying: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Create Temporary Target \(\.$name)") {
            \.$targetValue
            \.$durationMinutes
            \.$startTime
            \.$confirmBeforeApplying
        }
    }

    @MainActor func perform() async throws -> some ProvidesDialog {
        let request = CustomTempTargetIntentRequest()

        guard targetValue > 0 else {
            return .result(
                dialog: IntentDialog(stringLiteral: String(localized: "Target value must be positive"))
            )
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return .result(
                dialog: IntentDialog(stringLiteral: String(localized: "Name is required"))
            )
        }

        // Start time must lie within now ... now + 24 h (small grace window for
        // clock skew between Shortcuts execution and this perform() call).
        let now = Date()
        let grace: TimeInterval = 60
        let lowerBound = now.addingTimeInterval(-grace)
        let upperBound = now.addingTimeInterval(24 * 3600)
        guard startTime >= lowerBound, startTime <= upperBound else {
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(
                        localized: "Start time must be within the next 24 hours (now until +24 h)"
                    )
                )
            )
        }

        // Convert from user unit to mg/dL for storage.
        let targetMgdl = request.targetInMgdl(entered: Decimal(targetValue))

        if confirmBeforeApplying {
            let prettyStart = DateFormatter.localizedString(from: startTime, dateStyle: .short, timeStyle: .short)
            try await requestConfirmation(
                result: .result(
                    dialog: IntentDialog(
                        stringLiteral: String(
                            localized:
                            "Confirm Temp Target '\(trimmedName)': \(formatted(targetValue)) for \(durationMinutes) min starting \(prettyStart)"
                        )
                    )
                )
            )
        }

        let success = await request.createAndEnact(
            name: trimmedName,
            targetMgdl: targetMgdl,
            durationMinutes: Decimal(durationMinutes),
            startTime: startTime
        )

        if success {
            let now = Date()
            let wasScheduled = startTime > now.addingTimeInterval(2)
            if wasScheduled {
                let prettyStart = DateFormatter.localizedString(from: startTime, dateStyle: .short, timeStyle: .short)
                return .result(
                    dialog: IntentDialog(
                        stringLiteral: String(
                            localized: "Temp Target '\(trimmedName)' scheduled for \(prettyStart), \(durationMinutes) min"
                        )
                    )
                )
            }
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(
                        localized: "Temp Target '\(trimmedName)' applied for \(durationMinutes) min"
                    )
                )
            )
        } else {
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(localized: "Temp Target '\(trimmedName)' failed")
                )
            )
        }
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

/// Backend for `CreateCustomTempTargetIntent`. Mirrors the path used by
/// `TrioRemoteControl.handleTempTargetCommand` and `Adjustments.StateModel.saveCustomTempTarget`.
final class CustomTempTargetIntentRequest: BaseIntentsRequest {
    /// Convert a user-entered target into mg/dL for storage.
    func targetInMgdl(entered: Decimal) -> Decimal {
        switch settingsManager.settings.units {
        case .mgdL: return entered
        case .mmolL: return entered.asMgdL
        }
    }

    /// Persist the Temp Target and exit. Two paths:
    ///
    /// - **Immediate** (`startTime` is essentially now): store with
    ///   `createdAt = now` and `enabled = true`, push JSON to oref so the
    ///   algorithm picks it up on the next tick.
    /// - **Scheduled** (`startTime` is in the future): store with
    ///   `createdAt = startTime` and `enabled = false`. The shortcut does
    ///   **not** wait — the row appears in the app's scheduled-TT list and
    ///   the in-app scheduling logic activates it when the time comes.
    ///   Duration runs from `startTime` for `durationMinutes` (no wait
    ///   added to the run-time).
    @MainActor func createAndEnact(
        name: String,
        targetMgdl: Decimal,
        durationMinutes: Decimal,
        startTime: Date
    ) async -> Bool {
        let now = Date()
        let isScheduled = startTime > now.addingTimeInterval(2)
        return isScheduled
            ? await storeScheduled(
                name: name,
                targetMgdl: targetMgdl,
                durationMinutes: durationMinutes,
                startTime: startTime
            )
            : await enactImmediate(
                name: name,
                targetMgdl: targetMgdl,
                durationMinutes: durationMinutes
            )
    }

    // MARK: - Immediate path

    @MainActor private func enactImmediate(
        name: String,
        targetMgdl: Decimal,
        durationMinutes: Decimal
    ) async -> Bool {
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = startBackgroundTask(withName: "TempTarget Custom Enact")

        // Disable any currently active TT first (matches preset-activation flow).
        await disableAllActiveTempTargets()

        let tempTarget = makeTempTarget(
            name: name,
            createdAt: Date(),
            targetMgdl: targetMgdl,
            durationMinutes: durationMinutes,
            enabled: true
        )

        do {
            try await tempTargetsStorage.storeTempTarget(tempTarget: tempTarget)
            tempTargetsStorage.saveTempTargetsToStorage([tempTarget])
            Foundation.NotificationCenter.default.post(name: .willUpdateTempTargetConfiguration, object: nil)
            await awaitNotification(.didUpdateTempTargetConfiguration)
            endBackgroundTaskSafely(&backgroundTaskID, taskName: "TempTarget Custom Enact")
            return true
        } catch {
            debug(
                .default,
                "\(DebuggingIdentifiers.failed) Failed to enact custom TempTarget: \(error)"
            )
            endBackgroundTaskSafely(&backgroundTaskID, taskName: "TempTarget Custom Enact")
            return false
        }
    }

    // MARK: - Scheduled path (store + detached wait-and-activate)

    /// Persist the scheduled row and detach the wait+activate task, then
    /// return immediately. The detached task mirrors the post-persist half of
    /// `Adjustments.StateModel.saveScheduledTempTarget`: sleep until startTime,
    /// disable any actives, flip enabled = true, push JSON to oref.
    ///
    /// The detached task lives in the Trio app process for the same duration
    /// the in-app Add-TT submission would (i.e. as long as iOS keeps the
    /// process resident). No new lifecycle behaviour vs. the in-app form.
    @MainActor private func storeScheduled(
        name: String,
        targetMgdl: Decimal,
        durationMinutes: Decimal,
        startTime: Date
    ) async -> Bool {
        let scheduledTT = makeTempTarget(
            name: name,
            createdAt: startTime,
            targetMgdl: targetMgdl,
            durationMinutes: durationMinutes,
            enabled: false
        )
        do {
            try await tempTargetsStorage.storeTempTarget(tempTarget: scheduledTT)
        } catch {
            debug(
                .default,
                "\(DebuggingIdentifiers.failed) Failed to store scheduled TempTarget: \(error)"
            )
            return false
        }

        // Detached task — survives perform() returning. Same shape as the
        // tail of saveScheduledTempTarget() in AdjustmentsStateModel. We
        // capture self strongly: there's no retain cycle (the intent
        // request is throw-away) and we need self for the storage,
        // settingsManager, and viewContext references.
        Task.detached {
            await Self.waitUntilDate(startTime)
            await self.activateScheduled(
                name: name,
                targetMgdl: targetMgdl,
                durationMinutes: durationMinutes,
                startTime: startTime
            )
        }
        return true
    }

    @MainActor private func activateScheduled(
        name: String,
        targetMgdl: Decimal,
        durationMinutes: Decimal,
        startTime: Date
    ) async {
        await disableAllActiveTempTargets()
        do {
            let ids = try await tempTargetsStorage.fetchScheduledTempTarget(for: startTime)
            guard let firstID = ids.first,
                  let row = try viewContext.existingObject(with: firstID) as? TempTargetStored
            else {
                debug(
                    .default,
                    "\(DebuggingIdentifiers.failed) Scheduled TempTarget not found for \(startTime)"
                )
                return
            }
            row.enabled = true
            row.isUploadedToNS = false
            if viewContext.hasChanges {
                try viewContext.save()
            }
            let liveTT = makeTempTarget(
                name: name,
                createdAt: startTime,
                targetMgdl: targetMgdl,
                durationMinutes: durationMinutes,
                enabled: true
            )
            tempTargetsStorage.saveTempTargetsToStorage([liveTT])
            Foundation.NotificationCenter.default.post(
                name: .willUpdateTempTargetConfiguration,
                object: nil
            )
        } catch {
            debug(
                .default,
                "\(DebuggingIdentifiers.failed) Failed to activate scheduled TempTarget: \(error)"
            )
        }
    }

    /// Sleep until `targetDate`. Mirrors `Adjustments.StateModel.waitUntilDate`.
    private static func waitUntilDate(_ targetDate: Date) async {
        while Date() < targetDate {
            let delta = targetDate.timeIntervalSince(Date())
            let sleepSeconds = min(delta, 60.0)
            try? await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
        }
    }

    // MARK: - Helpers

    private func makeTempTarget(
        name: String,
        createdAt: Date,
        targetMgdl: Decimal,
        durationMinutes: Decimal,
        enabled: Bool
    ) -> TempTarget {
        TempTarget(
            name: name,
            createdAt: createdAt,
            targetTop: targetMgdl,
            targetBottom: targetMgdl,
            duration: durationMinutes,
            enteredBy: TempTarget.local,
            reason: TempTarget.custom,
            isPreset: false,
            enabled: enabled,
            halfBasalTarget: settingsManager.preferences.halfBasalExerciseTarget
        )
    }

    @MainActor private func disableAllActiveTempTargets() async {
        do {
            let ids = try await tempTargetsStorage.loadLatestTempTargetConfigurations(fetchLimit: 0)
            let results = try ids.compactMap {
                try self.viewContext.existingObject(with: $0) as? TempTargetStored
            }
            guard !results.isEmpty else { return }

            if let canceledTempTarget = results.first {
                let run = TempTargetRunStored(context: viewContext)
                run.id = UUID()
                run.name = canceledTempTarget.name
                run.startDate = canceledTempTarget.date ?? .distantPast
                run.endDate = Date()
                run.target = canceledTempTarget.target ?? 0
                run.tempTarget = canceledTempTarget
                run.isUploadedToNS = false
            }
            for tt in results {
                tt.enabled = false
                tt.isUploadedToNS = false
            }

            if viewContext.hasChanges {
                try viewContext.save()
                Foundation.NotificationCenter.default.post(name: .willUpdateTempTargetConfiguration, object: nil)
                tempTargetsStorage.saveTempTargetsToStorage([TempTarget.cancel(at: Date().addingTimeInterval(-1))])
                await awaitNotification(.didUpdateTempTargetConfiguration)
            }
        } catch {
            debug(
                .default,
                "\(DebuggingIdentifiers.failed) Failed to disable active temp targets before custom enact: \(error)"
            )
        }
    }
}
