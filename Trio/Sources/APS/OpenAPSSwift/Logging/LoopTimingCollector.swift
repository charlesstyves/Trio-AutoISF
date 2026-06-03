import Foundation

/// Lightweight context threaded through every wrapper so per-call timing
/// rows can be tagged with the same `loopId` and the loop summary can be
/// reconstructed at the end. `collector` aggregates the per-call durations.
/// `hasShadow` reflects whether the JS shadow path is also being run.
struct LoopTimingContext {
    let loopId: UUID
    let apsLoopId: UUID
    let entryPoint: String
    let algoContext: String
    let activePath: String
    let hasShadow: Bool
    let collector: LoopTimingCollector
}

/// Collects per-loop timing data so the public `OpenAPS.determineBasal` can
/// emit a single `TmpAlgoLoopSummary` row at the end. One instance per loop.
///
/// Thread-safety: wrappers run sequentially within a single loop's await chain,
/// so simple accumulation under a lock is enough.
final class LoopTimingCollector {
    let loopId: UUID
    let algoContext: String
    let activePath: String
    let hasShadow: Bool

    private let lock = NSLock()
    private var activeSumMs: Double = 0
    private var shadowSumMs: Double = 0
    private var comparisons: Int = 0
    /// Sub-section name → cumulative ms within this loop. Sub-section names are
    /// the dotted paths emitted by `OrefSubTimer.time` (e.g.
    /// "determineBasal.AutoISF.run", "autoISFGlucose.calculateParabolaFit").
    /// Multiple invocations of the same sub-section in one loop accumulate.
    private var subSections: [String: Double] = [:]

    init(loopId: UUID, algoContext: String, activePath: String, hasShadow: Bool) {
        self.loopId = loopId
        self.algoContext = algoContext
        self.activePath = activePath
        self.hasShadow = hasShadow
    }

    func recordActive(ms: Double) {
        lock.lock()
        defer { lock.unlock() }
        activeSumMs += ms
    }

    func recordShadow(ms: Double) {
        lock.lock()
        defer { lock.unlock() }
        shadowSumMs += ms
        comparisons += 1
    }

    func recordSubSection(name: String, ms: Double) {
        lock.lock()
        defer { lock.unlock() }
        subSections[name, default: 0] += ms
    }

    var snapshot: (active: Double, shadow: Double, comparisons: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (activeSumMs, shadowSumMs, comparisons)
    }

    var subSectionsSnapshot: [String: Double] {
        lock.lock()
        defer { lock.unlock() }
        return subSections
    }
}
