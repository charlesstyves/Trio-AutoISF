import AppIntents
import CoreData
import Foundation
import UIKit

/// Start-time mode for a custom Temp Target shortcut.
enum TempTargetStartMode: String, AppEnum {
    case now
    case scheduled

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Start"

    static var caseDisplayRepresentations: [TempTargetStartMode: DisplayRepresentation] = [
        .now: "Now (activate on submit)",
        .scheduled: "Scheduled (pick date & time)"
    ]
}

/// Create and activate a fully custom Temp Target — no preset selection required.
/// Target value is interpreted in the user's configured glucose unit (mg/dL or mmol/L).
///
/// Two start modes:
/// - **Now**: submitting the shortcut activates the Temp Target immediately.
/// - **Scheduled**: pick a date+time within the next 24 h. The TT is stored as
///   scheduled and activated when the time arrives (same flow as the in-app
///   Add TT form).
struct CreateCustomTempTargetIntent: AppIntent {
    static var title: LocalizedStringResource = "Create a Temporary Target"

    static var description = IntentDescription(
        "Create and activate a Temporary Target with name, target value, duration. Activate now on submit, or schedule for a date+time within the next 24 h."
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
        inclusiveRange: (5, 1440),
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "Duration in minutes?"))
    ) var durationMinutes: Int

    @Parameter(
        title: "Start",
        description: "Activate immediately on submit, or schedule for a future time",
        default: .now
    ) var start: TempTargetStartMode

    @Parameter(
        title: "Start time",
        description: "Date & time the Temp Target should begin (within the next 24 hours). Only used when Start is Scheduled.",
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "When should the Temp Target start?"))
    ) var startTime: Date?

    @Parameter(
        title: "Confirm Before applying",
        description: "If toggled, you will need to confirm before applying",
        default: true
    ) var confirmBeforeApplying: Bool

    static var parameterSummary: some ParameterSummary {
        Switch(\CreateCustomTempTargetIntent.$start) {
            Case(.scheduled) {
                Summary("Schedule Temporary Target \(\.$name) at \(\.$startTime)") {
                    \.$start
                    \.$targetValue
                    \.$durationMinutes
                    \.$confirmBeforeApplying
                }
            }
            DefaultCase {
                Summary("Create Temporary Target \(\.$name) now") {
                    \.$start
                    \.$targetValue
                    \.$durationMinutes
                    \.$confirmBeforeApplying
                }
            }
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

        // Resolve start time based on the chosen mode.
        let resolvedStart: Date
        switch start {
        case .now:
            resolvedStart = Date()
        case .scheduled:
            let picked: Date
            if let startTime = startTime {
                picked = startTime
            } else {
                picked = try await $startTime.requestValue(
                    IntentDialog(stringLiteral: String(localized: "When should the Temp Target start?"))
                )
            }
            // Scheduled time must lie within now ... now + 24 h (small grace
            // window for clock skew between Shortcuts execution and this
            // perform() call). Past or beyond-24h times are rejected.
            let now = Date()
            let grace: TimeInterval = 60
            let lowerBound = now.addingTimeInterval(-grace)
            let upperBound = now.addingTimeInterval(24 * 3600)
            guard picked >= lowerBound, picked <= upperBound else {
                return .result(
                    dialog: IntentDialog(
                        stringLiteral: String(
                            localized: "Start time must be within the next 24 hours (now until +24 h)"
                        )
                    )
                )
            }
            resolvedStart = picked
        }

        // Convert from user unit to mg/dL for storage.
        let targetMgdl = request.targetInMgdl(entered: Decimal(targetValue))

        if confirmBeforeApplying {
            let confirmDialog: String
            switch start {
            case .now:
                confirmDialog = String(
                    localized:
                    "Confirm Temp Target '\(trimmedName)': \(formatted(targetValue)) for \(durationMinutes) min, now"
                )
            case .scheduled:
                let prettyStart = DateFormatter.localizedString(from: resolvedStart, dateStyle: .short, timeStyle: .short)
                confirmDialog = String(
                    localized:
                    "Confirm Temp Target '\(trimmedName)': \(formatted(targetValue)) for \(durationMinutes) min starting \(prettyStart)"
                )
            }
            try await requestConfirmation(
                result: .result(dialog: IntentDialog(stringLiteral: confirmDialog))
            )
        }

        let success = await request.createAndEnact(
            name: trimmedName,
            targetMgdl: targetMgdl,
            durationMinutes: Decimal(durationMinutes),
            startTime: resolvedStart
        )

        guard success else {
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(localized: "Temp Target '\(trimmedName)' failed")
                )
            )
        }

        switch start {
        case .now:
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(
                        localized: "Temp Target '\(trimmedName)' applied for \(durationMinutes) min"
                    )
                )
            )
        case .scheduled:
            let prettyStart = DateFormatter.localizedString(from: resolvedStart, dateStyle: .short, timeStyle: .short)
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(
                        localized: "Temp Target '\(trimmedName)' scheduled for \(prettyStart), \(durationMinutes) min"
                    )
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

    // MARK: - Scheduled path (delegated)

    /// Delegates to `ScheduledTempTargetHelper.enact` so the preset-activation
    /// intent and the custom intent share the exact same scheduling backend.
    @MainActor private func storeScheduled(
        name: String,
        targetMgdl: Decimal,
        durationMinutes: Decimal,
        startTime: Date
    ) async -> Bool {
        await ScheduledTempTargetHelper.enact(
            name: name,
            targetMgdl: targetMgdl,
            durationMinutes: durationMinutes,
            halfBasalTarget: settingsManager.preferences.halfBasalExerciseTarget,
            startTime: startTime,
            tempTargetsStorage: tempTargetsStorage,
            viewContext: viewContext
        )
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
        await ScheduledTempTargetHelper.disableAllActiveTempTargets(
            tempTargetsStorage: tempTargetsStorage,
            viewContext: viewContext
        )
    }
}
