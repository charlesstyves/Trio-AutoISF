import SwiftUI

struct AlgoComparisonAnalysisView: View {
    @State private var snapshot: AlgoComparisonAnalyzer.Snapshot?
    @State private var window: AlgoComparisonAnalyzer.Window = .last24h
    @State private var isLoading = false
    @State private var showClearConfirm = false

    var body: some View {
        List {
            Picker("Window", selection: $window) {
                ForEach(AlgoComparisonAnalyzer.Window.allCases) { w in
                    Text(w.label).tag(w)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            if isLoading && snapshot == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let snap = snapshot {
                summarySection(snap)
                if let pipeline = snap.pipelineStats {
                    pipelineSection(pipeline, totalLoops: snap.totalLoops)
                }
                if !snap.perFunction.isEmpty {
                    perFunctionSection(snap.perFunction)
                }
                if !snap.topDivergentFields.isEmpty {
                    divergentFieldsSection(snap.topDivergentFields)
                }
                if !snap.recentLoops.isEmpty {
                    recentLoopsSection(snap.recentLoops)
                }
                clearSection
            } else {
                Text("No comparison data yet. Run a few loops with the toggle on.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Algo Compare Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: window) { await load() }
        .refreshable { await load() }
        .alert("Clear all comparison data?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task {
                    await AlgoComparisonPersistence.deleteAll()
                    await load()
                }
            }
        } message: {
            Text(
                "Deletes every TmpAlgoFunctionTiming and TmpAlgoLoopSummary row. This data is diagnostic only and is not used by the loop."
            )
        }
    }

    @ViewBuilder private func summarySection(_ snap: AlgoComparisonAnalyzer.Snapshot) -> some View {
        Section("Overview") {
            kvRow("Loops", "\(snap.totalLoops)")
            kvRow("With shadow", "\(snap.shadowLoops)")
            if !snap.activePathBreakdown.isEmpty {
                let breakdown = snap.activePathBreakdown
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key): \($0.value)" }
                    .joined(separator: "  ")
                kvRow("Active path", breakdown)
            }
            if let earliest = snap.earliestTimestamp, let latest = snap.latestTimestamp {
                kvRow("Range", "\(Self.dateFormatter.string(from: earliest)) → \(Self.dateFormatter.string(from: latest))")
            }
        }
    }

    @ViewBuilder private func pipelineSection(_ p: AlgoComparisonAnalyzer.PipelineStats, totalLoops: Int) -> some View {
        Section("Pipeline timing (per loop)") {
            kvRow("p50 total", String(format: "%.0f ms", p.p50TotalMs))
            kvRow("p95 total", String(format: "%.0f ms", p.p95TotalMs))
            kvRow("avg total", String(format: "%.0f ms", p.avgTotalMs))
            kvRow("p50 Swift modules", "\(String(format: "%.0f ms", p.p50SwiftSumMs))  (n=\(p.swiftSampleCount))")
            kvRow("p50 JS modules", "\(String(format: "%.0f ms", p.p50JsSumMs))  (n=\(p.jsSampleCount))")
            kvRow("p50 wait (data fetch / I/O)", String(format: "%.0f ms", p.p50WaitMs))
            Text("\(totalLoops) loop summary rows")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder private func perFunctionSection(_ functions: [AlgoComparisonAnalyzer.FunctionStats]) -> some View {
        Section("Per function") {
            ForEach(functions) { f in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(f.function).bold()
                        Spacer()
                        Text("\(f.totalCalls) calls")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if f.swiftSampleCount > 0 {
                        Text(
                            "Swift  p50 \(String(format: "%.1f", f.swiftP50Ms)) ms  p95 \(String(format: "%.1f", f.swiftP95Ms)) ms  (n=\(f.swiftSampleCount))"
                        )
                        .font(.caption)
                    }
                    if f.jsSampleCount > 0 {
                        Text(
                            "JS     p50 \(String(format: "%.1f", f.jsP50Ms)) ms  p95 \(String(format: "%.1f", f.jsP95Ms)) ms  (n=\(f.jsSampleCount))"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    if f.shadowCount > 0 {
                        let pct = f.matchingRate * 100
                        HStack(spacing: 12) {
                            Text(String(format: "matching %.0f%% (%d/%d)", pct, f.matchingCount, f.shadowCount))
                                .font(.caption)
                                .foregroundColor(f.matchingCount == f.shadowCount ? .green : .orange)
                            if f.valueDifferenceCount > 0 {
                                Text(String(format: "avg diffs %.1f", f.avgDiffCount))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder private func divergentFieldsSection(_ fields: [AlgoComparisonAnalyzer.DivergentField]) -> some View {
        Section("Top divergent fields") {
            ForEach(fields.prefix(20)) { d in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(d.path).font(.caption.monospaced())
                        Spacer()
                        Text("\(d.occurrences)×").font(.caption).foregroundColor(.secondary)
                    }
                    HStack(spacing: 12) {
                        Text("js: \(d.exampleJs)").font(.caption2.monospaced()).foregroundColor(.secondary)
                        Text("swift: \(d.exampleSwift)").font(.caption2.monospaced()).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder private func recentLoopsSection(_ loops: [AlgoComparisonAnalyzer.LoopRow]) -> some View {
        Section("Recent loops") {
            ForEach(loops) { loop in
                NavigationLink {
                    AlgoComparisonLoopDetailView(apsLoopId: loop.apsLoopId)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(Self.dateFormatter.string(from: loop.timestamp))
                                .font(.caption)
                            Spacer()
                            Text("\(loop.activePath) · \(loop.algoContext)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 12) {
                            Text(String(format: "total %.0fms", loop.pipelineTotalMs)).font(.caption)
                            Text(String(format: "active %.0f", loop.moduleSumActiveMs)).font(.caption2)
                                .foregroundColor(.secondary)
                            if loop.hasShadow {
                                Text(String(format: "shadow %.0f", loop.moduleSumShadowMs)).font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(String(format: "wait %.0f", loop.waitMs)).font(.caption2).foregroundColor(.secondary)
                        }
                        if !loop.entryPoints.isEmpty {
                            Text(loop.entryPoints.joined(separator: " → "))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear all comparison data")
                }
            }
        } footer: {
            Text(
                "This is diagnostic data for the Swift oref port. It is safe to delete and will be regenerated on the next loop."
            )
        }
    }

    private func kvRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }()

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        snapshot = await AlgoComparisonAnalyzer.snapshot(window: window)
    }
}

struct AlgoComparisonLoopDetailView: View {
    let apsLoopId: UUID
    @State private var detail: AlgoComparisonAnalyzer.LoopDetail?

    var body: some View {
        List {
            if let d = detail {
                summary(d.summary)
                ForEach(d.subPipelines) { sub in
                    subPipelineSection(sub)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("APS Loop")
        .navigationBarTitleDisplayMode(.inline)
        .task { detail = await AlgoComparisonAnalyzer.loopDetail(apsLoopId: apsLoopId) }
    }

    @ViewBuilder private func summary(_ s: AlgoComparisonAnalyzer.LoopRow) -> some View {
        Section("Summary (aggregated)") {
            row("Timestamp", AlgoComparisonAnalysisView_dateString(s.timestamp))
            row("Active path", s.activePath)
            row("Context", s.algoContext)
            row("Entry points", s.entryPoints.joined(separator: " → "))
            row("Pipeline total", String(format: "%.1f ms", s.pipelineTotalMs))
            row("Active modules sum", String(format: "%.1f ms", s.moduleSumActiveMs))
            if s.hasShadow {
                row("Shadow modules sum", String(format: "%.1f ms", s.moduleSumShadowMs))
                row("Comparisons", "\(s.comparisonsCount)")
            }
            row("Wait", String(format: "%.1f ms", s.waitMs))
        }
    }

    @ViewBuilder private func subPipelineSection(_ sub: AlgoComparisonAnalyzer.SubPipeline) -> some View {
        Section(sub.entryPoint) {
            row("Pipeline", String(format: "%.1f ms", sub.pipelineTotalMs))
            row("Active sum", String(format: "%.1f ms", sub.moduleSumActiveMs))
            if sub.moduleSumShadowMs > 0 {
                row("Shadow sum", String(format: "%.1f ms", sub.moduleSumShadowMs))
            }
            row("Wait", String(format: "%.1f ms", sub.waitMs))
            ForEach(sub.timings) { t in
                timingRow(t)
            }
        }
    }

    @ViewBuilder private func timingRow(_ t: AlgoComparisonAnalyzer.TimingRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(t.function).font(.caption.bold())
                Spacer()
                if let result = t.resultType {
                    Text(result).font(.caption2).foregroundColor(.secondary)
                }
            }
            HStack(spacing: 12) {
                Text(String(format: "active %.1f ms", t.activeDurationMs)).font(.caption2)
                if let s = t.shadowDurationMs {
                    Text(String(format: "shadow %.1f ms", s)).font(.caption2).foregroundColor(.secondary)
                }
                if t.diffCount > 0 {
                    Text("\(t.diffCount) diffs").font(.caption2).foregroundColor(.orange)
                }
            }
            if t.diffCount > 0 {
                ForEach(t.differences) { d in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(d.path).font(.caption2.monospaced())
                        HStack {
                            Text("js: \(d.jsRepr)").font(.caption2.monospaced()).foregroundColor(.secondary)
                            Spacer()
                            Text("swift: \(d.swiftRepr)").font(.caption2.monospaced()).foregroundColor(.secondary)
                        }
                        if d.jsKeyMissing {
                            Text("JS key missing").font(.caption2).foregroundColor(.orange)
                        }
                        if d.nativeKeyMissing {
                            Text("Swift key missing").font(.caption2).foregroundColor(.orange)
                        }
                        if d.nested {
                            Text("(nested array/object)").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 8)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
}

private func AlgoComparisonAnalysisView_dateString(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f.string(from: date)
}
