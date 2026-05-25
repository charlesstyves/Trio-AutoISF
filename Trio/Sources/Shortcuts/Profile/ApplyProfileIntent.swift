import AppIntents
import Foundation

/// Activate a profile immediately for a chosen number of hours.
///
/// Shortcuts intentionally do not expose indefinite activation: only timed
/// (auto-reverting) profile activations are allowed via the Shortcuts surface.
struct ApplyProfileIntent: AppIntent {
    static var title = LocalizedStringResource("Activate a profile (timed)")

    static var description = IntentDescription(
        .init("Activate a stored profile now for a chosen number of hours. Indefinite activation is not available via Shortcuts.")
    )

    @Parameter(
        title: LocalizedStringResource("Profile"),
        description: LocalizedStringResource("Profile to activate"),
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "Which profile do you want to activate?"))
    ) var profile: ProfileEntity?

    @Parameter(
        title: LocalizedStringResource("Duration (hours)"),
        description: LocalizedStringResource("How long the profile should stay active before reverting"),
        default: 1.0,
        inclusiveRange: (0.25, 24.0)
    ) var durationHours: Double

    @Parameter(
        title: LocalizedStringResource("Confirm Before applying"),
        description: LocalizedStringResource("If toggled, you will need to confirm before applying"),
        default: true
    ) var confirmBeforeApplying: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Activate \(\.$profile) for \(\.$durationHours) h") {
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

        let durationMinutes = Int((durationHours * 60).rounded())
        guard durationMinutes > 0 else {
            return .result(
                dialog: IntentDialog(stringLiteral: String(localized: "Duration must be positive"))
            )
        }

        let descriptor = String(localized: "for \(formattedHours(durationHours)) h")

        if confirmBeforeApplying {
            try await requestConfirmation(
                result: .result(
                    dialog: IntentDialog(
                        stringLiteral: String(localized: "Confirm to activate profile '\(target.name)' \(descriptor)")
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
                stringLiteral: String(localized: "Profile '\(target.name)' activated \(descriptor)")
            )
        )
    }

    private func formattedHours(_ hours: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: hours)) ?? "\(hours)"
    }
}
