import Foundation

/// Result from the keto-protect evaluation.
struct KetoProtectResult {
    /// Final rate after applying the keto-protect floor (may equal the input rate).
    let rate: Decimal
    /// Reason fragment for prepending to the determination reason string. Empty when keto protect is off or inactive.
    let reason: String
}

/// Enforces a minimum basal rate floor to prevent insulin suspension long enough to cause ketosis.
///
/// Ported from oref0 basal-set-temp.js.
/// Two modes:
///   - Simple (`ketoProtect && !variableKetoProtect`): floor always enforced when rate < floor.
///   - Variable (`ketoProtect && variableKetoProtect`): floor enforced only when net IOB is deeply
///     negative (< −currentBasal) AND insulin activity is still decreasing (iobActivity < 0).
enum KetoProtect {
    static func apply(
        rate: Decimal,
        profile: Profile,
        bolusIOB: Decimal = 0,
        basalIOB: Decimal = 0,
        iobActivity: Decimal = 0
    ) -> KetoProtectResult {
        guard profile.ketoProtect || profile.variableKetoProtect,
              let currentBasal = profile.currentBasal
        else {
            return KetoProtectResult(rate: rate, reason: "")
        }

        // Compute floor rate — absolute takes precedence over percentage.
        var floor: Decimal
        if profile.ketoProtectAbsolut {
            floor = min(max(profile.ketoProtectBasalAbsolut, 0), 2)
        } else {
            // Percent clamped to 5–50 % of currentBasal.
            let pct = min(max(profile.ketoProtectBasalPercent * 100, 5), 50) / 100
            floor = currentBasal * pct
        }
        floor = TempBasalFunctions.roundBasal(profile: profile, basalRate: floor)

        let netIOB = bolusIOB + basalIOB
        var finalRate = rate
        var reason = ""

        if profile.ketoProtect, profile.variableKetoProtect {
            if netIOB < -currentBasal, iobActivity < 0 {
                // Variable mode active: net IOB is deeply negative and still waning.
                if finalRate < floor {
                    finalRate = floor
                    reason = "KetoVarProt:, \(floor)U/hr, "
                }
            } else if netIOB < 0 || iobActivity < 0 {
                // Variable mode conditions not met but IOB/activity state is relevant — log state, do not enforce floor.
                reason =
                    "KetoVarProt:, not active, IOB \(netIOB.jsRounded(scale: 2)) ?< \((-currentBasal).jsRounded(scale: 2)), iobActivity: \(iobActivity.jsRounded(scale: 3)) ?< 0, "
            }
        } else if profile.ketoProtect, !profile.variableKetoProtect {
            // Simple mode: always enforce floor.
            if finalRate < floor {
                finalRate = floor
                reason = "KetoProt:, \(floor)U/hr, "
            }
        }

        return KetoProtectResult(rate: finalRate, reason: reason)
    }
}
