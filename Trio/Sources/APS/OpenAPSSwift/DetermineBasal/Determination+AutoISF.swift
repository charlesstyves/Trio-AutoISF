import Foundation

extension Determination {
    /// Populate the autoISF telemetry fields (ISF ratios, parabola/dura/bg_acce
    /// metrics, and the JS rT.BGI / rT.deviation / rT.iobActivity mirror trio)
    /// from a full autoISF result and the surrounding glucose-impact context.
    ///
    /// When `result.isfAdjustBypassed` is true (autoISF off, or exercise plus
    /// `autoISF_off_Sport`), the parabola / dura / bg_acce / acceISF / bgISF /
    /// ppISF / duraISF fields collapse to a sentinel `1` — there's no real
    /// adaptation to report.
    ///
    /// `auto_ISFratio` is `profileSens / adjustedSens` regardless of bypass —
    /// when autoISF bypasses, `adjustedSensitivity` carries the TT-modifier-
    /// widened value, so this still yields a meaningful ratio
    /// (profileSens / widenedSens).
    mutating func applyAutoISF(
        result: AutoISFEngineResult,
        originalSensitivity: Decimal,
        adjustedSensitivity: Decimal,
        glucoseImpact: Decimal,
        deviation: Decimal,
        iobActivity: Decimal?
    ) {
        let bypassed = result.isfAdjustBypassed
        smbRatio = result.smbRatio
        duraISFratio = bypassed ? 1 : result.adjustResult?.duraISFratio
        bgISFratio = bypassed ? 1 : result.adjustResult?.bgISFratio
        ppISFratio = bypassed ? 1 : result.adjustResult?.ppISFratio
        acceISFratio = bypassed ? 1 : result.adjustResult?.acceISFratio
        autoISFratio = bypassed
            ? (adjustedSensitivity > 0 ? (originalSensitivity / adjustedSensitivity).jsRounded(scale: 2) : 1)
            : result.adjustResult?.autoISFratio
        iobTH = result.smbResult?.iobTHEffective
        // Parabola fit metrics from glucose analysis.
        parabolaFitMinutes = bypassed ? 1 : result.glucoseStatus?.dura_p
        parabolaFitLastDelta = bypassed ? 1 : result.glucoseStatus?.delta_pl
        parabolaFitNextDelta = bypassed ? 1 : result.glucoseStatus?.delta_pn
        parabolaFitCorrelation = bypassed ? 1 : result.glucoseStatus?.r_squ
        parabolaFitA0 = bypassed ? 1 : result.glucoseStatus?.a_0
        parabolaFitA1 = bypassed ? 1 : result.glucoseStatus?.a_1
        parabolaFitA2 = bypassed ? 1 : result.glucoseStatus?.a_2
        // Duration ISF window metrics.
        duraMin = bypassed ? 1 : result.glucoseStatus?.dura_ISF_minutes
        duraAvg = bypassed ? 1 : result.glucoseStatus?.dura_ISF_average
        bgAcce = bypassed ? 1 : result.glucoseStatus?.bg_acceleration
        // Glucose-impact pipeline (mirrors JS rT.BGI / rT.deviation / rT.iobActivity).
        bgi = glucoseImpact.jsRounded()
        self.deviation = deviation
        self.iobActivity = iobActivity
    }
}
