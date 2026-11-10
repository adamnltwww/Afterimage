import SwiftUI
import UIKit
import Observation

/// One clock for decorative canvases. Interaction physics keeps its own full-rate clock.
@Observable final class DecorativeMotion: NSObject {
    var time = Date.timeIntervalSinceReferenceDate
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastFrame = 0.0
    private(set) var visible = false

    func setVisible(_ value: Bool) {
        visible = value
        if value { wake() } else { stop() }
    }
    func wake() {
        guard visible else { return }
        guard link == nil else { return }
        let driver = DecorativeMotionDriver(owner: self)
        let display = CADisplayLink(target: driver, selector: #selector(DecorativeMotionDriver.tick(_:)))
        display.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
        link = display
        lastFrame = 0
        display.add(to: .main, forMode: .common)
    }
    fileprivate func advance(_ display: CADisplayLink) {
        let now = display.timestamp
        let elapsed = lastFrame == 0 ? 0 : min(0.15, max(0, now - lastFrame))
        lastFrame = now
        guard visible else { stop(); return }
        time += elapsed
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
