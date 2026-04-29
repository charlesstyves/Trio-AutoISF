import CoreData
import Foundation

/// Read-side analytics over the temporary `TmpAlgoFunctionTiming` and
/// `TmpAlgoLoopSummary` tables. Pure aggregation + decoding; no UI concerns.
enum AlgoComparisonAnalyzer {
    enum Window: String, CaseIterable, Identifiable {
        case last24h
        case last7d
        case all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .last24h: return "24h"
            case .last7d: return "7d"
            case .all: return "All"
            }
        }

        var since: Date? {
            switch self {
            case .last24h: return Date().addingTimeInterval(-24 * 3600)
            case .last7d: return Date().addingTimeInterval(-7 * 24 * 3600)
            case .all: return nil
            }
        }
    }

    struct Snapshot {
        let window: Window
        let totalLoops: Int
        let shadowLoops: Int
        let earliestTimestamp: Date?
        let latestTimestamp: Date?
        let activePathBreakdown: [String: Int]
        let perFunction: [FunctionStats]
        let recentLoops: [LoopRow]
        let topDivergentFields: [DivergentField]
        let pipelineStats: PipelineStats?
    }

    struct FunctionStats: Identifiable {
        let function: String
        var id: String { function }
        let totalCalls: Int
        let shadowCount: Int
        let matchingCount: Int
        let valueDifferenceCount: Int
        let comparisonErrorCount: Int
        let swiftSampleCount: Int
        let swiftP50Ms: Double
        let swiftP95Ms: Double
        let swiftAvgMs: Double
        let jsSampleCount: Int
        let jsP50Ms: Double
        let jsP95Ms: Double
        let jsAvgMs: Double
        let avgDiffCount: Double
        var matchingRate: Double {
            shadowCount > 0 ? Double(matchingCount) / Double(shadowCount) : 0
        }
    }

    struct PipelineStats {
        let p50TotalMs: Double
        let p95TotalMs: Double
        let avgTotalMs: Double
        let p50SwiftSumMs: Double
        let p50JsSumMs: Double
        let p50WaitMs: Double
        let swiftSampleCount: Int
        let jsSampleCount: Int
    }

    /// Represents one APS loop tick — the sum of `createProfiles`, `autosense`,
    /// and `determineBasal` sub-pipelines that share an `apsLoopId`.
    struct LoopRow: Identifiable {
        let apsLoopId: UUID
        var id: UUID { apsLoopId }
        let timestamp: Date
        let activePath: String
        let algoContext: String
        let entryPoints: [String]
        let pipelineTotalMs: Double
        let moduleSumActiveMs: Double
        let moduleSumShadowMs: Double
        let waitMs: Double
        let comparisonsCount: Int
        let hasShadow: Bool
    }

    struct LoopDetail {
        let summary: LoopRow
        let subPipelines: [SubPipeline]
    }

    struct SubPipeline: Identifiable {
        let id: UUID
        let entryPoint: String
        let pipelineTotalMs: Double
        let moduleSumActiveMs: Double
        let moduleSumShadowMs: Double
        let waitMs: Double
        let timings: [TimingRow]
    }

    struct TimingRow: Identifiable {
        let id: UUID
        let function: String
        let activeDurationMs: Double
        let shadowDurationMs: Double?
        let resultType: String?
        let diffCount: Int
        let differences: [SlimDifference]
        let hasShadow: Bool
    }

    struct SlimDifference: Identifiable {
        let id = UUID()
        let path: String
        let jsRepr: String
        let swiftRepr: String
        let jsKeyMissing: Bool
        let nativeKeyMissing: Bool
        let nested: Bool
    }

    struct DivergentField: Identifiable {
        let id: String
        var path: String { id }
        let function: String
        let occurrences: Int
        let exampleJs: String
        let exampleSwift: String
    }

    // MARK: - Snapshot

    static func snapshot(window: Window, recentLoopLimit: Int = 25) async -> Snapshot {
        let context = CoreDataStack.shared.newTaskContext()
        return await context.perform {
            let summaryReq = NSFetchRequest<TmpAlgoLoopSummary>(entityName: "TmpAlgoLoopSummary")
            summaryReq.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            if let since = window.since {
                summaryReq.predicate = NSPredicate(format: "timestamp >= %@", since as NSDate)
            }
            let summaries = (try? context.fetch(summaryReq)) ?? []

            let timingReq = NSFetchRequest<TmpAlgoFunctionTiming>(entityName: "TmpAlgoFunctionTiming")
            timingReq.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            if let since = window.since {
                timingReq.predicate = NSPredicate(format: "timestamp >= %@", since as NSDate)
            }
            let timings = (try? context.fetch(timingReq)) ?? []

            let aggregated = aggregateByApsLoopId(summaries: summaries)
            let totalLoops = aggregated.count
            let shadowLoops = aggregated.filter { $0.hasShadow }.count
            let earliest = aggregated.last?.timestamp
            let latest = aggregated.first?.timestamp

            var activePathBreakdown: [String: Int] = [:]
            for row in aggregated {
                activePathBreakdown[row.activePath, default: 0] += 1
            }

            let byFunction: [String: [TmpAlgoFunctionTiming]] = Dictionary(grouping: timings, by: { $0.function ?? "?" })
            var perFunction: [FunctionStats] = []
            for (fn, rows) in byFunction {
                perFunction.append(buildFunctionStats(function: fn, rows: rows))
            }
            perFunction.sort { lhs, rhs in
                let order = ["makeProfile", "meal", "iob", "autosens", "determineBasal"]
                let li = order.firstIndex(of: lhs.function) ?? Int.max
                let ri = order.firstIndex(of: rhs.function) ?? Int.max
                return li < ri
            }

            let recentLoops = Array(aggregated.prefix(recentLoopLimit))

            var fieldCounter: [String: (function: String, count: Int, exampleJs: String, exampleSwift: String)] = [:]
            for row in timings where row.hasShadow && row.diffCount > 0 {
                let diffs = decodeDifferences(row.differencesJSON)
                let fnName = row.function ?? "?"
                for d in diffs {
                    let key = "\(fnName).\(d.path)"
                    if var existing = fieldCounter[key] {
                        existing.count += 1
                        fieldCounter[key] = existing
                    } else {
                        fieldCounter[key] = (fnName, 1, d.jsRepr, d.swiftRepr)
                    }
                }
            }
            let topDivergentFields = fieldCounter
                .map { key, value in
                    DivergentField(
                        id: key,
                        function: value.function,
                        occurrences: value.count,
                        exampleJs: value.exampleJs,
                        exampleSwift: value.exampleSwift
                    )
                }
                .sorted { $0.occurrences > $1.occurrences }

            let totals = aggregated.map(\.pipelineTotalMs).filter { $0 > 0 }
            let pipelineStats: PipelineStats? = {
                guard !totals.isEmpty else { return nil }
                var swiftSums: [Double] = []
                var jsSums: [Double] = []
                for row in aggregated {
                    let isSwift = (row.activePath == "Swift")
                    if isSwift {
                        swiftSums.append(row.moduleSumActiveMs)
                        if row.hasShadow { jsSums.append(row.moduleSumShadowMs) }
                    } else {
                        jsSums.append(row.moduleSumActiveMs)
                        if row.hasShadow { swiftSums.append(row.moduleSumShadowMs) }
                    }
                }
                let waits = aggregated.map(\.waitMs)
                return PipelineStats(
                    p50TotalMs: percentile(totals, p: 0.5),
                    p95TotalMs: percentile(totals, p: 0.95),
                    avgTotalMs: average(totals),
                    p50SwiftSumMs: percentile(swiftSums, p: 0.5),
                    p50JsSumMs: percentile(jsSums, p: 0.5),
                    p50WaitMs: percentile(waits, p: 0.5),
                    swiftSampleCount: swiftSums.count,
                    jsSampleCount: jsSums.count
                )
            }()

            return Snapshot(
                window: window,
                totalLoops: totalLoops,
                shadowLoops: shadowLoops,
                earliestTimestamp: earliest,
                latestTimestamp: latest,
                activePathBreakdown: activePathBreakdown,
                perFunction: perFunction,
                recentLoops: recentLoops,
                topDivergentFields: topDivergentFields,
                pipelineStats: pipelineStats
            )
        }
    }

    // MARK: - Loop detail

    static func loopDetail(apsLoopId: UUID) async -> LoopDetail? {
        let context = CoreDataStack.shared.newTaskContext()
        return await context.perform {
            let summaryReq = NSFetchRequest<TmpAlgoLoopSummary>(entityName: "TmpAlgoLoopSummary")
            summaryReq.predicate = NSPredicate(format: "apsLoopId == %@", apsLoopId as CVarArg)
            summaryReq.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            let subSummaries = (try? context.fetch(summaryReq)) ?? []
            guard !subSummaries.isEmpty else { return nil }

            let timingReq = NSFetchRequest<TmpAlgoFunctionTiming>(entityName: "TmpAlgoFunctionTiming")
            timingReq.predicate = NSPredicate(format: "apsLoopId == %@", apsLoopId as CVarArg)
            timingReq.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            let timings = (try? context.fetch(timingReq)) ?? []
            let timingsBySubLoop: [UUID: [TmpAlgoFunctionTiming]] = Dictionary(grouping: timings, by: { $0.loopId ?? UUID() })

            let aggregated = aggregateByApsLoopId(summaries: subSummaries)
            guard let summary = aggregated.first else { return nil }

            let subPipelines: [SubPipeline] = subSummaries.map { s in
                let key = s.loopId ?? UUID()
                let subTimings = (timingsBySubLoop[key] ?? []).map { t in
                    TimingRow(
                        id: t.id ?? UUID(),
                        function: t.function ?? "?",
                        activeDurationMs: t.activeDurationMs,
                        shadowDurationMs: t.hasShadow ? t.shadowDurationMs : nil,
                        resultType: t.resultType,
                        diffCount: Int(t.diffCount),
                        differences: decodeDifferences(t.differencesJSON),
                        hasShadow: t.hasShadow
                    )
                }
                return SubPipeline(
                    id: key,
                    entryPoint: s.entryPoint ?? "?",
                    pipelineTotalMs: s.pipelineTotalMs,
                    moduleSumActiveMs: s.moduleSumActiveMs,
                    moduleSumShadowMs: s.moduleSumShadowMs,
                    waitMs: s.waitMs,
                    timings: subTimings
                )
            }

            return LoopDetail(summary: summary, subPipelines: subPipelines)
        }
    }

    // MARK: - Helpers

    private static func aggregateByApsLoopId(summaries: [TmpAlgoLoopSummary]) -> [LoopRow] {
        let groups: [UUID: [TmpAlgoLoopSummary]] = Dictionary(grouping: summaries, by: { $0.apsLoopId ?? $0.loopId ?? UUID() })
        var rows: [LoopRow] = []
        for (apsId, group) in groups {
            let ordered = group.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
            let latest = ordered.last
            let pipelineTotal = ordered.reduce(0.0) { $0 + $1.pipelineTotalMs }
            let activeSum = ordered.reduce(0.0) { $0 + $1.moduleSumActiveMs }
            let shadowSum = ordered.reduce(0.0) { $0 + $1.moduleSumShadowMs }
            let waitSum = ordered.reduce(0.0) { $0 + $1.waitMs }
            let cmpCount = ordered.reduce(0) { $0 + Int($1.comparisonsCount) }
            let hasShadow = ordered.contains { $0.hasShadow }
            let entryPoints = ordered.map { $0.entryPoint ?? "?" }
            let context = ordered.last(where: { $0.entryPoint == "determineBasal" })?.algoContext
                ?? latest?.algoContext ?? ""
            rows.append(LoopRow(
                apsLoopId: apsId,
                timestamp: latest?.timestamp ?? .distantPast,
                activePath: latest?.activePath ?? "?",
                algoContext: context,
                entryPoints: entryPoints,
                pipelineTotalMs: pipelineTotal,
                moduleSumActiveMs: activeSum,
                moduleSumShadowMs: shadowSum,
                waitMs: waitSum,
                comparisonsCount: cmpCount,
                hasShadow: hasShadow
            ))
        }
        return rows.sorted { $0.timestamp > $1.timestamp }
    }

    private static func buildFunctionStats(function: String, rows: [TmpAlgoFunctionTiming]) -> FunctionStats {
        var swiftMs: [Double] = []
        var jsMs: [Double] = []
        for r in rows {
            let isSwiftActive = (r.activePath == "Swift")
            if isSwiftActive {
                swiftMs.append(r.activeDurationMs)
                if r.hasShadow { jsMs.append(r.shadowDurationMs) }
            } else {
                jsMs.append(r.activeDurationMs)
                if r.hasShadow { swiftMs.append(r.shadowDurationMs) }
            }
        }
        let shadowRows = rows.filter { $0.hasShadow }
        let matching = shadowRows.filter { $0.resultType == ComparisonResultType.matching.rawValue }.count
        let valueDiff = shadowRows.filter { $0.resultType == ComparisonResultType.valueDifference.rawValue }.count
        let cmpError = shadowRows.filter { $0.resultType == ComparisonResultType.comparisonError.rawValue }.count
        let avgDiff: Double = shadowRows
            .isEmpty ? 0 : Double(shadowRows.reduce(0) { $0 + Int($1.diffCount) }) / Double(shadowRows.count)

        return FunctionStats(
            function: function,
            totalCalls: rows.count,
            shadowCount: shadowRows.count,
            matchingCount: matching,
            valueDifferenceCount: valueDiff,
            comparisonErrorCount: cmpError,
            swiftSampleCount: swiftMs.count,
            swiftP50Ms: percentile(swiftMs, p: 0.5),
            swiftP95Ms: percentile(swiftMs, p: 0.95),
            swiftAvgMs: average(swiftMs),
            jsSampleCount: jsMs.count,
            jsP50Ms: percentile(jsMs, p: 0.5),
            jsP95Ms: percentile(jsMs, p: 0.95),
            jsAvgMs: average(jsMs),
            avgDiffCount: avgDiff
        )
    }

    private static func decodeDifferences(_ json: String?) -> [SlimDifference] {
        guard let json = json,
              let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return arr.compactMap { dict in
            guard let path = dict["path"] as? String,
                  let js = dict["js"] as? String,
                  let sw = dict["swift"] as? String
            else { return nil }
            return SlimDifference(
                path: path,
                jsRepr: js,
                swiftRepr: sw,
                jsKeyMissing: (dict["jsKeyMissing"] as? Bool) ?? false,
                nativeKeyMissing: (dict["nativeKeyMissing"] as? Bool) ?? false,
                nested: (dict["nested"] as? Bool) ?? false
            )
        }
    }

    private static func percentile(_ values: [Double], p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let idx = max(0, min(sorted.count - 1, Int((Double(sorted.count) * p).rounded(.up)) - 1))
        return sorted[idx]
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
