import Foundation

/// The SMB loop-mode an autoISF evaluation resolves to. Consumed by
/// `AutoISFsmb.variableSMBRatio` and by the SMB dosing path in
/// `DosingEngine.determineSMBDelivery` to decide whether the `max(fixed, ramp)`
/// full-loop floor applies.
enum AutoISFLoopMode {
    case oref // fall through to standard SMB enabling logic
    case enforced // SMB on — even target at normal BG
    case fullLoop // SMB on — even temp-target below 100
    case blocked // SMB off — odd target
    case iobTHExceeded // SMB off — IOB exceeds threshold
    case b30Running // SMB off — B30 basal active
}

/// Consolidated result from  autoISF  for one loop iteration.
struct AutoISFEngineResult {
    /// Adjusted ISF — replaces the caller's `adjustedSensitivity` when non-nil.
    let adjustedSensitivity: Decimal?
    /// SMB enabled override — nil means defer to standard oref logic.
    let smbEnabled: Bool?
    /// Full ISF reason string, always populated.
    let isfReason: String
    /// ISF sub-module result (for Determination ratio fields).
    let adjustResult: AutoISFAdjustResult?
    /// SMB sub-module result (for iobTH field).
    let smbResult: AutoISFsmbResult?
    /// AutoISF glucose status (for Determination parabola / dura / acce fields).
    let glucoseStatus: AutoISFGlucoseStatus?
}

/// Coordinates all autoISF sub-modules for a single loop iteration.
///
/// Callers pass their current `adjustedSensitivity` and receive back a result
/// bundle: one field to update sens, one to override SMB, one ready-to-use
/// reason string, and sub-results for the Determination struct.
///
/// SMB control runs whenever autoISF is enabled, regardless of dynISF.
/// ISF adjustment only runs when dynISF is inactive.
enum AutoISF {
    static func run(
        profile: Profile,
        dynamicIsfActive: Bool,
        adjustedSensitivity: Decimal,
        profileSens: Decimal,
        targetBG: Decimal,
        sensitivityRatio: Decimal,
        originalSensitivity: Decimal,
        exerciseModeActive: Bool,
        resistanceModeActive: Bool,
        microBolusAllowed: Bool,
        iob: Decimal,
        b30IsActive: Bool,
        autoISFStatus: AutoISFGlucoseStatus?,
        overrideSmbIsOff: Bool
    ) -> AutoISFEngineResult {
        let autosensReason = AutoISFReason.autosensOnlyReason(
            ratio: sensitivityRatio,
            originalSensitivity: originalSensitivity,
            adjustedSensitivity: adjustedSensitivity
        )

        // SMB control: runs whenever autoISF is enabled, independent of dynISF
        let smbResult = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: targetBG,
            microBolusAllowed: microBolusAllowed,
            iob: iob,
            b30IsActive: b30IsActive,
            exerciseModeActive: exerciseModeActive,
            overrideSmbIsOff: overrideSmbIsOff
        )
        let smbEnabled: Bool? = smbResult.flatMap { $0.loopMode != .oref ? $0.smbEnabled : nil }

        // ISF adjustment: only when dynISF is inactive and glucose status is available
        guard !dynamicIsfActive, let status = autoISFStatus else {
            return AutoISFEngineResult(
                adjustedSensitivity: nil,
                smbEnabled: smbEnabled,
                isfReason: autosensReason,
                adjustResult: nil,
                smbResult: smbResult,
                glucoseStatus: autoISFStatus
            )
        }

        let adjustResult = AutoISFAdjust.calculate(
            sens: adjustedSensitivity,
            profileSens: profileSens,
            targetBG: targetBG,
            profile: profile,
            glucoseStatus: status,
            sensitivityRatio: sensitivityRatio,
            exerciseModeActive: exerciseModeActive,
            resistanceModeActive: resistanceModeActive
        )

        let isfReason: String
        if let adjustResult = adjustResult {
            isfReason = AutoISFReason.isfReason(
                autosensEnabled: profile.enableAutosens,
                sensitivityRatio: sensitivityRatio,
                smbFragment: smbResult?.reason ?? "",
                parabolaFragment: AutoISFReason.parabolaFitTag(
                    enabled: profile.enableBGacceleration,
                    acceISFratio: adjustResult.acceISFratio,
                    status: status
                ),
                adjustReason: adjustResult.reason
            )
        } else {
            isfReason = autosensReason
        }

        return AutoISFEngineResult(
            adjustedSensitivity: adjustResult?.adjustedSens,
            smbEnabled: smbEnabled,
            isfReason: isfReason,
            adjustResult: adjustResult,
            smbResult: smbResult,
            glucoseStatus: status
        )
    }
}
