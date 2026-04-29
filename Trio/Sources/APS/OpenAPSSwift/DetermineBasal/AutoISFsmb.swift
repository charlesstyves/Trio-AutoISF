import Foundation

/// Output of the autoISF SMB-activation decision.
struct AutoISFsmbResult {
    let loopMode: AutoISFLoopMode
    /// Effective IOB threshold value (for logging). 100 % of `iob_threshold_percent * max_iob`.
    let iobTHEffective: Decimal
    /// 130 %-tolerance virtual IOB ceiling used by `applyIobTHcap`. Mirrors JS `iobTHvirtual`.
    let iobTHVirtual: Decimal
    /// Reason fragment to prepend to the determination reason string.
    let reason: String

    var smbEnabled: Bool { loopMode == .enforced || loopMode == .fullLoop }
}

/// autoISF-specific SMB logic: ports `loop_smb()` (enable/disable decision) and
/// `determine_varSMBratio()` (variable delivery-ratio ramp) from
/// determine-basal.js (autoISF 3.01).
///
/// `evaluate` returns `nil` when autoISF is disabled (caller falls back to
/// standard SMB logic) and `.oref` when autoISF defers to oref's own SMB
/// enabling logic (same fallback).
enum AutoISFsmb {
    static func evaluate(
        profile: Profile,
        targetBG: Decimal,
        microBolusAllowed: Bool,
        iob: Decimal,
        b30IsActive: Bool,
        exerciseModeActive _: Bool,
        overrideSmbIsOff: Bool
    ) -> AutoISFsmbResult? {
        guard profile.autoisf else { return nil }

        // iob_threshold_percent == 1 (100 %) disables the iobTH method
        let useIobTH = profile.iobThresholdPercent != 1
        let (iobThEffective, iobThVirtual) = iobTHValues(profile: profile)

        // Override disabling SMB wins over all autoISF SMB logic
        if overrideSmbIsOff {
            return AutoISFsmbResult(
                loopMode: .blocked,
                iobTHEffective: iobThEffective,
                iobTHVirtual: iobThVirtual,
                reason: AutoISFReason.smbBlockedOverride
            )
        }

        // B30 basal active → SMB off (placeholder until B30 module is ported)
        if b30IsActive {
            return AutoISFsmbResult(
                loopMode: .b30Running,
                iobTHEffective: iobThEffective,
                iobTHVirtual: iobThVirtual,
                reason: AutoISFReason.smbBlockedB30Running
            )
        }

        guard microBolusAllowed else {
            return AutoISFsmbResult(
                loopMode: .oref,
                iobTHEffective: iobThEffective,
                iobTHVirtual: iobThVirtual,
                reason: ""
            )
        }

        // IOB threshold: disable SMB if IOB exceeds effective threshold
        if useIobTH, iobThEffective < iob {
            return AutoISFsmbResult(
                loopMode: .iobTHExceeded,
                iobTHEffective: iobThEffective,
                iobTHVirtual: iobThVirtual,
                reason: AutoISFReason.smbBlockedIobTHExceeded
            )
        }

        // Even/odd target override — only active when setting is enabled
        guard profile.enableSMBEvenOnOddOffAlways else {
            return AutoISFsmbResult(
                loopMode: .oref,
                iobTHEffective: iobThEffective,
                iobTHVirtual: iobThVirtual,
                reason: ""
            )
        }

        let evenTarget: Bool
        if profile.targetUnits == .mmolL {
            evenTarget = Int(NSDecimalNumber(decimal: (targetBG * 10).jsRounded()).doubleValue) % 2 == 0
        } else {
            evenTarget = Int(NSDecimalNumber(decimal: targetBG).doubleValue) % 2 == 0
        }

        guard evenTarget else {
            return AutoISFsmbResult(
                loopMode: .blocked,
                iobTHEffective: iobThEffective,
                iobTHVirtual: iobThVirtual,
                reason: AutoISFReason.smbBlockedOddTarget
            )
        }

        guard profile.maxIob > 0 else {
            return AutoISFsmbResult(
                loopMode: .blocked,
                iobTHEffective: iobThEffective,
                iobTHVirtual: iobThVirtual,
                reason: AutoISFReason.smbBlockedMaxIobZero
            )
        }

        // Below-100 min_bg signals a temp target → full-loop power
        if targetBG < 100 {
            return AutoISFsmbResult(
                loopMode: .fullLoop,
                iobTHEffective: iobThEffective,
                iobTHVirtual: iobThVirtual,
                reason: AutoISFReason.smbEnabledFullLoop(iobThEffective: iobThEffective)
            )
        }
        return AutoISFsmbResult(
            loopMode: .enforced,
            iobTHEffective: iobThEffective,
            iobTHVirtual: iobThVirtual,
            reason: AutoISFReason.smbEnabledEnforced(iobThEffective: iobThEffective)
        )
    }

    /// Computes the autoISF IOB-threshold values from the profile.
    ///
    /// Mirrors determine-basal.js (autoISF 3.01):
    /// - `iobThEffective` = `iob_threshold_percent * max_iob * iobTH_reduction_ratio`,
    ///   clamped to `max_iob` (JS `Math.min(profile.max_iob, iobThEffective)`).
    ///   Used by the gate (disable SMB when current IOB exceeds it).
    /// - `iobThVirtual`   = `iob_threshold_percent * 1.3 * max_iob * iobTH_reduction_ratio`.
    ///   The 130 % overrun ceiling used by `applyIobTHcap`.
    ///
    /// `iobTH_reduction_ratio` is 1.0 here — `exercise_ratio` is not yet ported.
    static func iobTHValues(profile: Profile) -> (effective: Decimal, virtual: Decimal) {
        let reductionRatio: Decimal = 1.0
        let effective = min(
            profile.maxIob,
            profile.iobThresholdPercent * profile.maxIob * reductionRatio
        )
        let virtual = profile.iobThresholdPercent * Decimal(1.3) * profile.maxIob * reductionRatio
        return (effective, virtual)
    }

    /// autoISF 130 % iobTH SMB cap. Mirrors determine-basal.js lines 1855-1864.
    ///
    /// If autoISF is enabled, the iobTH method is on (`iob_threshold_percent != 1`),
    /// and delivering this microBolus would push current IOB past `iobTHVirtual`,
    /// the bolus is clamped so post-delivery IOB stays at `iobTHVirtual`. Returns
    /// the (possibly reduced) bolus and a reason tail to append to the
    /// "Microbolusing Xu" string.
    ///
    /// The cap fires regardless of `enableSMB_EvenOn_OddOff_always` — same principle
    /// as the gate, which was decoupled from the toggle in May 2025. If the user set
    /// iobTH < 100 %, they want it enforced. With autoISF disabled this is a no-op.
    static func applyIobTHcap(
        profile: Profile,
        currentIob: Decimal,
        microBolus: Decimal,
        loopMode _: AutoISFLoopMode,
        iobTHVirtual: Decimal
    ) -> (microBolus: Decimal, reasonTail: String) {
        guard profile.autoisf,
              profile.iobThresholdPercent != 1,
              microBolus > iobTHVirtual - currentIob
        else {
            return (microBolus, "", reason)
        }
        return (
            smbResult.iobTHVirtual - currentIob,
            AutoISFReason.smbCappedByIobTH,
            AutoISFReason.applyIobTHCapTag(to: reason)
        )
    }

    /// Ports `determine_varSMBratio()` from determine-basal.js (autoISF 3.01).
    ///
    /// Produces the SMB delivery ratio to use for the microbolus calculation. When
    /// `smbDeliveryRatioBGrange > 0` the ratio ramps linearly from `smbDeliveryRatioMin`
    /// at BG target to `smbDeliveryRatioMax` at `target + bgRange`. With `bgRange == 0`
    /// the fixed `smbDeliveryRatio` is returned. In fullLoop mode the result is
    /// `max(fixed, ramp)` so the fixed ratio acts as a floor.
    static func variableSMBRatio(
        profile: Profile,
        currentGlucose: Decimal,
        targetGlucose: Decimal,
        loopMode: AutoISFLoopMode
    ) -> Decimal {
        // JS: if (bg_range < 10) bg_range /= 0.0555  → treat small values as mmol/L
        var bgRange = profile.smbDeliveryRatioBGrange
        if bgRange < 10 {
            bgRange /= Decimal(0.0555)
        }
        let fixSMB = profile.smbDeliveryRatio
        let lowerSMB = min(profile.smbDeliveryRatioMin, profile.smbDeliveryRatioMax)
        let higherSMB = max(profile.smbDeliveryRatioMin, profile.smbDeliveryRatioMax)
        let higherBG = targetGlucose + bgRange
        var newSMB = fixSMB

        if bgRange > 0 {
            newSMB = lowerSMB + (higherSMB - lowerSMB) * (currentGlucose - targetGlucose) / bgRange
            newSMB = max(lowerSMB, min(higherSMB, newSMB))
        }
        if loopMode == .fullLoop {
            return max(fixSMB, newSMB)
        }
        if bgRange == 0 {
            return fixSMB
        }
        if currentGlucose <= targetGlucose {
            return lowerSMB
        }
        if currentGlucose >= higherBG {
            return higherSMB
        }
        return newSMB
    }
}
