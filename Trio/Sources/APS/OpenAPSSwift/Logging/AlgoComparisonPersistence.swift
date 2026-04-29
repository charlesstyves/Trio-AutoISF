import CoreData
import Foundation

/// Persistence layer for the temporary algo-comparison telemetry tables
/// (`TmpAlgoFunctionTiming` + `TmpAlgoLoopSummary`). Treat as a
/// development-only diagnostic — entities and this file are intended to
/// be deleted once the Swift port reaches parity with the JS implementation.
enum AlgoComparisonPersistence {
    /// Persist one function-timing row. Called from every wrapper, regardless
    /// of whether shadow comparison is active.
    static func saveFunctionTiming(
        loopId: UUID,
        apsLoopId: UUID,
        entryPoint: String,
        function: OrefFunction,
        algoContext: String,
        activePath: String,
        activeDurationMs: Double,
        shadowDurationMs: Double?,
        comparison: AlgorithmComparison?
    ) {
        let context = CoreDataStack.shared.newTaskContext()
        context.perform {
            let row = TmpAlgoFunctionTiming(context: context)
            row.id = UUID()
            row.timestamp = Date()
            row.loopId = loopId
            row.apsLoopId = apsLoopId
            row.entryPoint = entryPoint
            row.function = function.rawValue
            row.algoContext = algoContext
            row.activePath = activePath
            row.activeDurationMs = activeDurationMs

            if let shadowMs = shadowDurationMs, let cmp = comparison {
                row.hasShadow = true
                row.shadowDurationMs = shadowMs
                row.resultType = cmp.resultType.rawValue
                let diffs = cmp.differences ?? [:]
                row.diffCount = Int32(diffs.count)
                if !diffs.isEmpty {
                    row.differencesJSON = slimDifferences(diffs)
                }
            } else {
                row.hasShadow = false
                row.shadowDurationMs = 0
                row.diffCount = 0
            }

            do {
                if context.hasChanges { try context.save() }
            } catch {
                debug(.openAPS, "AlgoComparisonPersistence: failed to save timing: \(error)")
            }
        }
    }

    /// Persist the loop-level summary at the end of a public OpenAPS entry point.
    static func saveLoopSummary(
        loopId: UUID,
        apsLoopId: UUID,
        entryPoint: String,
        algoContext: String,
        activePath: String,
        pipelineTotalMs: Double,
        moduleSumActiveMs: Double,
        moduleSumShadowMs: Double,
        comparisonsCount: Int,
        hasShadow: Bool
    ) {
        let context = CoreDataStack.shared.newTaskContext()
        context.perform {
            let row = TmpAlgoLoopSummary(context: context)
            row.id = UUID()
            row.timestamp = Date()
            row.loopId = loopId
            row.apsLoopId = apsLoopId
            row.entryPoint = entryPoint
            row.algoContext = algoContext
            row.activePath = activePath
            row.pipelineTotalMs = pipelineTotalMs
            row.moduleSumActiveMs = moduleSumActiveMs
            row.moduleSumShadowMs = moduleSumShadowMs
            row.waitMs = max(0, pipelineTotalMs - moduleSumActiveMs - moduleSumShadowMs)
            row.comparisonsCount = Int32(comparisonsCount)
            row.hasShadow = hasShadow

            do {
                if context.hasChanges { try context.save() }
            } catch {
                debug(.openAPS, "AlgoComparisonPersistence: failed to save loop summary: \(error)")
            }
        }
    }

    /// Delete every comparison row (both timing and summary) — called from the
    /// "Clear" button in the Algorithm settings UI.
    static func deleteAll() async {
        let context = CoreDataStack.shared.newTaskContext()
        await context.perform {
            for entityName in ["TmpAlgoFunctionTiming", "TmpAlgoLoopSummary"] {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let delete = NSBatchDeleteRequest(fetchRequest: request)
                delete.resultType = .resultTypeStatusOnly
                do {
                    try context.execute(delete)
                } catch {
                    debug(.openAPS, "AlgoComparisonPersistence: failed to delete \(entityName): \(error)")
                }
            }
        }
    }

    /// Convert the full-fidelity `[String: ValueDifference]` into a slim,
    /// per-key summary that drops nested arrays/objects.
    private static func slimDifferences(_ differences: [String: ValueDifference]) -> String? {
        var slim: [[String: Any]] = []
        for (key, diff) in differences {
            slim.append([
                "path": key,
                "js": shortRepr(diff.js),
                "swift": shortRepr(diff.swift),
                "jsKeyMissing": diff.jsKeyMissing,
                "nativeKeyMissing": diff.nativeKeyMissing,
                "nested": isContainer(diff.js) || isContainer(diff.swift)
            ])
        }
        guard let data = try? JSONSerialization.data(withJSONObject: slim, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func shortRepr(_ value: JSONValue) -> String {
        switch value {
        case .null: return "null"
        case let .string(s): return s.count > 80 ? String(s.prefix(80)) + "…" : s
        case let .number(n):
            if n == n.rounded() { return String(format: "%g", n) }
            return String(format: "%.4f", n)
        case let .boolean(b): return b ? "true" : "false"
        case let .array(arr): return "<array[\(arr.count)]>"
        case let .object(obj): return "<object[\(obj.keys.count) keys]>"
        }
    }

    private static func isContainer(_ value: JSONValue) -> Bool {
        switch value {
        case .array, .object: return true
        default: return false
        }
    }
}
