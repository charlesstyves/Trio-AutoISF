import Foundation

/// Abstraction over "where does a settings editor read from and write to".
///
/// - `LiveScope` — the default; reads/writes go to `SettingsManager` and the live therapy JSON files.
/// - `DraftScope` — used when editing a profile draft that is not yet persisted or activated (added later).
///
/// Editor StateModels hold a `SettingsScope` instead of reaching into `settingsManager` / `FileStorage`
/// directly, so the same views can back either a live edit session or a draft profile edit session.
protocol SettingsScope: AnyObject {
    var preferences: Preferences { get set }
    var basalProfile: [BasalProfileEntry] { get set }
    var sensitivities: InsulinSensitivities { get set }
    var carbRatios: CarbRatios { get set }
    var bgTargets: BGTargets { get set }
}

/// Scope that reads and writes the live (currently-active) settings via the existing
/// `SettingsManager` (for preferences) and `FileStorage` (for therapy files).
final class LiveScope: SettingsScope {
    private let settingsManager: SettingsManager
    private let storage: FileStorage

    init(settingsManager: SettingsManager, storage: FileStorage) {
        self.settingsManager = settingsManager
        self.storage = storage
    }

    var preferences: Preferences {
        get { settingsManager.preferences }
        set { settingsManager.preferences = newValue }
    }

    var basalProfile: [BasalProfileEntry] {
        get {
            storage.retrieve(OpenAPS.Settings.basalProfile, as: [BasalProfileEntry].self)
                ?? [BasalProfileEntry](from: OpenAPS.defaults(for: OpenAPS.Settings.basalProfile))
                ?? []
        }
        set { storage.save(newValue, as: OpenAPS.Settings.basalProfile) }
    }

    var sensitivities: InsulinSensitivities {
        get {
            storage.retrieve(OpenAPS.Settings.insulinSensitivities, as: InsulinSensitivities.self)
                ?? InsulinSensitivities(from: OpenAPS.defaults(for: OpenAPS.Settings.insulinSensitivities))
                ?? InsulinSensitivities(units: .mgdL, userPreferredUnits: .mgdL, sensitivities: [])
        }
        set { storage.save(newValue, as: OpenAPS.Settings.insulinSensitivities) }
    }

    var carbRatios: CarbRatios {
        get {
            storage.retrieve(OpenAPS.Settings.carbRatios, as: CarbRatios.self)
                ?? CarbRatios(from: OpenAPS.defaults(for: OpenAPS.Settings.carbRatios))
                ?? CarbRatios(units: .grams, schedule: [])
        }
        set { storage.save(newValue, as: OpenAPS.Settings.carbRatios) }
    }

    var bgTargets: BGTargets {
        get {
            storage.retrieve(OpenAPS.Settings.bgTargets, as: BGTargets.self)
                ?? BGTargets(from: OpenAPS.defaults(for: OpenAPS.Settings.bgTargets))
                ?? BGTargets(units: .mgdL, userPreferredUnits: .mgdL, targets: [])
        }
        set { storage.save(newValue, as: OpenAPS.Settings.bgTargets) }
    }
}
