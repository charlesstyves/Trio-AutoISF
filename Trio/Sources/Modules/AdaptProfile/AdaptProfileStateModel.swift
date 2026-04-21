import Combine
import CoreData
import Observation
import SwiftUI

extension AdaptProfile {
    /// One entry in the basal review: original live rate, percentage-adjusted raw target, and the
    /// pump-rounded rate the user can still tweak.
    struct BasalReviewItem: Identifiable, Hashable {
        let id: Int // minutes since midnight
        let timeLabel: String
        let minutes: Int
        let originalRate: Decimal
        let adjustedRate: Decimal
        var selectedRate: Decimal
        var wasRounded: Bool
    }

    /// In-memory draft for a new profile being created. Populated by `buildDraft` and mutated by
    /// the review UI before being saved.
    struct NewProfileDraft {
        var name: String = ""
        /// Single therapy percentage. Higher = more aggressive (more insulin): basal scales up,
        /// ISF and CR scale down proportionally.
        var adjustPercent: Decimal = 100

        var preferencesSource = Preferences()

        var originalBasal: [BasalProfileEntry] = []
        var basalItems: [BasalReviewItem] = []
        var supportedRates: [Decimal] = []

        var originalSensitivities: InsulinSensitivities = .init(
            units: .mgdL, userPreferredUnits: .mgdL, sensitivities: []
        )
        var adjustedSensitivities: InsulinSensitivities = .init(
            units: .mgdL, userPreferredUnits: .mgdL, sensitivities: []
        )

        var originalCarbRatios: CarbRatios = .init(units: .grams, schedule: [])
        var adjustedCarbRatios: CarbRatios = .init(units: .grams, schedule: [])

        var bgTargets: BGTargets = .init(units: .mgdL, userPreferredUnits: .mgdL, targets: [])

        var hasRoundingAdjustments: Bool {
            basalItems.contains { $0.wasRounded }
        }

        var finalBasal: [BasalProfileEntry] {
            basalItems.map {
                let formatter = DateFormatter()
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "HH:mm:ss"
                let date = Date(timeIntervalSince1970: TimeInterval($0.minutes * 60))
                return BasalProfileEntry(start: formatter.string(from: date), minutes: $0.minutes, rate: $0.selectedRate)
            }
        }

        var therapyBundle: TherapyBundle {
            TherapyBundle(
                basalProfile: finalBasal,
                sensitivities: adjustedSensitivities,
                carbRatios: adjustedCarbRatios,
                bgTargets: bgTargets
            )
        }
    }

    @Observable final class StateModel: BaseStateModel<Provider> {
        var items: [AdaptProfileListItem] = []
        var isLoading: Bool = false

        var draft = NewProfileDraft()

        override func subscribe() {
            Task { await refresh() }
        }

        @MainActor func refresh() async {
            isLoading = true
            items = await provider.fetchAll()
            isLoading = false
        }

        func rename(_ item: AdaptProfileListItem, to newName: String) {
            Task {
                await provider.rename(id: item.id, to: newName)
                await refresh()
            }
        }

        func delete(_ item: AdaptProfileListItem) {
            Task {
                await provider.delete(id: item.id)
                await refresh()
            }
        }

        @MainActor func reorder(from source: IndexSet, to destination: Int) {
            items.move(fromOffsets: source, toOffset: destination)
            let ids = items.map(\.id)
            Task {
                await provider.applyOrdering(ids)
                await refresh()
            }
        }

        /// Reorder the inactive subset of `items` while keeping the active profile pinned at the
        /// top. The active profile is rendered in its own section so it shouldn't participate in
        /// the draggable list.
        @MainActor func reorderInactive(from source: IndexSet, to destination: Int) {
            let active = items.filter(\.isActive)
            var inactive = items.filter { !$0.isActive }
            inactive.move(fromOffsets: source, toOffset: destination)
            items = active + inactive
            let ids = items.map(\.id)
            Task {
                await provider.applyOrdering(ids)
                await refresh()
            }
        }

        /// Resets the draft to reflect current live settings with neutral (100%) percentages.
        func startNewDraft() {
            var d = NewProfileDraft()
            d.preferencesSource = scope.preferences
            d.originalBasal = scope.basalProfile
            d.originalSensitivities = scope.sensitivities
            d.adjustedSensitivities = scope.sensitivities
            d.originalCarbRatios = scope.carbRatios
            d.adjustedCarbRatios = scope.carbRatios
            d.bgTargets = scope.bgTargets
            draft = d
        }

        /// Applies the draft's current percentages to the source data and recomputes basal review
        /// entries (with pump-supported rounding).
        func applyPercentagesToDraft() {
            let concentration = settingsManager.settings.insulinConcentration
            let supportedRaw = provider.supportedBasalRates ?? Self.fallbackBasalRates(pumpIncrement: 0.05)
            let supported = supportedRaw.map { $0 * concentration }.sorted()
            draft.supportedRates = supported

            let basalFactor = draft.adjustPercent / 100
            let isfFactor = 100 / draft.adjustPercent
            let crFactor = 100 / draft.adjustPercent

            // Basal — apply percentage, then round down to nearest supported rate
            draft.basalItems = draft.originalBasal.map { entry in
                let adjusted = entry.rate * basalFactor
                let rounded = supported.last(where: { $0 <= adjusted }) ?? (supported.first ?? adjusted)
                let relativeDiff = abs(adjusted - rounded) / max(abs(adjusted), 0.001)
                return BasalReviewItem(
                    id: entry.minutes,
                    timeLabel: String(entry.start.prefix(5)),
                    minutes: entry.minutes,
                    originalRate: entry.rate,
                    adjustedRate: adjusted,
                    selectedRate: rounded,
                    wasRounded: relativeDiff > 0.001
                )
            }

            // ISF — scale each sensitivity, then quantize to the ISF picker step (1 mg/dL)
            let scaledSensitivities = draft.originalSensitivities.sensitivities.map { entry in
                InsulinSensitivityEntry(
                    sensitivity: Self.roundToStep(entry.sensitivity * isfFactor, step: 1),
                    offset: entry.offset,
                    start: entry.start
                )
            }
            draft.adjustedSensitivities = InsulinSensitivities(
                units: draft.originalSensitivities.units,
                userPreferredUnits: draft.originalSensitivities.userPreferredUnits,
                sensitivities: scaledSensitivities
            )

            // CR — scale each ratio, then quantize to the CR picker step (0.1 g/U)
            let scaledRatios = draft.originalCarbRatios.schedule.map { entry in
                CarbRatioEntry(
                    start: entry.start,
                    offset: entry.offset,
                    ratio: Self.roundToStep(entry.ratio * crFactor, step: 0.1)
                )
            }
            draft.adjustedCarbRatios = CarbRatios(
                units: draft.originalCarbRatios.units,
                schedule: scaledRatios
            )
        }

        /// Round `value` to the nearest multiple of `step` (plain rounding, half-up).
        private static func roundToStep(_ value: Decimal, step: Decimal) -> Decimal {
            guard step > 0 else { return value }
            var divided = value / step
            var rounded = Decimal()
            NSDecimalRound(&rounded, &divided, 0, .plain)
            return rounded * step
        }

        /// Persist the draft as a new (non-active) profile. Returns success.
        func saveDraft() async -> Bool {
            let preferences = draft.preferencesSource
            let therapy = draft.therapyBundle
            let id = await provider.saveNewProfile(
                name: draft.name,
                preferences: preferences,
                therapy: therapy
            )
            await refresh()
            return id != nil
        }

        private static func fallbackBasalRates(pumpIncrement: Decimal) -> [Decimal] {
            // 0.05 → 30 U/hr, same ceiling BasalProfileEditor uses
            var out: [Decimal] = []
            var current: Decimal = pumpIncrement
            while current <= 30 {
                out.append(current)
                current += pumpIncrement
            }
            return out
        }
    }
}
