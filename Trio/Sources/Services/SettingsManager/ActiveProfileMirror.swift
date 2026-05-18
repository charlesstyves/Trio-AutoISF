import CoreData
import Foundation

/// Mirrors live settings writes into the currently-active `ProfileStored` snapshot, so that
/// editing "live" is the same as editing the active profile.
///
/// Updates are fire-and-forget on a background Core Data context. Failures are logged but never
/// block the live settings write. Calls no-op when no active profile exists (e.g. during
/// onboarding, before the initial Default profile is seeded).
final class ActiveProfileMirror {
    static let shared = ActiveProfileMirror()

    private let context: NSManagedObjectContext

    private init() {
        context = CoreDataStack.shared.newTaskContext()
        context.name = "ActiveProfileMirrorContext"
        context.transactionAuthor = "ActiveProfileMirror"
    }

    func updatePreferences(_ preferences: Preferences) {
        update { $0.preferences = preferences }
    }

    func updateBasalProfile(_ basalProfile: [BasalProfileEntry]) {
        updateTherapy { $0.basalProfile = basalProfile }
    }

    func updateSensitivities(_ sensitivities: InsulinSensitivities) {
        updateTherapy { $0.sensitivities = sensitivities }
    }

    func updateCarbRatios(_ carbRatios: CarbRatios) {
        updateTherapy { $0.carbRatios = carbRatios }
    }

    func updateBGTargets(_ bgTargets: BGTargets) {
        updateTherapy { $0.bgTargets = bgTargets }
    }

    private func updateTherapy(_ mutate: @escaping (inout TherapyBundle) -> Void) {
        update { profile in
            var bundle = profile.therapy ?? TherapyBundle(
                basalProfile: [],
                sensitivities: InsulinSensitivities(units: .mgdL, userPreferredUnits: .mgdL, sensitivities: []),
                carbRatios: CarbRatios(units: .grams, schedule: []),
                bgTargets: BGTargets(units: .mgdL, userPreferredUnits: .mgdL, targets: [])
            )
            mutate(&bundle)
            profile.therapy = bundle
        }
    }

    private func update(_ mutate: @escaping (ProfileStored) -> Void) {
        context.perform {
            do {
                let request = ProfileStored.fetch(.activeProfile, fetchLimit: 1)
                guard let profile = try self.context.fetch(request).first else { return }
                mutate(profile)
                if self.context.hasChanges {
                    try self.context.save()
                }
            } catch {
                debug(.coreData, "ActiveProfileMirror update failed: \(error)")
            }
        }
    }
}
