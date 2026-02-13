import Foundation

/// Type of extremum detected at a glucose data point.
enum ExtremumType {
    case max
    case min
    case none
}

/// A minimal glucose data point for peak detection.
struct GlucosePoint {
    let date: Date
    let glucose: Int
}

/// Detects meaningful turning points (peaks and valleys) in a CGM glucose time series
/// using least-squares parabola fitting.
///
/// Ported concept from oref's `glucose-get-last.js` parabola fitting, adapted for
/// retrospective peak/valley detection in Trio's Swift Charts.
///
/// **Algorithm:**
///
/// For each data point in the glucose series, a quadratic curve `y = a₂·x² + a₁·x + a₀`
/// is fitted to the surrounding data within a sliding window using least-squares regression.
///
/// - `a₁` (slope at the point): when near zero, indicates a turning point
/// - `a₂` (curvature / acceleration): negative = peak (concave down), positive = valley (concave up)
/// - `r²` (correlation): quality of fit — only well-fitted turning points are accepted
///
/// This naturally rejects false peaks on monotonic slopes because `a₁` remains significantly
/// non-zero when glucose is steadily rising or falling.
///
/// After identifying candidate turning points, a minimum time gap is enforced between
/// same-type extrema to avoid clustering.
enum PeakPicker {
    // MARK: - Configuration

    /// Minimum |a₁| below which the slope is considered "near zero" (turning point).
    /// Units: mg/dL per 5 minutes. At a real turning point the fitted slope should be
    /// close to zero, but CGM noise and 5-min discretisation can push it to 2-4.
    private static let slopeThreshold: Double = 4.0

    /// Minimum |a₂| (curvature) to confirm the parabola has meaningful bend.
    private static let curvatureThreshold: Double = 0.0005

    /// Minimum r² for accepting a parabola fit.
    private static let minRSquared: Double = 0.50

    /// Minimum duration (seconds) of data required for a valid parabola fit.
    private static let minFitDuration: TimeInterval = 10 * 60 // 10 minutes

    /// Maximum duration (seconds) of data to include in the fit window (each side).
    private static let maxFitWindow: TimeInterval = 45 * 60 // 45 minutes each side

    /// Minimum time gap (seconds) between same-type extrema to avoid clustering.
    private static let minSameTypeGap: TimeInterval = 45 * 60 // 45 minutes

    /// Minimum glucose difference (mg/dL) between a peak and its nearest valley
    /// (or vice versa) for the turning point to be considered significant.
    private static let minAmplitude: Double = 25

    // MARK: - Public API

    /// Detects peaks and valleys in a glucose time series using parabola fitting.
    ///
    /// - Parameters:
    ///   - data: Time-ordered glucose measurements.
    ///   - windowHours: Not used directly but kept for API compatibility.
    ///   - secondaryWindowFactor: Not used — kept for API compatibility.
    ///   - oppositeGapFactor: Not used — kept for API compatibility.
    ///   - minSameTypeGapFactor: Not used — kept for API compatibility.
    ///
    /// - Returns: An array of `(point: GlucosePoint, type: ExtremumType)`
    ///            sorted by timestamp ascending.
    static func pick(
        data: [GlucosePoint],
        windowHours _: Double = 1,
        secondaryWindowFactor _: Double = 1.0 / 3.0,
        oppositeGapFactor _: Double = 1.9,
        minSameTypeGapFactor _: Double = 0.8
    ) -> [(point: GlucosePoint, type: ExtremumType)] {
        // Filter valid points, sorted oldest → latest
        let asc = data.filter { $0.glucose > 0 }
        let n = asc.count
        guard n >= 4 else { return [] } // need at least 4 points for a meaningful fit

        let times = asc.map(\.date)
        let vals = asc.map { Double($0.glucose) }

        // MARK: - Fit parabola at each point and identify turning-point candidates

        struct Candidate {
            let idx: Int
            let type: ExtremumType
            let slopeAbs: Double // |a₁| — lower is better (closer to zero)
            let rSquared: Double // fit quality — higher is better
        }

        var candidates: [Candidate] = []

        let scaleTime: Double = 300.0 // normalise time to 5-minute units

        for i in 0 ..< n {
            let t0 = times[i]

            // Gather all points within ±maxFitWindow around point i
            var sx: Double = 0
            var sx2: Double = 0
            var sx3: Double = 0
            var sx4: Double = 0
            var sy: Double = 0
            var sxy: Double = 0
            var sx2y: Double = 0
            var nFit = 0
            var fitPoints: [(ti: Double, bg: Double)] = []

            for j in 0 ..< n {
                let dt = times[j].timeIntervalSince(t0)
                if dt < -maxFitWindow { continue }
                if dt > maxFitWindow { break }

                let ti = dt / scaleTime
                let bg = vals[j]
                sx += ti
                sx2 += ti * ti
                sx3 += ti * ti * ti
                sx4 += ti * ti * ti * ti
                sy += bg
                sxy += ti * bg
                sx2y += ti * ti * bg
                nFit += 1
                fitPoints.append((ti: ti, bg: bg))
            }

            guard nFit >= 4 else { continue }

            // Check we have data on both sides of the center point
            guard let firstTi = fitPoints.first?.ti, let lastTi = fitPoints.last?.ti,
                  firstTi < -0.1, lastTi > 0.1 else { continue }

            let totalSpan = (lastTi - firstTi) * scaleTime
            guard totalSpan >= minFitDuration else { continue }

            let nf = Double(nFit)

            // Solve y = a₂·t² + a₁·t + a₀ using Cramer's rule
            let detH = sx4 * (sx2 * nf - sx * sx)
                - sx3 * (sx3 * nf - sx * sx2)
                + sx2 * (sx3 * sx - sx2 * sx2)

            guard abs(detH) > 1E-10 else { continue }

            let detA = sx2y * (sx2 * nf - sx * sx)
                - sxy * (sx3 * nf - sx * sx2)
                + sy * (sx3 * sx - sx2 * sx2)

            let detB = sx4 * (sxy * nf - sy * sx)
                - sx3 * (sx2y * nf - sy * sx2)
                + sx2 * (sx2y * sx - sxy * sx2)

            let detC = sx4 * (sx2 * sy - sx * sxy)
                - sx3 * (sx3 * sy - sx * sx2y)
                + sx2 * (sx3 * sxy - sx2 * sx2y)

            let a2 = detA / detH // curvature
            let a1 = detB / detH // slope at t=0
            let a0 = detC / detH // fitted value at t=0

            // Compute r²
            let yMean = sy / nf
            var ssTotal: Double = 0
            var ssResidual: Double = 0
            for pt in fitPoints {
                ssTotal += (pt.bg - yMean) * (pt.bg - yMean)
                let fitted = a2 * pt.ti * pt.ti + a1 * pt.ti + a0
                ssResidual += (pt.bg - fitted) * (pt.bg - fitted)
            }

            let rSquared: Double = ssTotal > 0 ? max(0, 1.0 - ssResidual / ssTotal) : 0

            // Turning point criteria
            guard rSquared >= minRSquared else { continue }
            guard abs(a1) <= slopeThreshold else { continue }
            guard abs(a2) >= curvatureThreshold else { continue }

            let type: ExtremumType = a2 < 0 ? .max : .min
            candidates.append(Candidate(idx: i, type: type, slopeAbs: abs(a1), rSquared: rSquared))
        }

        guard !candidates.isEmpty else { return [] }

        // MARK: - Select best turning points, enforcing minimum gap

        // Sort candidates by extremeness: for MAX, highest glucose first;
        // for MIN, lowest glucose first. This ensures the most prominent
        // turning points are selected before less significant ones.
        // We process MAX and MIN separately then merge.
        let maxCandidates = candidates.filter { $0.type == .max }
            .sorted { vals[$0.idx] > vals[$1.idx] } // highest glucose first
        let minCandidates = candidates.filter { $0.type == .min }
            .sorted { vals[$0.idx] < vals[$1.idx] } // lowest glucose first

        var selected: [(idx: Int, type: ExtremumType)] = []

        /// Check whether an opposite-type candidate exists between two same-type
        /// points in time. Uses the full candidate list (not just selected) so
        /// that the check works regardless of selection order.
        /// If an opposite-type turn lies between two same-type extrema, they
        /// belong to different wave cycles and the gap constraint is waived.
        let allCandidateEntries: [(idx: Int, type: ExtremumType)] = candidates.map { (idx: $0.idx, type: $0.type) }

        func hasOppositeBetween(
            typeA: ExtremumType,
            timeA: Date,
            timeB: Date
        ) -> Bool {
            let lo = min(timeA, timeB)
            let hi = max(timeA, timeB)
            return allCandidateEntries.contains { entry in
                entry.type != typeA &&
                    times[entry.idx] > lo &&
                    times[entry.idx] < hi
            }
        }

        // Greedily select MAX candidates
        for candidate in maxCandidates {
            let candidateTime = times[candidate.idx]
            let tooClose = selected.contains { existing in
                guard existing.type == .max else { return false }
                let gap = abs(times[existing.idx].timeIntervalSince(candidateTime))
                guard gap < minSameTypeGap else { return false }
                // Allow if there's an opposite-type turn between them
                return !hasOppositeBetween(
                    typeA: .max,
                    timeA: times[existing.idx],
                    timeB: candidateTime
                )
            }
            if tooClose { continue }
            selected.append((idx: candidate.idx, type: .max))
        }

        // Greedily select MIN candidates
        for candidate in minCandidates {
            let candidateTime = times[candidate.idx]
            let tooClose = selected.contains { existing in
                guard existing.type == .min else { return false }
                let gap = abs(times[existing.idx].timeIntervalSince(candidateTime))
                guard gap < minSameTypeGap else { return false }
                // Allow if there's an opposite-type turn between them
                return !hasOppositeBetween(
                    typeA: .min,
                    timeA: times[existing.idx],
                    timeB: candidateTime
                )
            }
            if tooClose { continue }
            selected.append((idx: candidate.idx, type: .min))
        }

        // Sort by time
        selected.sort { times[$0.idx] < times[$1.idx] }

        // MARK: - Snap to actual extreme value

        // The parabola vertex (a₁ ≈ 0) may not coincide with the actual highest/lowest
        // CGM reading. For each selected turning point, scan nearby data and replace
        // the index with the actual extreme glucose value within ±snapWindow.
        let snapWindow: TimeInterval = 15 * 60 // 15 minutes
        for i in 0 ..< selected.count {
            let centerIdx = selected[i].idx
            let centerTime = times[centerIdx]
            var bestIdx = centerIdx

            // Scan backwards from center
            for j in stride(from: centerIdx - 1, through: 0, by: -1) {
                if centerTime.timeIntervalSince(times[j]) > snapWindow { break }
                switch selected[i].type {
                case .max:
                    if vals[j] > vals[bestIdx] { bestIdx = j }
                case .min:
                    if vals[j] < vals[bestIdx] { bestIdx = j }
                case .none:
                    break
                }
            }
            // Scan forwards from center
            for j in (centerIdx + 1) ..< n {
                if times[j].timeIntervalSince(centerTime) > snapWindow { break }
                switch selected[i].type {
                case .max:
                    if vals[j] > vals[bestIdx] { bestIdx = j }
                case .min:
                    if vals[j] < vals[bestIdx] { bestIdx = j }
                case .none:
                    break
                }
            }
            selected[i] = (idx: bestIdx, type: selected[i].type)
        }

        // MARK: - Amplitude filter: remove minor turns

        // Iteratively remove the turning point with the smallest amplitude
        // (difference to its nearest opposite-type neighbour) until all
        // remaining turns exceed minAmplitude.
        while selected.count >= 2 {
            var worstIndex: Int?
            var worstAmplitude = Double.greatestFiniteMagnitude

            for i in 0 ..< selected.count {
                let val = vals[selected[i].idx]
                var amplitude = Double.greatestFiniteMagnitude

                // Look at the nearest neighbour(s) in the selected list
                if i > 0 {
                    amplitude = min(amplitude, abs(val - vals[selected[i - 1].idx]))
                }
                if i < selected.count - 1 {
                    amplitude = min(amplitude, abs(val - vals[selected[i + 1].idx]))
                }

                if amplitude < worstAmplitude {
                    worstAmplitude = amplitude
                    worstIndex = i
                }
            }

            guard let removeIdx = worstIndex, worstAmplitude < minAmplitude else { break }
            selected.remove(at: removeIdx)
        }

        // Convert to final result
        return selected.map { (point: asc[$0.idx], type: $0.type) }
    }

    // MARK: - Convenience method for GlucoseStored

    /// Convenience method that accepts `[GlucoseStored]` and converts internally.
    static func pick(
        data: [GlucoseStored],
        windowHours: Double = 1,
        secondaryWindowFactor: Double = 1.0 / 3.0,
        oppositeGapFactor: Double = 1.9,
        minSameTypeGapFactor: Double = 0.8
    ) -> [(date: Date, glucose: Int16, type: ExtremumType)] {
        let points = data.compactMap { g -> GlucosePoint? in
            guard let date = g.date else { return nil }
            return GlucosePoint(date: date, glucose: Int(g.glucose))
        }

        let results = pick(
            data: points,
            windowHours: windowHours,
            secondaryWindowFactor: secondaryWindowFactor,
            oppositeGapFactor: oppositeGapFactor,
            minSameTypeGapFactor: minSameTypeGapFactor
        )

        return results.map { (date: $0.point.date, glucose: Int16($0.point.glucose), type: $0.type) }
    }
}

// MARK: - CoreData import for GlucoseStored type reference

import CoreData
