import Charts
import SwiftUI

// Thin wrappers around the shared `TherapySettingEditorView` for each therapy schedule in the
// draft flow. Bindings write straight into the draft state model — no side effects.

extension AdaptProfile {
    /// Basal rate editor with the same chart + total daily basal footer as the live editor.
    struct DraftBasalEditor: View {
        @Bindable var state: DraftEditorStateModel
        @State private var refreshUI = UUID()
        @State private var now = Date()

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        private var rateFormatter: NumberFormatter {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            return f
        }

        var body: some View {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !state.basalItems.isEmpty {
                        VStack(alignment: .leading) {
                            chart
                                .frame(height: 180)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color.chart.opacity(0.65))
                        .clipShape(
                            .rect(
                                topLeadingRadius: 10,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 10
                            )
                        )
                    }

                    TherapySettingEditorView(
                        items: $state.basalItems,
                        unit: .unitPerHour,
                        timeOptions: state.timeValues,
                        valueOptions: state.basalRateValues
                    )

                    if !state.basalItems.isEmpty {
                        HStack {
                            Text("Total").bold()
                            Spacer()
                            Text(rateFormatter.string(from: totalDailyBasal as NSNumber) ?? "0")
                            Text("U/day").foregroundStyle(Color.secondary)
                        }
                        .id(refreshUI)
                        .padding()
                        .background(Color.chart.opacity(0.65))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Basal Rates")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: state.basalItems) { _, _ in refreshUI = UUID() }
        }

        private var chart: some View {
            Chart {
                ForEach(Array(state.basalItems.enumerated()), id: \.element.id) { index, item in
                    let start = Calendar.current.startOfDay(for: now).addingTimeInterval(item.time)
                    let endOffset: TimeInterval = index + 1 < state.basalItems.count
                        ? state.basalItems[index + 1].time
                        : 86400
                    let end = Calendar.current.startOfDay(for: now).addingTimeInterval(endOffset)

                    RectangleMark(
                        xStart: .value("start", start),
                        xEnd: .value("end", end),
                        yStart: .value("rate-start", item.value),
                        yEnd: .value("rate-end", 0)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.purple.opacity(0.6), Color.purple.opacity(0.1)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .alignsMarkStylesWithPlotArea()

                    LineMark(x: .value("start", start), y: .value("rate", item.value))
                        .lineStyle(.init(lineWidth: 1))
                        .foregroundStyle(Color.purple)
                    LineMark(x: .value("end", end), y: .value("rate", item.value))
                        .lineStyle(.init(lineWidth: 1))
                        .foregroundStyle(Color.purple)
                }
            }
            .id(refreshUI)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisValueLabel(format: .dateTime.hour())
                    AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                }
            }
            .chartXScale(
                domain: Calendar.current.startOfDay(for: now) ... Calendar.current.startOfDay(for: now)
                    .addingTimeInterval(60 * 60 * 24)
            )
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel()
                    AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                }
            }
        }

        private var totalDailyBasal: Decimal {
            var total: Decimal = 0
            let sorted = state.basalItems.sorted(by: { $0.time < $1.time })
            for (i, item) in sorted.enumerated() {
                let next = i + 1 < sorted.count ? sorted[i + 1].time : 86400
                let hours = Decimal((next - item.time) / 3600)
                total += item.value * hours
            }
            return total
        }
    }

    struct DraftISFEditor: View {
        @Bindable var state: DraftEditorStateModel

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !state.isfItems.isEmpty {
                        chartContainer {
                            TherapyScheduleChart(
                                items: state.isfItems,
                                color: .cyan,
                                valueTransform: { state.units == .mmolL ? $0.asMmolL : $0 }
                            )
                        }
                    }
                    TherapySettingEditorView(
                        items: $state.isfItems,
                        unit: state.units == .mmolL ? .mmolLPerUnit : .mgdLPerUnit,
                        timeOptions: state.timeValues,
                        valueOptions: state.isfRateValues
                    )
                }
                .padding(.horizontal)
            }
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Insulin Sensitivity")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    struct DraftCREditor: View {
        @Bindable var state: DraftEditorStateModel

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !state.crItems.isEmpty {
                        chartContainer {
                            TherapyScheduleChart(items: state.crItems, color: .orange)
                        }
                    }
                    TherapySettingEditorView(
                        items: $state.crItems,
                        unit: .gramPerUnit,
                        timeOptions: state.timeValues,
                        valueOptions: state.crRateValues
                    )
                }
                .padding(.horizontal)
            }
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Carb Ratio")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    struct DraftTargetEditor: View {
        @Bindable var state: DraftEditorStateModel

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !state.targetItems.isEmpty {
                        chartContainer {
                            TherapyScheduleChart(
                                items: state.targetItems,
                                color: .green,
                                lineOnly: true,
                                valueTransform: { state.units == .mmolL ? $0.asMmolL : $0 }
                            )
                        }
                    }
                    TherapySettingEditorView(
                        items: $state.targetItems,
                        unit: state.units == .mmolL ? .mmolL : .mgdL,
                        timeOptions: state.timeValues,
                        valueOptions: state.targetRateValues
                    )
                }
                .padding(.horizontal)
            }
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Glucose Targets")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Shared chart helpers

@ViewBuilder private func chartContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(alignment: .leading) {
        content()
            .frame(height: 180)
            .padding(.horizontal)
    }
    .padding(.vertical)
    .background(Color.chart.opacity(0.65))
    .clipShape(
        .rect(
            topLeadingRadius: 10,
            bottomLeadingRadius: 10,
            bottomTrailingRadius: 10,
            topTrailingRadius: 10
        )
    )
}

/// Reusable 24 h schedule chart used by the ISF / CR / Target draft editors.
/// Mirrors the visuals of the live editors: RectangleMark + top/bottom LineMark for
/// basal/ISF/CR; line-only for targets. Value transform allows mg/dL → mmol/L display.
struct TherapyScheduleChart: View {
    let items: [TherapySettingItem]
    let color: Color
    let lineOnly: Bool
    let valueTransform: (Decimal) -> Decimal

    @State private var now = Date()

    init(
        items: [TherapySettingItem],
        color: Color,
        lineOnly: Bool = false,
        valueTransform: @escaping (Decimal) -> Decimal = { $0 }
    ) {
        self.items = items
        self.color = color
        self.lineOnly = lineOnly
        self.valueTransform = valueTransform
    }

    var body: some View {
        Chart {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let displayValue = valueTransform(item.value)
                let start = Calendar.current.startOfDay(for: now).addingTimeInterval(item.time)
                let endOffset: TimeInterval = index + 1 < items.count ? items[index + 1].time : 86400
                let end = Calendar.current.startOfDay(for: now).addingTimeInterval(endOffset)

                if !lineOnly {
                    RectangleMark(
                        xStart: .value("start", start),
                        xEnd: .value("end", end),
                        yStart: .value("rate-start", displayValue),
                        yEnd: .value("rate-end", 0)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [color.opacity(0.6), color.opacity(0.1)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .alignsMarkStylesWithPlotArea()
                }

                LineMark(x: .value("start", start), y: .value("value", displayValue))
                    .lineStyle(.init(lineWidth: lineOnly ? 2.5 : 1))
                    .foregroundStyle(color)
                LineMark(x: .value("end", end), y: .value("value", displayValue))
                    .lineStyle(.init(lineWidth: lineOnly ? 2.5 : 1))
                    .foregroundStyle(color)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            }
        }
        .chartXScale(
            domain: Calendar.current.startOfDay(for: now) ... Calendar.current.startOfDay(for: now)
                .addingTimeInterval(60 * 60 * 24)
        )
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel()
                AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            }
        }
    }
}
