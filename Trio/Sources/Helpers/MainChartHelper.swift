import Charts
import CoreData
import Foundation
import SwiftUI

enum MainChartHelper {
    // Calculates the glucose value thats the nearest to parameter 'time'
    /// -Returns: A NSManagedObject of GlucoseStored
    /// it is thread safe as everything is executed on the main thread
    static func timeToNearestGlucose(glucoseValues: [GlucoseStored], time: TimeInterval) -> GlucoseStored? {
        guard !glucoseValues.isEmpty else {
            return nil
        }

        var low = 0
        var high = glucoseValues.count - 1
        var closestGlucose: GlucoseStored?

        // binary search to find next glucose
        while low <= high {
            let mid = low + (high - low) / 2
            let midTime = glucoseValues[mid].date?.timeIntervalSince1970 ?? 0

            if midTime == time {
                return glucoseValues[mid]
            } else if midTime < time {
                low = mid + 1
            } else {
                high = mid - 1
            }

            // update if necessary
            if closestGlucose == nil || abs(midTime - time) < abs(closestGlucose!.date?.timeIntervalSince1970 ?? 0 - time) {
                closestGlucose = glucoseValues[mid]
            }
        }

        return closestGlucose
    }

    enum Config {
        static let bolusSize: CGFloat = 5
        static let bolusScale: CGFloat = 6
        static let carbsSize: CGFloat = 5
        static let maxCarbSize: CGFloat = 30
        static let carbsScale: CGFloat = 3
        static let fpuSize: CGFloat = 10
        static let maxGlucose = 270
        static let minGlucose = 45

        /// Max widths for carb (5) and FPU (3) bars.
        static let carbBarWidth: CGFloat = 5
        static let fpuBarWidth: CGFloat = 3
        /// Arrow tip length at the bar's pointed end.
        static let barArrowHeight: CGFloat = 5

        /// Max bar body height for bolus and carb bars.
        static let bolusBarMaxHeight: CGFloat = 45
        static let carbBarMaxHeight: CGFloat = 45

        /// Pixel gap between the bar's arrow tip and the BG curve.
        static let bolusAnnotationSpacing: CGFloat = 15
        static let carbAnnotationSpacing: CGFloat = 15

        /// Doses below this amount render with a narrower bar (SMB-class).
        static let smbWidthThreshold: Decimal = 0.3

        /// Bolus bar height = `(amount / maxAmount) ^ bolusHeightExponent * maxHeight`.
        /// `1.0` = linear, `0.5` = sqrt. Lower → small SMBs grow and big bars stay capped.
        static let bolusHeightExponent: Double = 0.6
    }

    /// Bar width: piecewise on `screenHours`, narrower for SMB-class doses. Tightens with
    /// longer time windows to keep clustered SMBs from overlapping.
    static func bolusBarWidth(amount: Decimal, minimumSMB: Decimal, screenHours: Int16) -> CGFloat {
        let isSmall = amount < minimumSMB
        switch screenHours {
        case ...6:
            return isSmall ? 2.5 : 3
        case 7 ... 18:
            return isSmall ? 2 : 2.5
        default: // 19…24
            return isSmall ? 1.5 : 2
        }
    }

    /// Carb bar width — same shape as bolus, clamped to `Config.carbBarWidth`.
    static func carbBarWidth(amount: Decimal, minimumSMB: Decimal, screenHours: Int16) -> CGFloat {
        min(bolusBarWidth(amount: amount, minimumSMB: minimumSMB, screenHours: screenHours), Config.carbBarWidth)
    }

    /// FPU bar width — same shape as bolus, clamped to `Config.fpuBarWidth`.
    static func fpuBarWidth(amount: Decimal, minimumSMB: Decimal, screenHours: Int16) -> CGFloat {
        min(bolusBarWidth(amount: amount, minimumSMB: minimumSMB, screenHours: screenHours), Config.fpuBarWidth)
    }

    /// Bolus bar height with power-law compression — see `Config.bolusHeightExponent`
    /// for the rationale on the exponent value (sqrt-ish to compress the dynamic range).
    static func bolusBarHeight(amount: Decimal, maxAmount: Decimal) -> CGFloat {
        let amountValue = CGFloat(truncating: amount as NSNumber)
        let maxValue = max(CGFloat(truncating: maxAmount as NSNumber), 0.001)
        let normalized = max(0, min(1, amountValue / maxValue))
        return CGFloat(pow(Double(normalized), Config.bolusHeightExponent)) * Config.bolusBarMaxHeight
    }

    /// Linear carb bar height — `(amount / maxAmount) * carbBarMaxHeight`.
    static func carbBarHeight(amount: Decimal, maxAmount: Decimal) -> CGFloat {
        let amountValue = CGFloat(truncating: amount as NSNumber)
        let maxValue = max(CGFloat(truncating: maxAmount as NSNumber), 0.001)
        return (amountValue / maxValue) * Config.carbBarMaxHeight
    }

    static func bolusOffset(units: GlucoseUnits) -> Decimal {
        units == .mgdL ? 20 : (20 / 18)
    }

    static func calculateDuration(
        objectID: NSManagedObjectID,
        attribute: String,
        context: NSManagedObjectContext
    ) -> TimeInterval? {
        do {
            let object = try context.existingObject(with: objectID)
            if let attributeValue = object.value(forKey: attribute) as? NSDecimalNumber {
                let doubleValue = attributeValue.doubleValue
                if doubleValue != 0 {
                    return TimeInterval(doubleValue * 60) // return seconds
                }
            } else {
                debugPrint("Attribute \(attribute) not found or not of type NSDecimalNumber")
            }
        } catch {
            debugPrint(
                "\(DebuggingIdentifiers.failed) \(#file) \(#function) Failed to calculate duration for object with error: \(error)"
            )
        }

        return nil
    }

    static func calculateTarget(objectID: NSManagedObjectID, attribute: String, context: NSManagedObjectContext) -> Decimal? {
        do {
            let object = try context.existingObject(with: objectID)
            if let attributeValue = object.value(forKey: attribute) as? NSDecimalNumber, attributeValue != 0 {
                return attributeValue.decimalValue
            }
        } catch {
            debugPrint(
                "\(DebuggingIdentifiers.failed) \(#file) \(#function) Failed to calculate target for object with error: \(error)"
            )
        }
        return nil
    }
}

// MARK: - Rule Marks and Charts configurations

extension MainChartView {
    func drawCurrentTimeMarker() -> some ChartContent {
        RuleMark(
            x: .value(
                "",
                Date(timeIntervalSince1970: TimeInterval(NSDate().timeIntervalSince1970)),
                unit: .second
            )
        ).lineStyle(.init(lineWidth: 2, dash: [3])).foregroundStyle(Color(.systemGray2))
    }

    func drawStartRuleMark() -> some ChartContent {
        RuleMark(
            x: .value(
                "",
                state.startMarker,
                unit: .second
            )
        ).foregroundStyle(Color.clear)
    }

    func drawEndRuleMark() -> some ChartContent {
        RuleMark(
            x: .value(
                "",
                state.endMarker,
                unit: .second
            )
        ).foregroundStyle(Color.clear)
    }

    func basalChartPlotStyle(_ plotContent: ChartPlotContent) -> some View {
        plotContent
            .rotationEffect(.degrees(180))
            .scaleEffect(x: -1, y: 1)
    }

    var mainChartXAxis: some AxisContent {
        AxisMarks(values: .stride(by: .hour, count: screenHours > 6 ? (screenHours > 12 ? 4 : 2) : 1)) { _ in
            if displayXgridLines {
                AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2, 3]))
            } else {
                AxisGridLine(stroke: .init(lineWidth: 0, dash: [2, 3]))
            }
        }
    }

    var hiddenChartXAxis: some AxisContent {
        AxisMarks(values: .stride(by: .hour, count: screenHours > 6 ? (screenHours > 12 ? 4 : 2) : 1)) { _ in
            AxisGridLine(stroke: .init(lineWidth: 0, dash: [2, 3]))
            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .narrow)), anchor: .top)
                .font(.footnote).foregroundStyle(Color.clear)
        }
    }

    var dummyChartXAxis: some AxisContent {
        AxisMarks(values: .stride(by: .hour, count: screenHours > 6 ? (screenHours > 12 ? 4 : 2) : 1)) { _ in
            AxisGridLine(stroke: .init(lineWidth: 0, dash: [2, 3]))
        }
    }

    var basalChartXAxis: some AxisContent {
        AxisMarks(values: .stride(by: .hour, count: screenHours > 6 ? (screenHours > 12 ? 4 : 2) : 1)) { _ in
            if displayXgridLines {
                AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2, 3]))
            } else {
                AxisGridLine(stroke: .init(lineWidth: 0, dash: [2, 3]))
            }
            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .narrow)), anchor: .top)
                .font(.footnote).foregroundStyle(Color.primary)
        }
    }

    var mainChartYAxis: some AxisContent {
        AxisMarks(
            position: .trailing,
            values: stride(
                from: units == .mgdL ? 75 : 4,
                through: units == .mgdL ? state.maxYAxisValue : state.maxYAxisValue.asMmolL,
                by: units == .mgdL ? 50 : 3
            ).map { $0 }
        ) { value in
            if displayYgridLines {
                AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2, 3]))
            } else {
                AxisGridLine(stroke: .init(lineWidth: 0, dash: [2, 3]))
            }

            if let glucoseValue = value.as(Double.self), glucoseValue > 0 {
                /// fix offset between the two charts...
                if units == .mmolL {
                    AxisTick(length: 7, stroke: .init(lineWidth: 7)).foregroundStyle(Color.clear)
                }
                AxisValueLabel().font(.footnote).foregroundStyle(Color.primary)
            }
        }
    }

    var cobIobChartYAxis: some AxisContent {
        AxisMarks(position: .trailing) { _ in
            if displayYgridLines {
                AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2, 3]))
            } else {
                AxisGridLine(stroke: .init(lineWidth: 0, dash: [2, 3]))
            }
        }
    }

    func fullWidth(viewWidth: CGFloat) -> CGFloat {
        viewWidth * CGFloat(hours) / CGFloat(min(max(screenHours, 2), 24))
    }
}
