import Foundation

/// A bounded, monotonic time axis. Short gaps expand for touch targets; long gaps compress.
struct TimelineLayout {
    // Leave the full 290-point return curve visible beyond the first and last nodes.
    static let edgePadding = ThreadGeometry.joinLength - 130 + 24
    let positions: [Double]
    let width: Double

    init(dates: [Date], viewport: Double, leadingInset: Double? = nil) {
        var positions: [Double] = []
        var x = leadingInset ?? (130.0 + Self.edgePadding)
        for index in dates.indices {
            if index > 0 {
                let days = max(0, dates[index].timeIntervalSince(dates[index - 1]) / 86_400)
                x += 190 + min(250, sqrt(days) * 22)
            }
            positions.append(x)
        }
        self.positions = positions
        width = max(viewport, x + 130 + Self.edgePadding)
    }

    static func y(at x: Double) -> Double { 260 + sin(x / 240) * 12 }

    func browsingProgress(at offset: Double, viewport: Double) -> Double {
        let span = width - viewport
        guard span > 1 else { return 1 }
        // The scroll observer coalesces subpixel updates; snap the last point at each end.
        if offset <= 1 { return 0 }
        if offset >= span - 1 { return 1 }
        return offset / span
    }
}
