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

    @MainActor func createAndEnact(
        name: String?,
        targetMgdl: Decimal,
        durationMinutes: Decimal,
        startTime: Date
    ) async -> Bool {
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = startBackgroundTask(withName: "TempTarget Custom Enact")

        // Disable any currently active TT first (matches preset-activation flow).
        await disableAllActiveTempTargets()

        let halfBasal = settingsManager.preferences.halfBasalExerciseTarget
        let tempTarget = TempTarget(
            name: name ?? TempTarget.custom,
            createdAt: startTime,
            targetTop: targetMgdl,
            targetBottom: targetMgdl,
            duration: durationMinutes,
            enteredBy: TempTarget.local,
            reason: TempTarget.custom,
            isPreset: false,
            enabled: true,
            halfBasalTarget: halfBasal
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
