import SwiftUI

/// Stable world-space trajectories cross both sides of the bundle and its depth plane.
struct ThemeWeave: View {
    struct Span: Equatable {
        let start: Double
        let end: Double
        let key: String
        let ink: ThemePalette.Ink
        let emphasized: Bool
    }
    let spans: [Span]
    let origin: Double
    let width: Double
    let front: Bool
    let selectedKey: String?
    let progress: Double
    let hasFocus: Bool
    var height = 530.0
    var renderTime: Double?
    var synchronous = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: renderTime != nil || reduceMotion || scenePhase != .active)) { timeline in
            let time = renderTime ?? (reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate)
            Canvas(rendersAsynchronously: !synchronous) { context, _ in
                context.translateBy(x: -origin, y: 0)
                context.scaleBy(x: 1, y: height / 530)
                for span in spans where span.end >= origin && span.start <= origin + width {
                    let start = max(origin - 4, span.start)
                    let end = min(origin + width + 4, span.end)
                    let phase = ThemePalette.phase(for: span.key)
                    let selected = selectedKey == span.key
                    let prominence = selected ? 0.8 : ((selectedKey != nil || hasFocus) && !span.emphasized ? 0.12 : 0.4)
                    let release = selected ? 1 - progress : 1
                    for strand in 0..<2 {
                        func sample(_ x: Double) -> (Double, Double, Double) {
                            let u = (x - span.start) / max(1, span.end - span.start)
                            let envelope = pow(max(0, sin(.pi * u)), 0.8)
                            let angle = x / (93 + phase * 9) + phase + Double(strand) * 0.48 - time * 0.15
                            let radius = (19 + phase * 3 + Double(strand) * 3) * envelope
                            return (TimelineLayout.y(at: x) + sin(angle) * radius, cos(angle), envelope)
                        }
                        var path = Path()
                        for (i, x) in stride(from: start, through: end + 3, by: 3).enumerated() {
                            let x = min(x, end)
                            let point = CGPoint(x: x, y: sample(x).0)
                            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                        let stops = (0...48).map { i -> Gradient.Stop in
                            let fraction = Double(i) / 48
                            let x = start + (end - start) * fraction
                            let (_, depth, envelope) = sample(x)
                            let facing = ThreadGeometry.smooth((depth + 0.2) / 0.8)
                            let plane = front ? facing : (1 - facing) * 0.45
                            let pulse = SilkRenderer.travellingLight(x: x, strand: strand + 3, time: time)
                            let color = Color(red: 1 + (span.ink.red - 1) * envelope,
                                              green: 0.78 + (span.ink.green - 0.78) * envelope,
                                              blue: 0.40 + (span.ink.blue - 0.40) * envelope)
                            return .init(color: color.opacity(prominence * release * plane * (0.65 + pulse * 0.35)), location: fraction)
                        }
                        let ink = GraphicsContext.Shading.linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: start, y: 0), endPoint: CGPoint(x: max(start + 0.001, end), y: 0))
                        if front {
                            var glow = context
                            glow.addFilter(.blur(radius: 3))
                            glow.opacity = 0.18
                            glow.stroke(path, with: ink, lineWidth: 3)
                        }
                        context.stroke(path, with: ink, lineWidth: strand == 0 ? 0.65 : 0.4)
                    }
                }
            }
        }
        .frame(width: width, height: height).offset(x: origin)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
