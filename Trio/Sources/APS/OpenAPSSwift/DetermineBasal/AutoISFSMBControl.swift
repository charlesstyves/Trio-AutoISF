import Foundation

enum AutoISFLoopMode {
    case oref // fall through to standard SMB enabling logic
    case enforced // SMB on — even target at normal BG
    case fullLoop // SMB on — even temp-target below 100
    case blocked // SMB off — odd target
    case iobTHExceeded // SMB off — IOB exceeds threshold
    case b30Running // SMB off — B30 basal active
}

/// Output of the autoISF SMB-activation decision.
struct AutoISFSMBResult {
    let loopMode: AutoISFLoopMode
    /// Effective IOB threshold value (for logging).
    let iobTHEffective: Decimal
    /// Reason fragment to prepend to the determination reason string.
    let reason: String

    var smbEnabled: Bool { loopMode == .enforced || loopMode == .fullLoop }
}

/// Ports the `loop_smb()` function from determine-basal.js (autoISF 3.01).
///
/// Determines SMB activation via even/odd target and IOB-threshold checks.
/// Returns `nil` when autoISF is disabled (caller falls back to standard SMB logic).
/// Returns a result with `.oref` when autoISF provides no override (same fallback).
enum AutoISFSMBControl {
    static func evaluate(
        profile: Profile,
        targetBG: Decimal,
        microBolusAllowed: Bool,
        iob: Decimal,
        b30IsActive: Bool,
        exerciseModeActive _: Bool,
        overrideSmbIsOff: Bool
    ) -> AutoISFSMBResult? {
        guard profile.autoisf else { return nil }

        // iob_threshold_percent == 1 (100 %) disables the iobTH method
        let useIobTH = profile.iobThresholdPercent != 1
        // iobTH_reduction_ratio = 1.0 in normal mode (exercise_ratio not yet ported)
        let iobThEffective = (profile.iobThresholdPercent * profile.maxIob).jsRounded(scale: 1)

        // Override disabling SMB wins over all autoISF SMB logic
        if overrideSmbIsOff {
            return AutoISFSMBResult(
                loopMode: .blocked,
                iobTHEffective: iobThEffective,
                reason: AutoISFReason.smbBlockedOverride
            )
        }

        // B30 basal active → SMB off (placeholder until B30 module is ported)
        if b30IsActive {
            return AutoISFSMBResult(
                loopMode: .b30Running,
                iobTHEffective: iobThEffective,
                reason: AutoISFReason.smbBlockedB30Running
            )
        }

        guard microBolusAllowed else {
            return AutoISFSMBResult(loopMode: .oref, iobTHEffective: iobThEffective, reason: "")
        }

        // IOB threshold: disable SMB if IOB exceeds effective threshold
        if useIobTH, iobThEffective < iob {
            return AutoISFSMBResult(
                loopMode: .iobTHExceeded,
                iobTHEffective: iobThEffective,
                reason: AutoISFReason.smbBlockedIobTHExceeded
            )
        }

        // Even/odd target override — only active when setting is enabled
        guard profile.enableSMBEvenOnOddOffAlways else {
            return AutoISFSMBResult(loopMode: .oref, iobTHEffective: iobThEffective, reason: "")
        }

        let evenTarget: Bool
        if profile.targetUnits == .mmolL {
            evenTarget = Int(NSDecimalNumber(decimal: (targetBG * 10).jsRounded()).doubleValue) % 2 == 0
        } else {
            evenTarget = Int(NSDecimalNumber(decimal: targetBG).doubleValue) % 2 == 0
        }

        guard evenTarget else {
            return AutoISFSMBResult(
                loopMode: .blocked,
                iobTHEffective: iobThEffective,
                reason: AutoISFReason.smbBlockedOddTarget
            )
        }

        guard profile.maxIob > 0 else {
            return AutoISFSMBResult(
                loopMode: .blocked,
                iobTHEffective: iobThEffective,
                reason: AutoISFReason.smbBlockedMaxIobZero
            )
        }

        // Below-100 min_bg signals a temp target → full-loop power
        if targetBG < 100 {
            return AutoISFSMBResult(
                loopMode: .fullLoop,
                iobTHEffective: iobThEffective,
                reason: AutoISFReason.smbEnabledFullLoop(iobThEffective: iobThEffective)
            )
        }
        return AutoISFSMBResult(
            loopMode: .enforced,
            iobTHEffective: iobThEffective,
            reason: AutoISFReason.smbEnabledEnforced(iobThEffective: iobThEffective)
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
