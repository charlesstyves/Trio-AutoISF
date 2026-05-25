import AppIntents
import Foundation

/// Activate a profile immediately for a chosen number of hours.
///
/// Shortcuts intentionally do not expose indefinite activation: only timed
/// (auto-reverting) profile activations are allowed via the Shortcuts surface.
struct ApplyProfileIntent: AppIntent {
    static var title = LocalizedStringResource("Activate Profile")

    static var description = IntentDescription(
        .init("Activate a stored profile now for a chosen duration. Indefinite activation is not available via Shortcuts.")
    )

    @Parameter(
        title: LocalizedStringResource("Profile"),
        description: LocalizedStringResource("Profile to activate"),
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "Which profile do you want to activate?"))
    ) var profile: ProfileEntity?

    @Parameter(
        title: LocalizedStringResource("Hours"),
        description: LocalizedStringResource("Whole hours of activation (0–24)"),
        inclusiveRange: (0, 24),
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "How many whole hours?"))
    ) var hours: Int

    @Parameter(
        title: LocalizedStringResource("Minutes"),
        description: LocalizedStringResource("Additional minutes (0–55)"),
        inclusiveRange: (0, 55),
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "How many additional minutes?"))
    ) var minutes: Int

    @Parameter(
        title: LocalizedStringResource("Confirm Before applying"),
        description: LocalizedStringResource("If toggled, you will need to confirm before applying"),
        default: true
    ) var confirmBeforeApplying: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Activate Profile \(\.$profile)") {
            \.$hours
            \.$minutes
            \.$confirmBeforeApplying
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

        let durationMinutes = max(0, hours) * 60 + max(0, minutes)
        guard durationMinutes > 0 else {
            return .result(
                dialog: IntentDialog(stringLiteral: String(localized: "Duration must be positive"))
            )
        }

        let descriptor = formattedDuration(hours: hours, minutes: minutes)

        if confirmBeforeApplying {
            try await requestConfirmation(
                result: .result(
                    dialog: IntentDialog(
                        stringLiteral: String(localized: "Confirm to activate profile '\(target.name)' for \(descriptor)")
                    )
                )
            )
        }

        if let error = await request.activateProfile(id: target.id, durationMinutes: durationMinutes) {
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String(localized: "Failed to activate profile '\(target.name)': \(error)")
                )
            )
        }

        return .result(
            dialog: IntentDialog(
                stringLiteral: String(localized: "Profile '\(target.name)' activated for \(descriptor)")
            )
        )
    }

    /// "1 h 30 min", "45 min", "2 h" — mirrors the wording used in the in-app duration picker.
    private func formattedDuration(hours: Int, minutes: Int) -> String {
        let h = max(0, hours)
        let m = max(0, minutes)
        if h > 0, m > 0 { return "\(h) h \(m) min" }
        if h > 0 { return "\(h) h" }
        return "\(m) min"
    }
}
