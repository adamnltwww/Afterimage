import SwiftUI

/// The axis is a bundle of fibres travelling around a stable centre, not a stack of offset lines.
struct SilkAxis: View {
    let origin: Double
    let width: Double
    var tension = 0.0
    var threadPositions: [Double] = []
    var threadDisplacements: [Double] = []
    var threadFocus: Double?
    var height = 530.0
    var lightSamples = 96
    var renderTime: Double?
    var synchronous = false
    var crossSectionScale = 1.0
    var openingAmount = 0.0
    var openingCenter = 0.0
    var openingWidth = 402.0
    var openingAge = 10.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: renderTime != nil || reduceMotion || scenePhase != .active)) { timeline in
            let time = renderTime ?? (reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate)
            Canvas(rendersAsynchronously: !synchronous) { context, _ in
                context.translateBy(x: -origin, y: 0)
                context.scaleBy(x: 1, y: height / 530)
                SilkRenderer.draw(in: context, origin: origin, width: width, time: time, tension: tension,
                                  positions: threadPositions, displacements: threadDisplacements, focus: threadFocus,
                                  crossSectionScale: crossSectionScale, lightSamples: lightSamples,
                                  openingAmount: openingAmount, openingCenter: openingCenter, openingWidth: openingWidth, openingAge: openingAge)
            }
        }
        .frame(width: width, height: height)
        .offset(x: origin)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

enum SilkRenderer {
    private struct Fibre {
        var whole = Path()
        var light: GraphicsContext.Shading
        var frontLight: GraphicsContext.Shading
        var thickness: Double
    }

    /// Phase is world-anchored, so scrolling cannot restart or stretch the weave.
    static func point(x: Double, strand: Int, time: Double, tension: Double) -> (y: Double, depth: Double) {
        let seed = Double(strand) * 2.39996
        let phase = x / (71 + Double(strand % 4) * 17) - time * 0.208 + seed
            + sin(x / 163 + seed * 0.7) * 0.38 + sin(x / 57 - seed) * 0.14
        let breath = 0.5 + 0.5 * sin(x / 237 + seed * 0.4 + time * 0.045)
        let radius = strand < 8 ? 1.5 + breath * 4.5 : (strand < 15 ? 5 + breath * 13 : 13 + breath * 15)
        let detail = sin(x / 39 + seed + time * 0.07) * (strand < 8 ? 0.5 : 1.2)
            + sin(x / 13 + seed * 2 - time * 0.09) * 0.16
        let gathering = 0.64 + 0.36 * pow(0.5 + 0.5 * sin(x / 193 - time * 0.045), 2)
        let y = TimelineLayout.y(at: x) + (sin(phase) * radius * gathering + detail) * 1.4 * (1 - tension * 0.28)
        return (y, cos(phase))
    }

    static func travellingLight(x: Double, strand: Int, time: Double) -> Double {
        let seed = Double(strand) * 2.39996
        let travel = x - time * (22 + Double(strand % 3) * 3)
        let wave = 0.5 + 0.5 * sin(travel / (83 + Double(strand % 4) * 19) + seed + sin(travel / 179 + seed) * 0.7)
        return pow(wave, 14) * (0.3 + 0.7 * pow(0.5 + 0.5 * sin(time * 0.09 + seed), 2))
    }

    /// Wide independent branches spiral into the bundle, with the centre gathering first.
    /// Zero returns the normal renderer sample exactly, without changing canvas or phase.
    static func openingPoint(x: Double, strand: Int, time: Double, tension: Double,
                             amount: Double, center: Double, viewport: Double) -> (y: Double, depth: Double) {
        let settled = point(x: x, strand: strand, time: time, tension: tension)
        guard amount > 0 else { return settled }
        let seed = Double(strand) * 2.39996
        let u = (x - center) / max(240, viewport)
        let edge = min(1, abs(u) * 2)
        // A tension wave travels from the waist to the tips; fibres follow with
        // a slight lag, carrying their curves sideways as well as inward.
        let delay = edge * 0.22 + Double(strand % 5) * 0.025
        let progress = min(1, max(0, (1 - amount - delay) / (1 - delay)))
        let release = progress * progress * progress * (progress * (progress * 6 - 15) + 10)
        let envelope = 1 - release
        let group = Double(strand % 3) - 1
        let flow = sin(time * 0.65 + group * 0.5) * 0.025
        let advection = sin(.pi * progress) * 0.12 * sin(seed)
        let q = u + flow + advection
        // Three legible sweeping streams, each made of close, breathing fibres.
        let branch = -195 * sin(q * 2.8) + group * 72 * cos(q * 3.1 + time * 0.18)
        let curl = q * 7 + seed + release * 2.1 + time * 0.48
        let orbit = sin(curl) * (5 + Double(strand / 3) * 1.6) * exp(-u * u * 3)
            * (0.65 + 0.55 * sin(.pi * progress))
        return (settled.y + (orbit + branch) * envelope,
                settled.depth * (1 - envelope) + cos(curl) * envelope)
    }

    static func draw(in original: GraphicsContext, origin: Double, width: Double, time: Double, tension: Double,
                     positions: [Double], displacements: [Double], focus: Double?, crossSectionScale: Double = 1, lightSamples: Int = 96,
                     openingAmount: Double = 0, openingCenter: Double = 0, openingWidth: Double = 402, openingAge: Double = 10) {
        let start = origin - 24
        let end = origin + width + 24
        var fibres: [Fibre] = []
        for strand in 0..<17 {
            let leading = [0, 5, 11].contains(strand)
            var whole = Path()
            for (index, x) in stride(from: start, through: end, by: 3).enumerated() {
                let sample = openingPoint(x: x, strand: strand, time: time, tension: tension,
                                          amount: openingAmount, center: openingCenter, viewport: openingWidth)
                let base = TimelineLayout.y(at: x)
                let current = CGPoint(x: x, y: base + (sample.y - base) * crossSectionScale)
                if index == 0 { whole.move(to: current) } else { whole.addLine(to: current) }
            }
            var stops: [Gradient.Stop] = []
            var frontStops: [Gradient.Stop] = []
            let samples = max(8, lightSamples)
            for index in 0...samples {
                let fraction = Double(index) / Double(samples)
                let x = start + (end - start) * fraction
                let depth = (openingPoint(x: x, strand: strand, time: time, tension: tension,
                                         amount: openingAmount, center: openingCenter, viewport: openingWidth).depth + 1) / 2
                let pulse = travellingLight(x: x, strand: strand, time: time)
                var remaining = 1.0
                if [2, 5, 8].contains(strand), let first = positions.first, let last = positions.last {
                    let y = ThreadGeometry.y(at: x, progress: tension, positions: positions, focus: focus,
                                             bounds: (first - ThreadGeometry.joinLength)...(last + ThreadGeometry.joinLength), displacements: displacements)
                    let release = abs(TimelineLayout.y(at: x) - y) / ThreadGeometry.lift
                    remaining = 1 - ThreadGeometry.smooth(release / 0.35)
                }
                let exposure = 1 + openingAmount * (leading ? 0.18 : -0.22)
                let across = min(1, max(0, (x - openingCenter) / max(240, openingWidth) + 0.5))
                let arrival = ThreadGeometry.smooth((openingAge - Double(strand % 3) * 0.14 - across * 0.32) / 0.5)
                let entrance = 1 - openingAmount * (1 - arrival)
                let light = min(0.98, (0.16 + depth * 0.48 + pulse * 0.48) * exposure) * remaining * entrance
                let color = Color(red: 1, green: min(0.97, 0.63 + depth * 0.23 + pulse * 0.16), blue: min(0.88, 0.30 + depth * 0.35 + pulse * 0.24))
                stops.append(.init(color: color.opacity(light), location: fraction))
                // Front highlights fade in from the depth plane instead of exposing cut ends.
                let facing = ThreadGeometry.smooth((depth - 0.5) * 3)
                frontStops.append(.init(color: color.opacity(light * facing), location: fraction))
            }
            let ink = GraphicsContext.Shading.linearGradient(Gradient(stops: stops),
                startPoint: CGPoint(x: start, y: 0), endPoint: CGPoint(x: end, y: 0))
            let frontInk = GraphicsContext.Shading.linearGradient(Gradient(stops: frontStops),
                startPoint: CGPoint(x: start, y: 0), endPoint: CGPoint(x: end, y: 0))
            fibres.append(Fibre(whole: whole, light: ink,
                                frontLight: frontInk, thickness: (strand < 8 ? 0.75 : (strand < 15 ? 0.55 : 0.35))
                                    * (1 + openingAmount * (leading ? 0.65 : -0.12))))
        }

        var centre = Path()
        for (index, x) in stride(from: start, through: end, by: 3).enumerated() {
            let p = CGPoint(x: x, y: TimelineLayout.y(at: x))
            if index == 0 { centre.move(to: p) } else { centre.addLine(to: p) }
        }
        // Spacious low-luminance atmosphere, then the fibres behind the central bundle.
        var atmosphere = original
        atmosphere.addFilter(.blur(radius: 19))
        atmosphere.stroke(centre, with: .color(AfterimageStyle.amber.opacity(0.10 * pow(1 - openingAmount, 2))), lineWidth: 18)
        for fibre in fibres {
            var far = original
            far.addFilter(.blur(radius: 0.7))
            far.opacity = 0.45
            far.stroke(fibre.whole, with: fibre.light, lineWidth: fibre.thickness)
            var halo = original
            halo.addFilter(.blur(radius: 3.5))
            halo.opacity = 0.17
            halo.stroke(fibre.whole, with: fibre.light, lineWidth: 3.5)
        }

        // A narrow opaque waist occludes the rear fibres where they pass behind the axis.
        let corePresence = min(1, max(0.3, 1 - (crossSectionScale - 1) * 0.35)) * pow(1 - openingAmount, 2)
        original.stroke(centre, with: .color(AfterimageStyle.background.opacity(0.72 * corePresence)), lineWidth: 3)
        var coreGlow = original
        coreGlow.addFilter(.blur(radius: 3))
        coreGlow.stroke(centre, with: .color(AfterimageStyle.amber.opacity(0.28 * corePresence)), lineWidth: 4)
        original.stroke(centre, with: .color(Color(red: 1, green: 0.87, blue: 0.62).opacity(0.63 * corePresence)), lineWidth: 0.65)
        for fibre in fibres {
            original.stroke(fibre.whole, with: fibre.frontLight,
                            style: StrokeStyle(lineWidth: fibre.thickness, lineCap: .round, lineJoin: .round))
        }
    }
}

struct AfterimageWordmark: View {
    var progress: Double
    var body: some View {
        Text("AFTERIMAGE")
            .font(.system(size: 14, weight: .medium, design: .rounded)).tracking(3.4)
            .foregroundStyle(AfterimageStyle.amber.opacity(0.25))
            .overlay {
                GeometryReader { geometry in
                    let location = min(1, max(0, progress))
                    ZStack(alignment: .leading) {
                        AfterimageStyle.amber.opacity(0.65)
                            .frame(width: geometry.size.width * location)
                        Ellipse().fill(Color(red: 1, green: 0.91, blue: 0.73))
                            .frame(width: 38, height: 24).blur(radius: 7)
                            .offset(x: geometry.size.width * location - 19)
                    }
                }
                .mask(Text("AFTERIMAGE").font(.system(size: 14, weight: .medium, design: .rounded)).tracking(3.4))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("AFTERIMAGE，时间线浏览位置")
            .accessibilityValue("\(Int(min(1, max(0, progress)) * 100))%")
            .accessibilityIdentifier("timeline.progress")
    }
}
