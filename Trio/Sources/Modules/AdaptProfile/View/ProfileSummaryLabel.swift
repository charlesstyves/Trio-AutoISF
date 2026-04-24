import Foundation

/// Shared builder for the standard Adapt Profile summary label — applied percent,
/// total daily basal, and the "Algo / Targets tuned" badge. Call sites (History
/// profile rows, AdaptProfile list, Home chip subtitle) prepend or append their
/// own context-specific bits (countdown, run duration, etc.) around this core.
enum ProfileSummaryLabel {
    enum Tuning {
        case none
        case preferences
        case targets
        case both

        init(preferencesTuned: Bool, targetsTuned: Bool) {
            switch (preferencesTuned, targetsTuned) {
            case (true, true): self = .both
            case (true, false): self = .preferences
            case (false, true): self = .targets
            case (false, false): self = .none
            }
        }

        var text: String? {
            switch self {
            case .none: return nil
            case .both: return String(localized: "Algo & Targets tuned")
            case .preferences: return String(localized: "Algorithm Settings tuned")
            case .targets: return String(localized: "Glucose Targets tuned")
            }
        }
    }

    /// Standard summary strings in fixed order: percent → daily BR → tuned.
    /// Any of the inputs can be omitted; empty entries are filtered out.
    static func strings(
        appliedPercent: Decimal?,
        dailyBasalRate: Decimal?,
        tuning: Tuning
    ) -> [String] {
        var out = shortStrings(appliedPercent: appliedPercent, dailyBasalRate: dailyBasalRate)
        if let tunedStr = tuning.text {
            out.append(tunedStr)
        }
        return out
    }

    /// Compact variant for space-constrained rows (e.g. History profile entries that also
    /// show duration + time range). Drops the tuned badge.
    static func shortStrings(
        appliedPercent: Decimal?,
        dailyBasalRate: Decimal?
    ) -> [String] {
        var out: [String] = []
        if let pct = appliedPercent, pct != 100 {
            let pctStr = pct.formatted(.number.precision(.fractionLength(0)))
            out.append("\(pctStr) %")
        }
        if let br = dailyBasalRate {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            let brStr = formatter.string(from: br as NSNumber) ?? "\(br)"
            out.append("\(brStr) U/day")
        }
        return out
    }
}
