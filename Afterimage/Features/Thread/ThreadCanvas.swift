import SwiftUI

struct ThreadCanvas: View {
    let width: Double
    let range: ClosedRange<Double>?
    let progress: Double
    var positions: [Double] = []
    var displacements: [Double] = []
    var focus: Double?
    var visibleRange: ClosedRange<Double>?
    var themeInk = ThemePalette.ink(0)
    var height = 530.0
    var additionalLift = 0.0
    var liftDirection = 1.0
    var renderTime: Double?
    var synchronous = false
    @Environment(\.afterimageReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: renderTime != nil || reduceMotion || scenePhase != .active || (displacements.max() ?? progress) < 0.001)) { timeline in
            let time = renderTime ?? (reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate)
            Canvas(rendersAsynchronously: !synchronous) { context, _ in
                guard let range else { return }
                let visibility = min(1, (displacements.max() ?? progress) * 5)
                guard visibility > 0.001 else { return }
                let start = range.lowerBound - ThreadGeometry.joinLength
                let end = range.upperBound + ThreadGeometry.joinLength
                let bounds = start...end
                let origin = visibleRange?.lowerBound ?? 0
                let visibleStart = max(start, visibleRange?.lowerBound ?? start)
                let visibleEnd = min(end, visibleRange?.upperBound ?? end)
                guard visibleStart <= visibleEnd else { return }
                context.translateBy(x: -origin, y: 0)
                context.scaleBy(x: 1, y: height / 530)
                context.opacity = visibility

                func centre(_ x: Double) -> Double {
                    ThreadGeometry.y(at: x, progress: progress, positions: positions, focus: focus,
                                     bounds: bounds, displacements: displacements, additionalLift: additionalLift, direction: liftDirection)
                }
                func strength(_ x: Double) -> Double {
                    abs(TimelineLayout.y(at: x) - centre(x)) / ThreadGeometry.lift
                }
                func ink(strand: Int, core: Bool = false) -> GraphicsContext.Shading {
                    let stops = (0...96).map { index -> Gradient.Stop in
                        let fraction = Double(index) / 96
                        let x = visibleStart + (visibleEnd - visibleStart) * fraction
                        let released = strength(x)
                        let mint = ThreadGeometry.smooth(released / 0.8)
                        let pulse = SilkRenderer.travellingLight(x: x, strand: strand, time: time)
                        let edge = ThreadGeometry.smooth(min(x - start, end - x) / 55)
                        let alpha = core ? ThreadGeometry.smooth(released / 0.22) : 0.7
                        let light = pulse * 0.2
                        let color = Color(red: min(1, 1 + mint * (themeInk.red - 1) + light),
                                          green: min(1, 0.78 + mint * (themeInk.green - 0.78) + light),
                                          blue: min(1, 0.40 + mint * (themeInk.blue - 0.40) + light))
                        return .init(color: color.opacity(edge * alpha * (0.65 + pulse * 0.35)), location: fraction)
                    }
                    return .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: visibleStart, y: 0),
                                           endPoint: CGPoint(x: max(visibleStart + 0.001, visibleEnd), y: 0))
                }

                var path = Path()
                for (index, x) in stride(from: visibleStart, through: visibleEnd + 3, by: 3).enumerated() {
                    let x = min(x, visibleEnd)
                    let point = CGPoint(x: x, y: centre(x))
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                let coreInk = ink(strand: 2, core: true)
                var glow = context
                glow.opacity = 0.16
                glow.addFilter(.blur(radius: 9))
                glow.stroke(path, with: coreInk, lineWidth: 8)

                for strand in 0..<3 {
                    var fibre = Path()
                    var nodeIndex = 0
                    let sourceStrand = 2 + strand * 3
                    for (index, x) in stride(from: visibleStart, through: visibleEnd + 3, by: 3).enumerated() {
                        let x = min(x, visibleEnd)
                        while nodeIndex + 1 < positions.count && positions[nodeIndex + 1] < x { nodeIndex += 1 }
                        let left = positions.isEmpty ? 100 : abs(x - positions[nodeIndex])
                        let right = nodeIndex + 1 < positions.count ? abs(x - positions[nodeIndex + 1]) : left
                        let y = centre(x)
                        let released = strength(x)
                        let blend = ThreadGeometry.smooth(released / 0.65)
                        // Begin on the actual source fibre, then peel into the lifted bundle.
                        let source = SilkRenderer.point(x: x, strand: sourceStrand, time: time, tension: progress).y - TimelineLayout.y(at: x)
                        let envelope = 0.45 + 0.55 * ThreadGeometry.smooth(min(left, right) / 42)
                        let phase = x / (47 + Double(strand) * 13) - time * 0.19 + Double(strand) * 2.39996
                            + sin(x / 137 + Double(strand)) * 0.28
                        let orbit = sin(phase) * (2.4 + Double(strand) * 1.3) * envelope
                        let point = CGPoint(x: x, y: y + source * (1 - blend) + orbit * blend)
                        if index == 0 { fibre.move(to: point) } else { fibre.addLine(to: point) }
                    }
                    let fibreInk = ink(strand: sourceStrand)
                    var halo = context
                    halo.opacity = 0.15
                    halo.addFilter(.blur(radius: 2.5))
                    halo.stroke(fibre, with: fibreInk, lineWidth: 3)
                    context.stroke(fibre, with: fibreInk, style: StrokeStyle(lineWidth: 0.55, lineCap: .round, lineJoin: .round))
                }
                var nearGlow = context
                nearGlow.opacity = 0.24
                nearGlow.addFilter(.blur(radius: 2))
                nearGlow.stroke(path, with: coreInk, lineWidth: 2.4)
                context.stroke(path, with: coreInk, lineWidth: 0.65)
            }
        }
        .frame(width: visibleRange.map { $0.upperBound - $0.lowerBound } ?? width, height: height)
        .offset(x: visibleRange?.lowerBound ?? 0)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
