import SwiftUI
import UIKit

@Observable final class TimelineScrubActivity { var active = false }

struct TimelineScrubDate: View {
    let progress: TimelineReadProgress
    let activity: TimelineScrubActivity
    @State private var visible = false
    var body: some View {
        Text(progress.date?.formatted(.dateTime.year().month(.wide)) ?? "")
            .font(.caption.monospacedDigit()).foregroundStyle(AfterimageStyle.amber)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(AfterimageStyle.background.opacity(0.94), in: Capsule())
            .opacity(visible && progress.date != nil ? 1 : 0)
            .animation(.easeOut(duration: 0.22), value: visible)
            .allowsHitTesting(false).accessibilityHidden(!visible)
            .task(id: activity.active) {
                if activity.active { visible = true }
                else {
                    do { try await Task.sleep(for: .milliseconds(700)) }
                    catch { return }
                    visible = false
                }
            }
    }
}

/// Keep per-frame progress reads out of the library's body.
struct TimelineScrubWordmark: View {
    @Environment(\.afterimageReduceMotion) private var reduceMotion
    let progress: TimelineReadProgress
    let scrubber: TimelineScrubber
    let empty: Bool
    let externalWordmark: Bool
    let enabled: Bool

    var body: some View {
        ReadingPositionWordmark(progress: progress, empty: empty, externalWordmark: externalWordmark)
            .frame(width: 190, height: 44)
            .overlay {
                TimelineScrubSurface(scrubber: scrubber, reduceMotion: reduceMotion, enabled: enabled && !empty)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("时间轴浏览位置")
            .accessibilityValue(empty ? "暂无记录" : "\(Int(progress.value * 100))%")
            .accessibilityHint("左右滑动快速浏览时间轴")
            .accessibilityAdjustableAction { direction in
                guard enabled && !empty else { return }
                switch direction {
                case .increment: scrubber.step(forward: true)
                case .decrement: scrubber.step(forward: false)
                @unknown default: break
                }
            }
    }
}

/// Drives the existing scroll view, so cards, silk and reading progress stay in sync.
final class TimelineScrubber: NSObject {
    let activity = TimelineScrubActivity()
    weak var scrollView: UIScrollView?
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var velocity: CGFloat = 0
    private var scale: CGFloat = 1
    private var lastTranslation: CGFloat = 0

    func attach(_ scroll: UIScrollView) {
        guard scrollView !== scroll else { return }
        detach()
        scrollView = scroll
        scroll.panGestureRecognizer.addTarget(self, action: #selector(nativePan(_:)))
    }

    func detach() {
        stop()
        scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(nativePan(_:)))
        scrollView = nil
    }

    func stop() {
        activity.active = false
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        velocity = 0
    }

    private var bounds: ClosedRange<CGFloat>? {
        guard let scroll = scrollView else { return nil }
        let lower = -scroll.adjustedContentInset.left
        let upper = max(lower, scroll.contentSize.width - scroll.bounds.width + scroll.adjustedContentInset.right)
        return lower...upper
    }

    func begin(width: CGFloat) {
        stop()
        guard let scroll = scrollView, let bounds else { return }
        // Stop native deceleration at the visible position. Never jump to touch-down's fraction.
        activity.active = true
        scroll.setContentOffset(scroll.contentOffset, animated: false)
        scale = max(1, (bounds.upperBound - bounds.lowerBound) / max(1, width))
        lastTranslation = 0
    }

    func drag(translation: CGFloat) {
        guard let scroll = scrollView else { return }
        setOffset(scroll.contentOffset.x + (translation - lastTranslation) * scale)
        lastTranslation = translation
    }

    func end(fingerVelocity: CGFloat, reduceMotion: Bool) {
        guard let scroll = scrollView, !reduceMotion else { stop(); return }
        // Bound very fast throws without losing the velocity of ordinary drags.
        let limit = max(1, scroll.bounds.width) * 12
        velocity = min(limit, max(-limit, fingerVelocity * scale))
        guard abs(velocity) > 15 else { stop(); return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        displayLink = link
        link.add(to: .main, forMode: .common)
    }

    func step(forward: Bool) {
        stop()
        guard let scroll = scrollView, let bounds else { return }
        let amount = max(scroll.bounds.width * 0.8, (bounds.upperBound - bounds.lowerBound) * 0.05)
        setOffset(scroll.contentOffset.x + (forward ? amount : -amount))
    }

    private func setOffset(_ x: CGFloat) {
        guard let scroll = scrollView, let bounds else { return }
        scroll.setContentOffset(CGPoint(x: min(bounds.upperBound, max(bounds.lowerBound, x)),
                                       y: scroll.contentOffset.y), animated: false)
    }

    @objc private func nativePan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began || gesture.state == .changed { stop() }
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let scroll = scrollView, scroll.window != nil,
              !scroll.isTracking, !scroll.isDragging, let bounds else { stop(); return }
        let dt = min(1.0 / 30, lastTimestamp == 0 ? link.targetTimestamp - link.timestamp : link.timestamp - lastTimestamp)
        lastTimestamp = link.timestamp
        // Exponential friction is independent of refresh rate; approach either end softly.
        let distance = velocity > 0 ? bounds.upperBound - scroll.contentOffset.x : scroll.contentOffset.x - bounds.lowerBound
        let braking = max(0, distance) * 9
        velocity = (velocity < 0 ? -1 : 1) * min(abs(velocity), braking)
        let decay = CGFloat(exp(-5.5 * dt))
        setOffset(scroll.contentOffset.x + velocity * (1 - decay) / 5.5)
        velocity *= decay
        if abs(velocity) < 8 { stop() }
    }
}

/// Transparent native touch surface over the wordmark, with a 44-point target.
struct TimelineScrubSurface: UIViewRepresentable {
    let scrubber: TimelineScrubber
    var reduceMotion: Bool
    var enabled: Bool

    func makeUIView(context: Context) -> TouchView { TouchView() }
    func updateUIView(_ view: TouchView, context: Context) {
        let motionChanged = view.reduceMotion != reduceMotion
        view.scrubber = scrubber
        view.reduceMotion = reduceMotion
        view.isUserInteractionEnabled = enabled
        if !enabled || motionChanged { scrubber.stop() }
    }
    static func dismantleUIView(_ view: TouchView, coordinator: ()) { view.scrubber?.stop() }

    final class TouchView: UIView, UIGestureRecognizerDelegate {
        weak var scrubber: TimelineScrubber?
        var reduceMotion = false
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
            addGestureRecognizer(pan)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            scrubber?.stop()
            super.touchesBegan(touches, with: event)
        }
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: self)
            return abs(velocity.x) > abs(velocity.y)
        }
        @objc private func pan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                scrubber?.begin(width: bounds.width)
                scrubber?.drag(translation: gesture.translation(in: self).x)
            case .changed:
                scrubber?.drag(translation: gesture.translation(in: self).x)
            case .ended:
                scrubber?.drag(translation: gesture.translation(in: self).x)
                scrubber?.end(fingerVelocity: gesture.velocity(in: self).x, reduceMotion: reduceMotion)
            case .cancelled, .failed: scrubber?.stop()
            default: break
            }
        }
    }
}
