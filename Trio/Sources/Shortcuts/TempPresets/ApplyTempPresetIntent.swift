import AppIntents
import Foundation

/// An App Intent that allows users to apply a temporary target preset through the Shortcuts app.
///
/// Two start modes (shares the `TempTargetStartMode` enum with `CreateCustomTempTargetIntent`):
/// - **Now**: submitting the shortcut enables the preset immediately.
/// - **Scheduled**: pick a date+time within the next 24 h. A new (non-preset)
///   row is stored with the preset's values, then a detached task waits until
///   the time arrives and activates it — the preset row itself is untouched.
struct ApplyTempPresetIntent: AppIntent {
    /// The title displayed for this action in the Shortcuts app.
    static var title: LocalizedStringResource = "Apply a Temporary Target"

    /// The description displayed for this action in the Shortcuts app.
    static var description = IntentDescription(
        "Enable a Temporary Target preset now or schedule it for a date+time within the next 24 h"
    )

    /// The temporary target preset to be applied.
    @Parameter(
        title: "Preset",
        description: "the preset to apply",
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "Which preset to apply?"))
    ) var preset: TempPreset?

    @Parameter(
        title: "Start",
        description: "Activate immediately on submit, or schedule for a future time",
        default: .now
    ) var start: TempTargetStartMode

    @Parameter(
        title: "Start time",
        description: "Date & time the preset should activate (within the next 24 hours). Only used when Start is Scheduled.",
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "When should the Temp Target start?"))
    ) var startTime: Date?

    /// A boolean parameter that determines whether confirmation is required before applying the temporary target.
    @Parameter(
        title: "Confirm Before applying",
        description: "If toggled, you will need to confirm before applying",
        default: true
    ) var confirmBeforeApplying: Bool

    /// Defines the summary format shown in the Shortcuts app when configuring this intent.
    static var parameterSummary: some ParameterSummary {
        Switch(\ApplyTempPresetIntent.$start) {
            Case(.scheduled) {
                Summary("Schedule \(\.$preset) at \(\.$startTime)") {
                    \.$start
                    \.$confirmBeforeApplying
                }
            }
            DefaultCase {
                Summary("Apply \(\.$preset) now") {
                    \.$start
                    \.$confirmBeforeApplying
                }
            }
        }
    }

    /// Executes the intent to apply the selected temporary target preset.
    @MainActor func perform() async throws -> some ProvidesDialog {
        let intentRequest = TempPresetsIntentRequest()
        let presetToApply: TempPreset

        if let preset = preset {
            presetToApply = preset
        } else {
            presetToApply = try await $preset.requestDisambiguation(
                among: intentRequest.fetchAndProcessTempTargets(),
                dialog: "Select Temporary Target"
            )
        }

        let displayName: String = presetToApply.name

        // Resolve start time based on the chosen mode.
        let resolvedStart: Date?
        switch start {
        case .now:
            resolvedStart = nil
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
            // window for clock skew between Shortcuts execution and perform()).
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

        if confirmBeforeApplying {
            let dialog: String
            switch start {
            case .now:
                dialog = String(localized: "Confirm to apply Temporary Target '\(displayName)' now")
            case .scheduled:
                let prettyStart = resolvedStart.map {
                    DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short)
                } ?? ""
                dialog = String(localized: "Confirm to schedule Temporary Target '\(displayName)' for \(prettyStart)")
            }
            try await requestConfirmation(
                result: .result(dialog: IntentDialog(stringLiteral: dialog))
            )
        }

        switch start {
        case .now:
            if await intentRequest.enactTempTarget(presetToApply) {
                return .result(
                    dialog: IntentDialog(
                        stringLiteral: String(
                            localized: "Temporary Target '\(displayName)' applied"
                        )
                    )
                )
            } else {
                return .result(
                    dialog: IntentDialog(
                        stringLiteral: String(
                            localized: "Temporary Target '\(displayName)' failed"
                        )
                    )
                )
            }
        case .scheduled:
            guard let resolvedStart = resolvedStart else {
                return .result(
                    dialog: IntentDialog(stringLiteral: String(localized: "Start time missing"))
                )
            }
            if await intentRequest.schedulePresetTempTarget(presetToApply, at: resolvedStart) {
                let prettyStart = DateFormatter.localizedString(from: resolvedStart, dateStyle: .short, timeStyle: .short)
                return .result(
                    dialog: IntentDialog(
                        stringLiteral: String(
                            localized: "Temporary Target '\(displayName)' scheduled for \(prettyStart)"
                        )
                    )
                )
            } else {
                return .result(
                    dialog: IntentDialog(
                        stringLiteral: String(
                            localized: "Failed to schedule Temporary Target '\(displayName)'"
                        )
                    )
                )
            }
        }
    }
}
