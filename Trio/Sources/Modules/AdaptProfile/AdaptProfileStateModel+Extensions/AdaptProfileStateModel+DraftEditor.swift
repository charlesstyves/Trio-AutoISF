import Foundation
import Observation

extension AdaptProfile {
    /// State for the draft editor hub that is entered after the percentage-adjustment form.
    ///
    /// Holds the working therapy and algorithm values as plain types so the shared components
    /// (`TherapySettingEditorView`, `SettingInputSection`) can bind to them directly, without any
    /// dependency on `SettingsManager`, `FileStorage`, pump, or Nightscout. Constructed from the
    /// list view (which has the resolved services) and disposed when the hub closes.
    @Observable final class DraftEditorStateModel: Identifiable {
        /// Stable identity for SwiftUI's `.sheet(item:)` presentation — each hub invocation gets
        /// a fresh state model, so a fresh UUID is fine.
        let id = UUID()

        let provider: AdaptProfileProvider
        let insulinConcentration: Decimal
        let units: GlucoseUnits

        /// Name of the profile this draft was seeded from (shown in the hub).
        var sourceProfileName: String
        /// Persisted on the new profile so the list can show "From <source> <percent> %".
        /// Cleared by `makeDefault()` to sever the "derived from" link — the profile then
        /// stops showing the percent/tuned badge the same way the seeded default profile does.
        var sourceProfileID: UUID?
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

        /// Source profile's prefs and BG targets, loaded lazily in edit mode via
        /// `loadSourceForTuning()`. Nil in new-draft mode (where `originalPreferences` already
        /// equals source) and stays nil if the source profile is missing / was deleted.
        var sourcePreferencesForTuning: Preferences?
        var sourceTargetItemsForTuning: [TherapySettingItem]?

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

        // MARK: - dynISF / autoISF cascade caches

        //
        // Enabling autoISF forces `useNewFormula` + `sigmoid` off; enabling dynISF forces
        // `autoisf` off. When the user later reverses the enabling side, we want the cascaded
        // side to come back to whatever it was before — otherwise the hub shows a stale
        // "changed" indicator and the user has to go hunt down the implicit side effect.

        @ObservationIgnored private var cachedDynISFBeforeAutoISFCascade: (useNewFormula: Bool, sigmoid: Bool)?
        @ObservationIgnored private var cachedAutoISFBeforeDynISFCascade: Bool?

        /// Toggle autoISF with cascade-and-restore. `true` caches the current dynISF pair and
        /// flips it off; `false` restores the cache (if any) and re-asserts the autosens invariant.
        func setAutoISF(_ enabled: Bool) {
            // User touched autoISF directly — any stale cache on the dynISF side is moot.
            cachedAutoISFBeforeDynISFCascade = nil
            preferences.autoisf = enabled
            if enabled {
                if cachedDynISFBeforeAutoISFCascade == nil {
                    cachedDynISFBeforeAutoISFCascade = (preferences.useNewFormula, preferences.sigmoid)
                }
                preferences.useNewFormula = false
                preferences.sigmoid = false
            } else {
                if let cache = cachedDynISFBeforeAutoISFCascade {
                    preferences.useNewFormula = cache.useNewFormula
                    preferences.sigmoid = cache.sigmoid
                    cachedDynISFBeforeAutoISFCascade = nil
                }
                // oref needs at least one of autosens / autoISF to scale ISF dynamically.
                preferences.enableAutosens = true
            }
        }

        /// Switch dynISF mode with cascade-and-restore. Non-disabled caches current autoISF and
        /// flips it off; `.disabled` restores the cached autoISF value.
        func setDynISFMode(_ mode: DynamicSettings.DynamicSensitivityType) {
            // User touched the picker directly — any stale cache on the autoISF side is moot.
            cachedDynISFBeforeAutoISFCascade = nil
            switch mode {
            case .logarithmic:
                preferences.useNewFormula = true
                preferences.sigmoid = false
            case .sigmoid:
                preferences.useNewFormula = true
                preferences.sigmoid = true
            case .disabled:
                preferences.useNewFormula = false
                preferences.sigmoid = false
            }
            if mode != .disabled {
                if cachedAutoISFBeforeDynISFCascade == nil {
                    cachedAutoISFBeforeDynISFCascade = preferences.autoisf
                }
                preferences.autoisf = false
                // dynISF substitutes its ratio into autosensData, which DetermineBasal+Helpers
                // only reads when enableAutosens is true. A draft seeded from an autoISF profile
                // with enableAutosens=false would otherwise activate dynISF that silently no-ops.
                preferences.enableAutosens = true
            } else {
                if let cache = cachedAutoISFBeforeDynISFCascade {
                    preferences.autoisf = cache
                    cachedAutoISFBeforeDynISFCascade = nil
                }
            }
        }

        /// Tie-break policy for `enforceAlgorithmMutualExclusion` when both dynISF and autoISF end
        /// up active. Resets restore original field values verbatim; if the user had previously
        /// toggled one and cascaded the other off, an undo on just one field re-enables both —
        /// this tells us which one the user's most recent action meant to keep.
        enum MutexPreference {
            case preferDynISF
            case preferAutoISF
        }

        /// Ensures `useNewFormula` and `autoisf` aren't simultaneously on. Call after any reset
        /// path that can restore one without touching the other.
        func enforceAlgorithmMutualExclusion(prefer: MutexPreference) {
            if preferences.useNewFormula, preferences.autoisf {
                switch prefer {
                case .preferDynISF:
                    preferences.autoisf = false
                case .preferAutoISF:
                    preferences.useNewFormula = false
                    preferences.sigmoid = false
                }
            }
            // sigmoid without useNewFormula is never valid — clean up stray state.
            if preferences.sigmoid, !preferences.useNewFormula {
                preferences.sigmoid = false
            }
        }

        /// Drops the label-bearing metadata: percent → 100, source link cleared. Leaves therapy
        /// and algorithm values untouched so the user's tuned numbers survive — only the "derived
        /// from source" framing goes away. After this, the profile renders like the seeded
        /// default (no percent, no tuned badge).
        func makeDefault() {
            appliedPercent = 100
            sourceProfileID = nil
            sourceProfileName = ""
        }

        var hasLabel: Bool {
            appliedPercent != 100 || sourceProfileID != nil
        }

        /// Tuning flags against the source profile — the same semantics the AdaptProfile list
        /// and History tab use. In new-draft mode falls through to `originalPreferences` (which
        /// IS source). In edit mode relies on the lazy fetch in `loadSourceForTuning()`; if that
        /// hasn't completed or the source is gone, reports `.none` so we don't show a misleading
        /// badge during the brief load.
        var tuningVsSource: ProfileSummaryLabel.Tuning {
            guard sourceProfileID != nil else { return .none }
            let sourcePrefs = sourcePreferencesForTuning ?? (editingProfileID == nil ? originalPreferences : nil)
            let sourceTargets = sourceTargetItemsForTuning ?? (editingProfileID == nil ? originalTargetItems : nil)
            guard let sourcePrefs = sourcePrefs, let sourceTargets = sourceTargets else { return .none }
            return ProfileSummaryLabel.Tuning(
                preferencesTuned: preferences != sourcePrefs,
                targetsTuned: targetItems != sourceTargets
            )
        }

        /// Edit-mode only: pull the source profile's prefs + targets so `tuningVsSource` can
        /// report the accumulated customizations (not just unsaved session edits).
        @MainActor func loadSourceForTuning() async {
            guard editingProfileID != nil,
                  let sourceID = sourceProfileID,
                  let content = await provider.loadProfileContent(id: sourceID)
            else { return }
            sourcePreferencesForTuning = content.preferences
            sourceTargetItemsForTuning = content.therapy.bgTargets.targets.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.low)
            }
        }

        /// Sum over the current draft basal items, matching `[BasalProfileEntry].totalDailyBasal`.
        var draftDailyBasal: Decimal {
            guard !basalItems.isEmpty else { return 0 }
            let sorted = basalItems.sorted { $0.time < $1.time }
            var total: Decimal = 0
            for (i, item) in sorted.enumerated() {
                let nextSeconds = i + 1 < sorted.count ? sorted[i + 1].time : 86400
                let hours = Decimal((nextSeconds - item.time) / 3600)
                total += item.value * hours
            }
            return total
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
                    therapy: therapyBundle(),
                    sourceProfileID: sourceProfileID,
                    appliedPercent: appliedPercent
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
