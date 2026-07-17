import SwiftUI

struct DownArrowBarShape: Shape {
    var arrowHeight: CGFloat = MainChartHelper.Config.barArrowHeight

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bodyMaxY = max(rect.minY, rect.maxY - arrowHeight)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: bodyMaxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: bodyMaxY))
        path.closeSubpath()
        return path
    }
}

struct UpArrowBarShape: Shape {
    var arrowHeight: CGFloat = MainChartHelper.Config.barArrowHeight

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bodyMinY = min(rect.maxY, rect.minY + arrowHeight)
        path.move(to: CGPoint(x: rect.minX, y: bodyMinY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: bodyMinY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
