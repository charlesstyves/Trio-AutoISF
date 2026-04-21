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
        set {
            storage.save(newValue, as: OpenAPS.Settings.basalProfile)
            ActiveProfileMirror.shared.updateBasalProfile(newValue)
        }
    }

    var sensitivities: InsulinSensitivities {
        get {
            storage.retrieve(OpenAPS.Settings.insulinSensitivities, as: InsulinSensitivities.self)
                ?? InsulinSensitivities(from: OpenAPS.defaults(for: OpenAPS.Settings.insulinSensitivities))
                ?? InsulinSensitivities(units: .mgdL, userPreferredUnits: .mgdL, sensitivities: [])
        }
        set {
            storage.save(newValue, as: OpenAPS.Settings.insulinSensitivities)
            ActiveProfileMirror.shared.updateSensitivities(newValue)
        }
    }

    var carbRatios: CarbRatios {
        get {
            storage.retrieve(OpenAPS.Settings.carbRatios, as: CarbRatios.self)
                ?? CarbRatios(from: OpenAPS.defaults(for: OpenAPS.Settings.carbRatios))
                ?? CarbRatios(units: .grams, schedule: [])
        }
        set {
            storage.save(newValue, as: OpenAPS.Settings.carbRatios)
            ActiveProfileMirror.shared.updateCarbRatios(newValue)
        }
    }

    var bgTargets: BGTargets {
        get {
            storage.retrieve(OpenAPS.Settings.bgTargets, as: BGTargets.self)
                ?? BGTargets(from: OpenAPS.defaults(for: OpenAPS.Settings.bgTargets))
                ?? BGTargets(units: .mgdL, userPreferredUnits: .mgdL, targets: [])
        }
        set {
            storage.save(newValue, as: OpenAPS.Settings.bgTargets)
            ActiveProfileMirror.shared.updateBGTargets(newValue)
        }
    }
}

/// Scope that keeps edits in memory without touching live settings, Core Data, or the pump.
///
/// Used when editing a profile draft during creation — seed it from a live source or a stored
/// profile, mutate via the same editor views used for live settings, then persist explicitly
/// (e.g. serialize into a new `ProfileStored`). Discarding the draft is just dropping the instance.
final class DraftScope: SettingsScope {
    var preferences: Preferences
    var basalProfile: [BasalProfileEntry]
    var sensitivities: InsulinSensitivities
    var carbRatios: CarbRatios
    var bgTargets: BGTargets

    init(
        preferences: Preferences,
        basalProfile: [BasalProfileEntry],
        sensitivities: InsulinSensitivities,
        carbRatios: CarbRatios,
        bgTargets: BGTargets
    ) {
        self.preferences = preferences
        self.basalProfile = basalProfile
        self.sensitivities = sensitivities
        self.carbRatios = carbRatios
        self.bgTargets = bgTargets
    }

    /// Seed a draft by copying from any live source (typically a `LiveScope`).
    convenience init(copying source: SettingsScope) {
        self.init(
            preferences: source.preferences,
            basalProfile: source.basalProfile,
            sensitivities: source.sensitivities,
            carbRatios: source.carbRatios,
            bgTargets: source.bgTargets
        )
    }

    /// Seed a draft from a stored profile snapshot. Any missing fields fall back to defaults.
    convenience init(from profile: ProfileStored) {
        let therapy = profile.therapy ?? TherapyBundle(
            basalProfile: [],
            sensitivities: InsulinSensitivities(units: .mgdL, userPreferredUnits: .mgdL, sensitivities: []),
            carbRatios: CarbRatios(units: .grams, schedule: []),
            bgTargets: BGTargets(units: .mgdL, userPreferredUnits: .mgdL, targets: [])
        )
        self.init(
            preferences: profile.preferences ?? Preferences(),
            basalProfile: therapy.basalProfile,
            sensitivities: therapy.sensitivities,
            carbRatios: therapy.carbRatios,
            bgTargets: therapy.bgTargets
        )
    }

    /// Serialize the current draft state into a `TherapyBundle` (for saving into a `ProfileStored`).
    var therapyBundle: TherapyBundle {
        TherapyBundle(
            basalProfile: basalProfile,
            sensitivities: sensitivities,
            carbRatios: carbRatios,
            bgTargets: bgTargets
        )
    }
}
