import Foundation
import Observation

extension AdaptProfile {
    /// State for the draft editor hub that is entered after the percentage-adjustment form.
    ///
    /// Holds the working therapy and algorithm values as plain types so the shared components
    /// (`TherapySettingEditorView`, `SettingInputSection`) can bind to them directly, without any
    /// dependency on `SettingsManager`, `FileStorage`, pump, or Nightscout. Constructed from the
    /// list view (which has the resolved services) and disposed when the hub closes.
    @Observable final class DraftEditorStateModel {
        let provider: AdaptProfileProvider
        let insulinConcentration: Decimal
        let units: GlucoseUnits

        /// Name of the profile this draft was seeded from (shown in the hub).
        let sourceProfileName: String
        /// Persisted on the new profile so the list can show "From <source> <percent> %".
        let sourceProfileID: UUID?
        /// When non-nil, the hub operates in "edit" mode: `save()` updates the existing profile
        /// instead of creating a new one.
        let editingProfileID: UUID?

        var isEditing: Bool { editingProfileID != nil }

        var name: String = ""
        var appliedPercent: Decimal = 100

        /// Editable TherapySettingItem lists. BG targets use low == high (single value / slot).
        var basalItems: [TherapySettingItem] = []
        var isfItems: [TherapySettingItem] = []
        var crItems: [TherapySettingItem] = []
        var targetItems: [TherapySettingItem] = []

        /// Snapshots of the source (active) profile BEFORE the % adjustment, used purely for
        /// "changed" indicators in the hub.
        let originalBasalItems: [TherapySettingItem]
        let originalISFItems: [TherapySettingItem]
        let originalCRItems: [TherapySettingItem]
        let originalTargetItems: [TherapySettingItem]
        let originalPreferences: Preferences

        /// Full algorithm preferences snapshot, mutated by SettingInputSection bindings.
        var preferences = Preferences()

        // MARK: - Picker option arrays

        private let settingsProvider = PickerSettingsProvider.shared
        private let timeStride = stride(from: 0.0, to: 1.days.timeInterval, by: 30.minutes.timeInterval).map { $0 }

        var timeValues: [TimeInterval] { timeStride }

        /// Pump-supported rates, concentration-scaled, sorted ascending. Falls back to 0.05 step grid.
        var basalRateValues: [Decimal] {
            let supported = provider.supportedBasalRates ?? Self.fallbackBasalRates(step: 0.05)
            return supported.map { $0 * insulinConcentration }.sorted()
        }

        var isfRateValues: [Decimal] {
            let setting = PickerSetting(value: 100, step: 1, min: 9, max: 540, type: .glucose)
            return settingsProvider.generatePickerValues(from: setting, units: units)
        }

        var crRateValues: [Decimal] {
            let setting = PickerSetting(value: 10, step: 0.1, min: 1, max: 50, type: .gram)
            return settingsProvider.generatePickerValues(from: setting, units: units)
        }

        var targetRateValues: [Decimal] {
            let setting = PickerSetting(value: 110, step: 1, min: 72, max: 180, type: .glucose)
            return settingsProvider.generatePickerValues(from: setting, units: units)
        }

        // MARK: - Init

        init(
            provider: AdaptProfileProvider,
            insulinConcentration: Decimal,
            units: GlucoseUnits,
            sourceProfileName: String,
            sourceProfileID: UUID?,
            from source: NewProfileDraft
        ) {
            self.provider = provider
            self.insulinConcentration = insulinConcentration
            self.units = units
            self.sourceProfileName = sourceProfileName
            self.sourceProfileID = sourceProfileID
            editingProfileID = nil

            name = source.name
            appliedPercent = source.adjustPercent
            preferences = source.preferencesSource
            originalPreferences = source.preferencesSource

            let basalItems = source.finalBasal.map {
                TherapySettingItem(time: TimeInterval($0.minutes * 60), value: $0.rate)
            }
            let isfItems = source.adjustedSensitivities.sensitivities.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.sensitivity)
            }
            let crItems = source.adjustedCarbRatios.schedule.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.ratio)
            }
            let targetItems = source.bgTargets.targets.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.low)
            }
            self.basalItems = basalItems
            self.isfItems = isfItems
            self.crItems = crItems
            self.targetItems = targetItems

            // Originals for "changed" markers — convert from the pre-% adjustment source values.
            originalBasalItems = source.originalBasal.map {
                TherapySettingItem(time: TimeInterval($0.minutes * 60), value: $0.rate)
            }
            originalISFItems = source.originalSensitivities.sensitivities.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.sensitivity)
            }
            originalCRItems = source.originalCarbRatios.schedule.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.ratio)
            }
            originalTargetItems = source.bgTargets.targets.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.low)
            }
        }

        // MARK: - Change detection (for hub "changed" indicators)

        var basalIsChanged: Bool { basalItems != originalBasalItems }
        var isfIsChanged: Bool { isfItems != originalISFItems }
        var crIsChanged: Bool { crItems != originalCRItems }
        var targetsAreChanged: Bool { targetItems != originalTargetItems }
        var preferencesChanged: Bool { preferences != originalPreferences }

        /// True when a single preferences field differs from the source profile's value.
        func isChanged<T: Equatable>(_ keyPath: KeyPath<Preferences, T>) -> Bool {
            preferences[keyPath: keyPath] != originalPreferences[keyPath: keyPath]
        }

        /// Resets a single preferences field back to the source profile's value.
        func resetField<T>(_ keyPath: WritableKeyPath<Preferences, T>) {
            preferences[keyPath: keyPath] = originalPreferences[keyPath: keyPath]
        }

        /// Edit-mode init: seed from an already-persisted profile. `original*` fields capture the
        /// profile's saved state at session open, so blue "changed" markers show only unsaved
        /// edits made during this session.
        init(
            provider: AdaptProfileProvider,
            insulinConcentration: Decimal,
            units: GlucoseUnits,
            editing content: LoadedProfileContent
        ) {
            self.provider = provider
            self.insulinConcentration = insulinConcentration
            self.units = units
            sourceProfileName = content.sourceProfileName ?? ""
            sourceProfileID = content.sourceProfileID
            editingProfileID = content.id

            name = content.name
            appliedPercent = content.appliedPercent
            preferences = content.preferences
            originalPreferences = content.preferences

            let basalItems = content.therapy.basalProfile.map {
                TherapySettingItem(time: TimeInterval($0.minutes * 60), value: $0.rate)
            }
            let isfItems = content.therapy.sensitivities.sensitivities.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.sensitivity)
            }
            let crItems = content.therapy.carbRatios.schedule.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.ratio)
            }
            let targetItems = content.therapy.bgTargets.targets.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.low)
            }
            self.basalItems = basalItems
            self.isfItems = isfItems
            self.crItems = crItems
            self.targetItems = targetItems

            // Baseline = session-open state. Blue marks unsaved edits this session.
            originalBasalItems = basalItems
            originalISFItems = isfItems
            originalCRItems = crItems
            originalTargetItems = targetItems
        }

        // MARK: - Persistence

        func therapyBundle() -> TherapyBundle {
            TherapyBundle(
                basalProfile: basalItems.map(Self.makeBasalEntry),
                sensitivities: InsulinSensitivities(
                    units: .mgdL,
                    userPreferredUnits: .mgdL,
                    sensitivities: isfItems.map(Self.makeISFEntry)
                ),
                carbRatios: CarbRatios(
                    units: .grams,
                    schedule: crItems.map(Self.makeCREntry)
                ),
                bgTargets: BGTargets(
                    units: .mgdL,
                    userPreferredUnits: .mgdL,
                    targets: targetItems.map(Self.makeTargetEntry)
                )
            )
        }

        /// Persist the draft — create a new profile or update the existing one, depending on
        /// `editingProfileID`. Returns `true` on success.
        func save() async -> Bool {
            if let editingID = editingProfileID {
                return await provider.updateProfile(
                    id: editingID,
                    name: name,
                    preferences: preferences,
                    therapy: therapyBundle()
                )
            }
            let id = await provider.saveNewProfile(
                name: name,
                preferences: preferences,
                therapy: therapyBundle(),
                sourceProfileID: sourceProfileID,
                appliedPercent: appliedPercent
            )
            return id != nil
        }

        // MARK: - Helpers

        private static let hhmmss: DateFormatter = {
            let f = DateFormatter()
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "HH:mm:ss"
            return f
        }()

        private static func makeBasalEntry(from item: TherapySettingItem) -> BasalProfileEntry {
            let minutes = Int(item.time / 60)
            return BasalProfileEntry(
                start: hhmmss.string(from: Date(timeIntervalSince1970: item.time)),
                minutes: minutes,
                rate: item.value
            )
        }

        private static func makeISFEntry(from item: TherapySettingItem) -> InsulinSensitivityEntry {
            let minutes = Int(item.time / 60)
            return InsulinSensitivityEntry(
                sensitivity: item.value,
                offset: minutes,
                start: hhmmss.string(from: Date(timeIntervalSince1970: item.time))
            )
        }

        private static func makeCREntry(from item: TherapySettingItem) -> CarbRatioEntry {
            let minutes = Int(item.time / 60)
            return CarbRatioEntry(
                start: hhmmss.string(from: Date(timeIntervalSince1970: item.time)),
                offset: minutes,
                ratio: item.value
            )
        }

        private static func makeTargetEntry(from item: TherapySettingItem) -> BGTargetEntry {
            let minutes = Int(item.time / 60)
            return BGTargetEntry(
                low: item.value,
                high: item.value,
                start: hhmmss.string(from: Date(timeIntervalSince1970: item.time)),
                offset: minutes
            )
        }

        private static func fallbackBasalRates(step: Decimal) -> [Decimal] {
            var out: [Decimal] = []
            var current: Decimal = step
            while current <= 30 {
                out.append(current)
                current += step
            }
            return out
        }
    }
}
