import Foundation

/// Consolidated result from the autoISF engine for one loop iteration.
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
    let smbResult: AutoISFSMBResult?
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
enum AutoISFEngine {
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
        autoISFStatus: AutoISFGlucoseStatus?
    ) -> AutoISFEngineResult {
        let autosensReason =
            "autosens:, \(sensitivityRatio.jsRounded(scale: 2)), ISF: \(originalSensitivity.jsRounded())→\(adjustedSensitivity.jsRounded())"

        // SMB control: runs whenever autoISF is enabled, independent of dynISF
        let smbResult = AutoISFSMBControl.evaluate(
            profile: profile,
            microBolusAllowed: microBolusAllowed,
            iob: iob,
            b30IsActive: b30IsActive,
            exerciseModeActive: exerciseModeActive
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
            var smbStr = ""
            if let smbResult = smbResult, !smbResult.reason.isEmpty {
                smbStr = "\(smbResult.reason), "
            }
            var parabolaStr = ""
            if status.a_2 > 0 {
                let tMin = -(status.a_1 / (2 * status.a_2))
                if tMin < 0 {
                    let minsAgo = (-tMin * 5).jsRounded(scale: 1)
                    let minBG = (status.a_0 - status.a_1 * status.a_1 / (4 * status.a_2)).jsRounded()
                    parabolaStr = "Parabolic Fit:, saw Min of \(minBG), about \(minsAgo)min ago, "
                }
            }
            let autosensStr = profile.enableAutosens ? "autosens:, \(sensitivityRatio.jsRounded(scale: 2)), " : ""
            isfReason = "\(autosensStr)\(smbStr)\(parabolaStr)\(adjustResult.reason), Standard"
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
