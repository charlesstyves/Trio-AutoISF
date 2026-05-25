import AppIntents
import Foundation

/// Persist a one-off schedule that will activate a profile at the given date/time
/// for a chosen number of hours. The existing background `ProfileScheduleFirer`
/// picks it up at fire time.
///
/// Shortcuts intentionally do not expose indefinite scheduling: only timed
/// (auto-reverting) profile activations are allowed via the Shortcuts surface.
struct ScheduleProfileOnceIntent: AppIntent {
    static var title = LocalizedStringResource("Schedule a profile (once, timed)")

    static var description = IntentDescription(
        .init("Schedule a profile to activate once at a specific date/time for a chosen number of hours. Indefinite scheduling is not available via Shortcuts.")
    )

    @Parameter(
        title: LocalizedStringResource("Profile"),
        description: LocalizedStringResource("Profile to schedule"),
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "Which profile do you want to schedule?"))
    ) var profile: ProfileEntity?

    @Parameter(
        title: LocalizedStringResource("Fire at"),
        description: LocalizedStringResource("Date and time the profile should activate")
    ) var fireAt: Date?

    @Parameter(
        title: LocalizedStringResource("Duration (hours)"),
        description: LocalizedStringResource("How long the profile should stay active before reverting"),
        default: 1.0,
        inclusiveRange: (0.25, 24.0)
    ) var durationHours: Double

    @Parameter(
        title: LocalizedStringResource("Schedule name"),
        description: LocalizedStringResource("Optional name for the schedule entry"),
        default: ""
    ) var scheduleName: String

    @Parameter(
        title: LocalizedStringResource("Confirm Before Scheduling"),
        description: LocalizedStringResource("If toggled, you will need to confirm before the schedule is saved"),
        default: true
    ) var confirmBeforeScheduling: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Schedule \(\.$profile) at \(\.$fireAt) for \(\.$durationHours) h") {
            \.$scheduleName
            \.$confirmBeforeScheduling
        }
    }

    @MainActor func perform() async throws -> some ProvidesDialog {
        let request = ProfileIntentRequest()

        let target: ProfileEntity
        if let profile = profile {
            target = profile
        } else {
            target = try await $profile.requestDisambiguation(
                among: request.fetchAllProfiles(),
                dialog: IntentDialog(stringLiteral: String(localized: "Select profile"))
            )
        }

        let resolvedFireAt: Date
        if let fireAt = fireAt {
            resolvedFireAt = fireAt
        } else {
            resolvedFireAt = try await $fireAt.requestValue(
                IntentDialog(stringLiteral: String(localized: "When should the profile activate?"))
            )
        }

        guard resolvedFireAt > Date() else {
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(localized: "Schedule time must be in the future")
                )
            )
        }

        let durationMinutes = Int((durationHours * 60).rounded())
        guard durationMinutes > 0 else {
            return .result(
                dialog: IntentDialog(stringLiteral: String(localized: "Duration must be positive"))
            )
        }

        let descriptor = String(localized: "for \(formattedHours(durationHours)) h")
        let prettyDate = DateFormatter.localizedString(from: resolvedFireAt, dateStyle: .short, timeStyle: .short)

        if confirmBeforeScheduling {
            try await requestConfirmation(
                result: .result(
                    dialog: IntentDialog(
                        stringLiteral: String(
                            localized: "Confirm to schedule profile '\(target.name)' at \(prettyDate) \(descriptor)"
                        )
                    )
                )
            )
        }

        let trimmedName = scheduleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let success = await request.scheduleOnce(
            profileID: target.id,
            fireAt: resolvedFireAt,
            duration: .minutes(durationMinutes),
            name: trimmedName.isEmpty ? nil : trimmedName
        )

        if success {
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(
                        localized: "Profile '\(target.name)' scheduled for \(prettyDate) \(descriptor)"
                    )
                )
            )
        } else {
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(localized: "Failed to schedule profile '\(target.name)'")
                )
            )
        }
    }

    private func formattedHours(_ hours: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: hours)) ?? "\(hours)"
    }
}
