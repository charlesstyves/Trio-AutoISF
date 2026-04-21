import Combine
import Observation
import SwiftUI

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

        var name: String = ""
        var appliedPercent: Decimal = 100

        /// TherapySettingItem lists for the four schedule-based therapy values. For BG targets we
        /// treat low == high (single value per time slot).
        var basalItems: [TherapySettingItem] = []
        var isfItems: [TherapySettingItem] = []
        var crItems: [TherapySettingItem] = []
        var targetItems: [TherapySettingItem] = []

        /// Full algorithm preferences snapshot, mutated by SettingInputSection bindings later.
        var preferences: Preferences = Preferences()

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
            from source: NewProfileDraft
        ) {
            self.provider = provider
            self.insulinConcentration = insulinConcentration
            self.units = units

            name = source.name
            appliedPercent = source.adjustPercent
            preferences = source.preferencesSource

            basalItems = source.finalBasal.map {
                TherapySettingItem(time: TimeInterval($0.minutes * 60), value: $0.rate)
            }
            isfItems = source.adjustedSensitivities.sensitivities.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.sensitivity)
            }
            crItems = source.adjustedCarbRatios.schedule.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.ratio)
            }
            targetItems = source.bgTargets.targets.map {
                TherapySettingItem(time: TimeInterval($0.offset * 60), value: $0.low)
            }
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

        /// Persist the draft as a new, non-active profile. Returns `true` on success.
        func save() async -> Bool {
            let id = await provider.saveNewProfile(
                name: name,
                preferences: preferences,
                therapy: therapyBundle()
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
