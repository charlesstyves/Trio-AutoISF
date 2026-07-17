import AppIntents
import Foundation

/// Schedule a Temp Target preset to activate at a future date+time within
/// the next 24 hours. Clones the preset's values into a custom-shaped
/// scheduled row (the app has no native scheduling for presets) and
/// detaches a wait+activate task that fires at the chosen time.
struct ScheduleTempPresetIntent: AppIntent {
    static var title: LocalizedStringResource = "Schedule TT Preset"

    static var description = IntentDescription(
        "Schedule a Temporary Target preset for a date+time within the next 24 hours"
    )

    @Parameter(
        title: "Preset",
        description: "the preset to schedule",
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "Which preset to schedule?"))
    ) var preset: TempPreset?

    @Parameter(
        title: "Start time",
        description: "Date & time the preset should activate (within the next 24 hours)",
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "When should the Temp Target start?"))
    ) var startTime: Date?

    @Parameter(
        title: "Confirm Before scheduling",
        description: "If toggled, you will need to confirm before scheduling",
        default: true
    ) var confirmBeforeScheduling: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Schedule \(\.$preset) at \(\.$startTime)") {
            \.$confirmBeforeScheduling
        }
    }

    @MainActor func perform() async throws -> some ProvidesDialog {
        let intentRequest = TempPresetsIntentRequest()

        let presetToSchedule: TempPreset
        if let preset = preset {
            presetToSchedule = preset
        } else {
            presetToSchedule = try await $preset.requestDisambiguation(
                among: intentRequest.fetchAndProcessTempTargets(),
                dialog: "Select Temporary Target"
            )
        }

        let resolvedStart: Date
        if let startTime = startTime {
            resolvedStart = startTime
        } else {
            resolvedStart = try await $startTime.requestValue(
                IntentDialog(stringLiteral: String(localized: "When should the Temp Target start?"))
            )
        }

        // Scheduled time must lie within now ... now + 24 h (small grace window
        // for clock skew between Shortcuts execution and perform()).
        let now = Date()
        let grace: TimeInterval = 60
        let lowerBound = now.addingTimeInterval(-grace)
        let upperBound = now.addingTimeInterval(24 * 3600)
        guard resolvedStart >= lowerBound, resolvedStart <= upperBound else {
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(
                        localized: "Start time must be within the next 24 hours (now until +24 h)"
                    )
                )
            )
        }

        let prettyStart = DateFormatter.localizedString(from: resolvedStart, dateStyle: .short, timeStyle: .short)
        if confirmBeforeScheduling {
            try await requestConfirmation(
                result: .result(
                    dialog: IntentDialog(
                        stringLiteral: String(
                            localized: "Confirm to schedule Temporary Target '\(presetToSchedule.name)' for \(prettyStart)"
                        )
                    )
                )
            )
        }

        if await intentRequest.schedulePresetTempTarget(presetToSchedule, at: resolvedStart) {
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(
                        localized: "Temporary Target '\(presetToSchedule.name)' scheduled for \(prettyStart)"
                    )
                )
            )
        } else {
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(
                        localized: "Failed to schedule Temporary Target '\(presetToSchedule.name)'"
                    )
                )
            )
        }
    }
}
