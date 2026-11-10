import SwiftUI
import UIKit
import Observation

/// One clock for decorative canvases. Interaction physics keeps its own full-rate clock.
@Observable final class DecorativeMotion: NSObject {
    var time = Date.timeIntervalSinceReferenceDate
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastFrame = 0.0
    @ObservationIgnored private var awakeUntil = 0.0
    @ObservationIgnored private var idle = false
    @ObservationIgnored private var motionRate = 1.0
    private(set) var visible = false

    func setVisible(_ value: Bool) {
        visible = value
        if value { wake() } else { stop() }
    }
    func wake() {
        guard visible else { return }
        awakeUntil = CACurrentMediaTime() + 3
        if idle {
            idle = false
            link?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        }
        guard link == nil else { return }
        let driver = DecorativeMotionDriver(owner: self)
        let display = CADisplayLink(target: driver, selector: #selector(DecorativeMotionDriver.tick(_:)))
        display.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        link = display
        lastFrame = 0
        display.add(to: .main, forMode: .common)
    }
    fileprivate func advance(_ display: CADisplayLink) {
        let now = display.timestamp
        let elapsed = lastFrame == 0 ? 0 : min(0.15, max(0, now - lastFrame))
        lastFrame = now
        let remaining = awakeUntil - now
        guard visible else { stop(); return }
        let blend = min(1, max(0, remaining))
        let targetRate = 0.35 + 0.65 * blend * blend * (3 - 2 * blend)
        // Keep phase continuous and ease into both interaction and idle speeds.
        motionRate += (targetRate - motionRate) * (1 - exp(-elapsed * 8))
        time += elapsed * motionRate
        if remaining <= 0 && !idle {
            idle = true
            display.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 15, preferred: 15)
        }
    }
    func stop() { link?.invalidate(); link = nil; lastFrame = 0 }
    deinit { link?.invalidate() }
}

private final class DecorativeMotionDriver: NSObject {
    weak var owner: DecorativeMotion?
    init(owner: DecorativeMotion) { self.owner = owner }
    @objc func tick(_ display: CADisplayLink) { owner?.advance(display) }
}

private struct DecorativeMotionKey: EnvironmentKey { static let defaultValue: DecorativeMotion? = nil }
extension EnvironmentValues {
    var decorativeMotion: DecorativeMotion? {
        get { self[DecorativeMotionKey.self] }
        set { self[DecorativeMotionKey.self] = newValue }
    }
}
