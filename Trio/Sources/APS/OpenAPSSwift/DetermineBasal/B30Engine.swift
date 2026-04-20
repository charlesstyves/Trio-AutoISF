import Foundation

/// Result from the B30 boost-basal evaluation.
struct B30Result {
    /// Whether B30 boost basal is currently active.
    let isActive: Bool
    /// Boosted basal rate (basal × b30Factor, pump-rounded). Only meaningful when isActive.
    let boostRate: Decimal
    /// Minutes remaining in the B30 window. Only meaningful when isActive.
    let remainingMinutes: Decimal
    /// Reason fragment for inclusion in the determination reason string.
    let reason: String
}

/// Evaluates whether the autoISF B30 boost-basal should activate for this loop cycle.
///
/// Ported from oref0 determine-basal.js lines 788–848.
/// Activation requires all of:
///   - autoISF and B30 both enabled
///   - Last manual bolus ≥ iTime_Start_Bolus, within b30_duration minutes
///   - EatingSoon temp target active and equal to iTime_target
///   - Current BG < b30_upperBG and delta ≤ b30_upperdelta
enum B30Engine {
    static func evaluate(
        profile: Profile,
        pumpHistory: [PumpHistoryEvent],
        currentTime: Date,
        targetBG: Decimal,
        currentBG: Decimal,
        bgDelta: Decimal,
        basal: Decimal
    ) -> B30Result {
        let inactive = B30Result(isActive: false, boostRate: basal, remainingMinutes: 0, reason: "")

        guard profile.enableB30, profile.autoisf else { return inactive }

        // Find the most recent manual bolus >= iTime_Start_Bolus (pumpHistory newest-first)
        let minBolus = profile.B30iTimeStartBolus
        var lastBolusAmount: Decimal = 0
        var lastBolusAge: Decimal = profile.B30iTime + 1 // default: outside window

        for event in pumpHistory {
            guard event.type == .bolus, !(event.isSMB ?? false),
                  let amount = event.amount, amount >= minBolus
            else { continue }
            lastBolusAmount = amount
            lastBolusAge = max(1, (Decimal(currentTime.timeIntervalSince(event.timestamp)) / 60).jsRounded(scale: 1))
            break
        }

        let b30Duration = profile.B30iTime
        let temptargetSet = profile.temptargetSet ?? false

        guard lastBolusAmount >= minBolus,
              lastBolusAge <= b30Duration,
              temptargetSet,
              targetBG == profile.B30iTimeTarget
        else { return inactive }

        let remainingMinutes = b30Duration - lastBolusAge

        guard bgDelta <= profile.B30upperDelta, currentBG < profile.B30upperLimit else {
            return B30Result(
                isActive: false,
                boostRate: basal,
                remainingMinutes: remainingMinutes,
                reason: "AIMI B30, cancelled, BG or Delta too high, "
            )
        }

        let boostRate = TempBasalFunctions.roundBasal(profile: profile, basalRate: basal * profile.B30basalFactor)
        let reason = " for \(remainingMinutes.jsRounded(scale: 0))m, "

        return B30Result(isActive: true, boostRate: boostRate, remainingMinutes: remainingMinutes, reason: reason)
    }
}
