import AppIntents
import Foundation

/// Schedule a custom Temp Target for a future date+time within the next 24
/// hours. Persists a non-preset row with `enabled = false` and detaches a
/// wait+activate task — same backend as scheduled-preset path.
struct ScheduleCustomTempTargetIntent: AppIntent {
    static var title: LocalizedStringResource = "Schedule a Temporary Target (custom)"

    static var description = IntentDescription(
        "Schedule a custom Temporary Target for a date+time within the next 24 hours"
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
        title: "Start time",
        description: "Date & time the Temp Target should begin (within the next 24 hours)",
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "When should the Temp Target start?"))
    ) var startTime: Date?

    @Parameter(
        title: "Confirm Before scheduling",
        description: "If toggled, you will need to confirm before scheduling",
        default: true
    ) var confirmBeforeScheduling: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Schedule Temporary Target \(\.$name) at \(\.$startTime)") {
            \.$targetValue
            \.$durationMinutes
            \.$confirmBeforeScheduling
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

        let targetMgdl = request.targetInMgdl(entered: Decimal(targetValue))
        let prettyStart = DateFormatter.localizedString(from: resolvedStart, dateStyle: .short, timeStyle: .short)

        if confirmBeforeScheduling {
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

        let success = await request.scheduleCustom(
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

        return .result(
            dialog: IntentDialog(
                stringLiteral: String(
                    localized: "Temp Target '\(trimmedName)' scheduled for \(prettyStart), \(durationMinutes) min"
                )
            )
        )
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
