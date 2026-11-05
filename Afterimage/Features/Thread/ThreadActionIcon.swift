import SwiftUI

/// Two strands and a directional tip: lift away from the bundle, or return to it.
struct ThreadActionIcon: View {
    var returning: Bool
    @Environment(\.legibilityWeight) private var legibilityWeight
    var body: some View {
        ThreadActionShape(returning: returning)
            .stroke(style: StrokeStyle(lineWidth: legibilityWeight == .bold ? 2.2 : 1.55, lineCap: .round, lineJoin: .round))
            .frame(width: 24, height: 24).accessibilityHidden(true)
    }
}

private struct ThreadActionShape: Shape {
    var returning: Bool
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x / 24 * rect.width, y: rect.minY + y / 24 * rect.height) }
        var path = Path()
        path.move(to: point(2.5, 20))
        path.addCurve(to: point(22, 20), control1: point(8, 23), control2: point(14, 16.5))
        if returning {
            path.move(to: point(3, 6))
            path.addCurve(to: point(20, 15), control1: point(10, 4.5), control2: point(15, 7))
            path.move(to: point(15, 13))
            path.addLine(to: point(20, 15))
            path.addLine(to: point(21, 10))
        } else {
            path.move(to: point(3, 12))
            path.addCurve(to: point(21, 5), control1: point(9, 15), control2: point(16, 12))
            path.move(to: point(16, 5.5))
            path.addLine(to: point(21, 5))
            path.addLine(to: point(21, 10))
        }
        return path
    }
}
