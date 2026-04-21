import Foundation

/// Output of the autoISF SMB-activation decision.
struct AutoISFSMBResult {
    enum LoopMode {
        case oref // fall through to standard SMB enabling logic
        case enforced // SMB on — even target at normal BG
        case fullLoop // SMB on — even temp-target below 100
        case blocked // SMB off — odd target
        case iobTHExceeded // SMB off — IOB exceeds threshold
        case b30Running // SMB off — B30 basal active
    }

    let loopMode: LoopMode
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
                reason: "SMB disabled:, Override"
            )
        }

        // B30 basal active → SMB off (placeholder until B30 module is ported)
        if b30IsActive {
            return AutoISFSMBResult(
                loopMode: .b30Running,
                iobTHEffective: iobThEffective,
                reason: "SMB disabled:, B30 running"
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
                reason: "autoISF-SMB disabled:, iobTH exceeded"
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
                reason: "autoISF-SMB disabled:, odd Target"
            )
        }

        guard profile.maxIob > 0 else {
            return AutoISFSMBResult(
                loopMode: .blocked,
                iobTHEffective: iobThEffective,
                reason: "autoISF-SMB disabled:, maxIOB=0"
            )
        }

        // Below-100 min_bg signals a temp target → full-loop power
        if targetBG < 100 {
            return AutoISFSMBResult(
                loopMode: .fullLoop,
                iobTHEffective: iobThEffective,
                reason: "autoISF-SMB enabled:, even TT, eff.iobTH:, \(iobThEffective)"
            )
        }
        return AutoISFSMBResult(
            loopMode: .enforced,
            iobTHEffective: iobThEffective,
            reason: "autoISF-SMB enabled:, even Target, eff.iobTH:, \(iobThEffective)"
        )
    }
}
