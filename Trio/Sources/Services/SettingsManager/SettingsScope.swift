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

    /// `true` when edits are directed at an in-memory profile draft — editors MUST NOT sync to the
    /// pump, upload to Nightscout, or broadcast global observer notifications in this mode.
    var isDraft: Bool { get }
}

/// Scope that reads and writes the live (currently-active) settings via the existing
/// `SettingsManager` (for preferences) and `FileStorage` (for therapy files).
final class LiveScope: SettingsScope {
    private let settingsManager: SettingsManager
    private let storage: FileStorage

    var isDraft: Bool { false }

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

    var isDraft: Bool { true }

    init(
        preferences: Preferences,
        basalProfile: [BasalProfileEntry],
        sensitivities: InsulinSensitivities,
        carbRatios: CarbRatios,
        bgTargets: BGTargets
    ) {
        // Normalize on seed so a draft loaded from a stored profile with an
        // inconsistent combination (e.g. dynISF on + autosens off) is corrected
        // up-front, before any editor view runs. This keeps the activated draft
        // in sync with the rules enforced by DynamicSettings and AutoISFSettings.
        self.preferences = Self.normalize(preferences)
        self.basalProfile = basalProfile
        self.sensitivities = sensitivities
        self.carbRatios = carbRatios
        self.bgTargets = bgTargets
    }

    /// Enforce the cross-feature consistency rules that the live editors apply via `didSet`:
    ///
    /// - dynISF active (`useNewFormula == true`) ⇒ `autoisf = false` and `enableAutosens = true`
    /// - autoISF off (`autoisf == false`) ⇒ `enableAutosens = true`
    ///
    /// dynISF takes precedence over autoISF: they are mutually exclusive in the UI, and
    /// the determine-basal pipeline routes the dynISF ratio through the autosens branch,
    /// so autosens must be enabled for dynISF to take effect.
    static func normalize(_ preferences: Preferences) -> Preferences {
        var prefs = preferences
        if prefs.useNewFormula {
            prefs.autoisf = false
            prefs.enableAutosens = true
        } else if !prefs.autoisf {
            prefs.enableAutosens = true
        }
        return prefs
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
