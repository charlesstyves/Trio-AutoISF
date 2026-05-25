import AppIntents
import Foundation

/// Activate a profile immediately, either indefinitely or for a custom number of hours.
struct ApplyProfileIntent: AppIntent {
    static var title = LocalizedStringResource("Activate a profile")

    static var description = IntentDescription(
        .init("Activate a stored profile now — indefinite or for a chosen number of hours")
    )

    @Parameter(
        title: LocalizedStringResource("Profile"),
        description: LocalizedStringResource("Profile to activate"),
        requestValueDialog: IntentDialog(stringLiteral: String(localized: "Which profile do you want to activate?"))
    ) var profile: ProfileEntity?

    @Parameter(
        title: LocalizedStringResource("Duration Mode"),
        description: LocalizedStringResource("Indefinite or custom hours"),
        default: .indefinite
    ) var durationMode: ProfileDurationMode

    @Parameter(
        title: LocalizedStringResource("Duration (hours)"),
        description: LocalizedStringResource("Activation duration in hours (used when Duration Mode is Custom)"),
        default: 1.0,
        inclusiveRange: (0.25, 24.0)
    ) var customDurationHours: Double

    @Parameter(
        title: LocalizedStringResource("Confirm Before applying"),
        description: LocalizedStringResource("If toggled, you will need to confirm before applying"),
        default: true
    ) var confirmBeforeApplying: Bool

    static var parameterSummary: some ParameterSummary {
        Switch(\ApplyProfileIntent.$durationMode) {
            Case(.customHours) {
                Summary("Activate \(\.$profile) for \(\.$customDurationHours) h") {
                    \.$confirmBeforeApplying
                }
            }
            DefaultCase {
                Summary("Activate \(\.$profile) indefinitely") {
                    \.$confirmBeforeApplying
                }
            }
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

        let durationMinutes: Int?
        let descriptor: String
        switch durationMode {
        case .indefinite:
            durationMinutes = nil
            descriptor = String(localized: "indefinitely")
        case .customHours:
            durationMinutes = Int((customDurationHours * 60).rounded())
            descriptor = String(localized: "for \(formattedHours(customDurationHours)) h")
        }

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
