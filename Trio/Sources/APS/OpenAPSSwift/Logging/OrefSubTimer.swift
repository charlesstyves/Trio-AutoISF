import Foundation

/// Lightweight sub-section timer used inside `determineBasal` to identify
/// which calculations dominate the loop's wall time. Emits one log line
/// per timed call:
///
///     [ALGOPERF-SUB] <name> active=12.34ms
///
/// Gated on `OrefSubTimer.enabled`; the call site stays free of timing
/// noise when sub-tracing is off (no Date allocation, no debug log).
///
/// Set `OrefSubTimer.enabled = settings.algoShadowCompare` from the
/// pipeline entry point so sub-tracing only runs when the user has the
/// algo-compare diagnostic toggle on.
enum OrefSubTimer {
    /// Master switch. Defaults off so production loops don't pay the timer.
    static var enabled: Bool = false

    /// When set by the pipeline (around the determineBasal active-path call),
    /// every `time(...)` invocation also accumulates its elapsed ms into the
    /// collector's per-loop sub-section dict. Cleared after the active call so
    /// subsequent unrelated work doesn't pollute the loop summary.
    static var currentCollector: LoopTimingCollector?

    @inline(__always) static func time<T>(_ name: String, _ work: () throws -> T) rethrows -> T {
        guard enabled else { return try work() }
        let start = Date()
        let result = try work()
        let elapsedMs = Date().timeIntervalSince(start) * 1000
        debug(.openAPSSwift, String(format: "[ALGOPERF-SUB] %@ active=%.2fms", name, elapsedMs))
        currentCollector?.recordSubSection(name: name, ms: elapsedMs)
        return result
    }
}
