import Foundation
import Observation
import QuartzCore
import UIKit

@MainActor
@Observable
final class ThreadMotion {
    private(set) var progress = 0.0
    private(set) var isDragging = false
    private(set) var target = 0.0
    private(set) var focusX: Double?
    private(set) var positions: [Double] = []
    private(set) var displacements: [Double] = []
    @ObservationIgnored private var nodeVelocities: [Double] = []
    @ObservationIgnored private var grabbedIndex: Int?
    static let releaseThreshold = 0.65
    static let overshootLimit = ThreadGeometry.overshootLimit
    @ObservationIgnored private var velocity = 0.0
    @ObservationIgnored private var dragOrigin: Double?
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var driver: ThreadDisplayDriver?
    @ObservationIgnored private let drivesDisplayLink: Bool

    init(drivesDisplayLink: Bool = true) { self.drivesDisplayLink = drivesDisplayLink }

    func configure(positions: [Double]) {
        guard self.positions != positions else { return }
        settle(expanded: false, immediately: true)
        self.positions = positions
        displacements = positions.map { _ in 0 }
        nodeVelocities = displacements
        grabbedIndex = nil
    }

    func drag(translation: Double, at x: Double? = nil, allowOvershoot: Bool = true) {
        if dragOrigin == nil {
            stop()
            dragOrigin = progress
            velocity = 0
            isDragging = true
            focusX = x
            grabbedIndex = x.flatMap { x in positions.indices.min { abs(positions[$0] - x) < abs(positions[$1] - x) } }
            // Rebase on the node under the finger, preserving every other node's live position.
            if let grabbedIndex { progress = displacements[grabbedIndex] }
            // Invert the rubber band when catching a stretched node so a zero-distance
            // re-grab starts exactly at its current visible height.
            let visibleExcess = max(0, progress - 1)
            if allowOvershoot && visibleExcess > 0 {
                let remaining = max(0.000001, Self.overshootLimit - visibleExcess)
                dragOrigin = 1 + Self.overshootLimit * visibleExcess / remaining
            } else {
                dragOrigin = progress
            }
        }
        let before = progress
        let requested = max(0, (dragOrigin ?? 0) - translation / ThreadGeometry.lift)
        let excess = max(0, requested - 1)
        progress = min(1, requested) + (allowOvershoot ? Self.overshootLimit * excess / (Self.overshootLimit + excess) : 0)
        if let grabbedIndex { displacements[grabbedIndex] = progress; nodeVelocities[grabbedIndex] = 0 }
        start()
        if (before < Self.releaseThreshold) != (progress < Self.releaseThreshold) {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    func endDrag(translation: Double, predicted: Double, reduceMotion: Bool) {
        let projection = progress - (predicted - translation) / 640
        velocity = min(5, max(-5, -(predicted - translation) / (0.18 * ThreadGeometry.lift)))
        dragOrigin = nil
        isDragging = false
        settle(expanded: projection > Self.releaseThreshold, immediately: reduceMotion)
    }

    func settle(expanded: Bool, immediately: Bool) {
        stop()
        dragOrigin = nil
        isDragging = false
        target = expanded ? 1 : 0
        if immediately {
            progress = target; velocity = 0
            displacements = positions.map { _ in target }
            nodeVelocities = positions.map { _ in 0 }
            if !expanded { focusX = nil }
            return
        }
        start()
    }

    private func start() {
        guard displayLink == nil else { return }
        guard drivesDisplayLink else { return }
        let driver = ThreadDisplayDriver(owner: self)
        let link = CADisplayLink(target: driver, selector: #selector(ThreadDisplayDriver.tick(_:)))
        let maximum = Float(UIScreen.main.maximumFramesPerSecond)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: min(60, maximum), maximum: maximum, preferred: maximum)
        self.driver = driver
        displayLink = link
        link.add(to: .main, forMode: .common)
    }

    func advance(by interval: Double) {
        // Fixed small substeps keep the coupled chain stable at both 60 and 120 Hz.
        let elapsed = min(0.1, max(0, interval))
        let steps = max(1, Int(ceil(elapsed * 240)))
        let dt = elapsed / Double(steps)
        for _ in 0..<steps {
            if !isDragging {
                velocity += (-190 * (progress - target) - 28 * velocity) * dt
                progress = min(1 + Self.overshootLimit, max(0, progress + velocity * dt))
            }
            let previous = displacements
            let released = ThreadGeometry.smooth((progress - Self.releaseThreshold) / (1 - Self.releaseThreshold))
            for i in positions.indices {
                if isDragging && i == grabbedIndex { continue }
                let value = previous[i]
                var force = 0.0
                // Only adjacent theme events exchange tension, independent of date spacing.
                if i > 0 { force += 180 * (previous[i - 1] - value) }
                if i + 1 < previous.count { force += 180 * (previous[i + 1] - value) }
                if isDragging {
                    force += -240 * (1 - released) * value + 220 * released * (progress - value)
                } else {
                    force += 190 * (progress - value)
                }
                nodeVelocities[i] += (force - 32 * nodeVelocities[i]) * dt
                displacements[i] = min(1 + Self.overshootLimit, max(0, value + nodeVelocities[i] * dt))
            }
        }
        let chainAtRest = displacements.indices.allSatisfy { abs(displacements[$0] - target) < 0.001 && abs(nodeVelocities[$0]) < 0.01 }
        if !isDragging && chainAtRest && abs(progress - target) < 0.001 && abs(velocity) < 0.01 {
            progress = target
            displacements = positions.map { _ in target }
            nodeVelocities = positions.map { _ in 0 }
            velocity = 0
            stop()
            if target == 0 { focusX = nil }
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        driver = nil
    }

    func suspend() {
        settle(expanded: target > 0.5, immediately: true)
    }
}

@MainActor
private final class ThreadDisplayDriver: NSObject {
    weak var owner: ThreadMotion?
    private var previousTimestamp: CFTimeInterval?
    init(owner: ThreadMotion) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) {
        // Use elapsed time between delivered callbacks, not the nominal display interval.
        // Rendering a complex weave may skip a refresh; physics must not slow down with it.
        let elapsed = previousTimestamp.map { link.timestamp - $0 } ?? (link.targetTimestamp - link.timestamp)
        previousTimestamp = link.timestamp
        owner?.advance(by: elapsed)
    }
}

enum ThreadGeometry {
    static let lift = 88.0
    static let joinLength = 290.0
    static let overshootLimit = 0.18

    /// Shape-preserving cubic interpolation: identical geometry for nodes and filament.
    static func sample(at x: Double, positions: [Double], values: [Double], fallback: Double) -> Double {
        guard positions.count == values.count, let first = positions.first, let last = positions.last else { return fallback }
        if x <= first { return values[0] }
        if x >= last { return values[values.count - 1] }
        var low = 0
        var high = positions.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if positions[mid] <= x { low = mid } else { high = mid }
        }
        func secant(_ i: Int) -> Double { (values[i + 1] - values[i]) / max(1, positions[i + 1] - positions[i]) }
        func slope(_ i: Int) -> Double {
            guard i > 0, i < positions.count - 1 else { return 0 }
            let a = secant(i - 1), b = secant(i)
            guard a * b > 0 else { return 0 }
            return 2 * a * b / (a + b)
        }
        let length = positions[high] - positions[low]
        let t = (x - positions[low]) / length
        let t2 = t * t, t3 = t2 * t
        return min(1 + overshootLimit, max(0, (2*t3 - 3*t2 + 1) * values[low] + (t3 - 2*t2 + t) * length * slope(low)
                         + (-2*t3 + 3*t2) * values[high] + (t3 - t2) * length * slope(high)))
    }

    static func smooth(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    /// Neighbour distance follows the theme's event order, even across long date gaps.
    static func influence(at x: Double, progress: Double, positions: [Double], focus: Double?) -> Double {
        let p = min(1, max(0, progress))
        guard let focus, !positions.isEmpty else { return p }
        func ordinal(_ value: Double) -> Double {
            guard let first = positions.first, let last = positions.last else { return 0 }
            if value <= first { return 0 }
            if value >= last { return Double(positions.count - 1) }
            // Binary search keeps sampling long threads inexpensive.
            var low = 0
            var high = positions.count - 1
            while high - low > 1 {
                let mid = (low + high) / 2
                if positions[mid] <= value { low = mid } else { high = mid }
            }
            return Double(low) + (value - positions[low]) / max(1, positions[high] - positions[low])
        }
        let distance = abs(ordinal(x) - ordinal(focus))
        let local = p * smooth((p - distance * 0.16) / max(0.001, p))
        let released = smooth((p - 0.65) / 0.35)
        return local * (1 - released) + p * released
    }

    static func y(at x: Double, progress: Double, positions: [Double] = [], focus: Double? = nil,
                  bounds: ClosedRange<Double>? = nil, displacements: [Double] = [], additionalLift: Double = 0, direction: Double = 1) -> Double {
        var strength = sample(at: x, positions: positions, values: displacements,
                              fallback: influence(at: x, progress: progress, positions: positions, focus: focus))
        if let bounds {
            let fade = min(joinLength, (bounds.upperBound - bounds.lowerBound) / 2)
            if fade > 0 {
                strength *= smooth((x - bounds.lowerBound) / fade) * smooth((bounds.upperBound - x) / fade)
            }
        }
        return TimelineLayout.y(at: x) - (lift + max(0, additionalLift)) * strength * direction
    }
}
