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

    var snapshot: (active: Double, shadow: Double, comparisons: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (activeSumMs, shadowSumMs, comparisons)
    }
}
