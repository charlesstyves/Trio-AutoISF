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
    /// Effective SMB delivery ratio (ramped or fixed), already clamped to `[0, 1]`.
    /// DosingEngine uses this for the microbolus amount; also stored in Determination.
    let smbRatio: Decimal
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
        currentGlucose: Decimal,
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

        // Effective SMB delivery ratio (fixed or BG-range-ramped), pre-computed once so
        // DosingEngine and Determination can read the same value.
        let smbRatio = min(
            AutoISFsmb.variableSMBRatio(
                profile: profile,
                currentGlucose: currentGlucose,
                targetGlucose: targetBG,
                loopMode: smbResult?.loopMode ?? .oref
            ),
            1
        )

        // ISF adjustment: only when dynISF is inactive and glucose status is available
        guard !dynamicIsfActive, let status = autoISFStatus else {
            return AutoISFEngineResult(
                adjustedSensitivity: nil,
                smbEnabled: smbEnabled,
                isfReason: autosensReason,
                smbRatio: smbRatio,
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
            smbRatio: smbRatio,
            adjustResult: adjustResult,
            smbResult: smbResult,
            glucoseStatus: status
        )
    }

    /// Outcome of the autoISF B30 dispatch. `notActive` → caller runs the standard
    /// oref dosing pipeline. `delivered` or `blocked` → caller returns the determination
    /// as-is (B30 took over either by boosting basal or by committing a safeguard fallback).
    enum B30Dispatch {
        case notActive
        case delivered(Determination)
        case blocked(Determination)
    }

    /// Mirrors JS `aimiRateActivated` branch — activation check, safeguard overlay,
    /// KetoProtect gate, and post-block SMB re-evaluation all live here so the top-level
    /// generator only has to ask autoISF for the outcome.
    ///
    /// - When safeguards suppress B30, AutoISFsmb is re-evaluated with `b30IsActive=false`
    ///   so the returned determination's `smbRatio` / `iobTH` / displayed SMB state reflect
    ///   the post-block reality (B30 isn't actually running).
    static func dispatchB30(
        b30Result: B30Result,
        determination: Determination,
        safetyInputs: B30SafetyInputs,
        profile: Profile,
        targetBG: Decimal,
        currentGlucose: Decimal,
        microBolusAllowed: Bool,
        iob: Decimal,
        exerciseModeActive: Bool,
        overrideSmbIsOff: Bool,
        bolusIOB: Decimal,
        basalIOB: Decimal,
        iobActivity: Decimal
    ) throws -> B30Dispatch {
        guard b30Result.isActive else { return .notActive }

        let (suppressed, afterSafeguards) = try AimiB30.applySafetyChecks(
            inputs: safetyInputs,
            determination: determination
        )

        if suppressed {
            var blocked = afterSafeguards
            let updatedSmb = AutoISFsmb.evaluate(
                profile: profile,
                targetBG: targetBG,
                microBolusAllowed: microBolusAllowed,
                iob: iob,
                b30IsActive: false,
                exerciseModeActive: exerciseModeActive,
                overrideSmbIsOff: overrideSmbIsOff
            )
            blocked.smbRatio = min(
                AutoISFsmb.variableSMBRatio(
                    profile: profile,
                    currentGlucose: currentGlucose,
                    targetGlucose: targetBG,
                    loopMode: updatedSmb?.loopMode ?? .oref
                ),
                1
            )
            blocked.iobTH = updatedSmb?.iobTHEffective
            return .blocked(blocked)
        }

        // Safeguards passed → deliver B30 boost. KetoProtect mirrors JS basal-set-temp.js
        // where keto check precedes the aimiRateActivated branch.
        var det = afterSafeguards
        let keto = KetoProtect.apply(
            rate: b30Result.boostRate,
            profile: profile,
            bolusIOB: bolusIOB,
            basalIOB: basalIOB,
            iobActivity: iobActivity
        )
        det.reason = keto.reason + b30Result.reason + det.reason
        det.reason = "AIMI B30, TBR \(keto.rate)U/hr" + det.reason
        det.reason += "calculated AIMI B30 Temp \(keto.rate)U/hr\(b30Result.reason)"
        det.rate = keto.rate
        det.duration = min(30, b30Result.remainingMinutes)
        return .delivered(det)
    }
}
