import SwiftUI
import UIKit

/// A directional pan on the memory itself; horizontal pans remain timeline navigation.
struct ThreadNodeTouch: UIViewRepresentable {
    let enabled: Bool
    let motion: ThreadMotion?
    let reduceMotion: Bool
    var x: Double = 0
    var verticalScale = 1.0
    var press: (Bool) -> Void = { _ in }
    let tap: () -> Void

    func makeUIView(context: Context) -> TouchView { TouchView() }

    func updateUIView(_ view: TouchView, context: Context) {
        view.motion = motion
        view.pan.isEnabled = enabled
        view.reduceMotion = reduceMotion
        view.tapAction = tap
        view.x = x
        view.verticalScale = verticalScale < 0 ? min(-0.01, verticalScale) : max(0.01, verticalScale)
        view.pressAction = press
    }

    final class TouchView: UIView, UIGestureRecognizerDelegate {
        var motion: ThreadMotion?
        var reduceMotion = false
        var tapAction: (() -> Void)?
        var x = 0.0
        var verticalScale = 1.0
        var pressAction: ((Bool) -> Void)?
        lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isAccessibilityElement = false
            pan.delegate = self
            pan.maximumNumberOfTouches = 1
            addGestureRecognizer(pan)
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
            tap.require(toFail: pan)
            addGestureRecognizer(tap)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            // Let the node decide direction before either enclosing scroll view begins.
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    scroll.panGestureRecognizer.require(toFail: pan)
                }
                ancestor = view.superview
            }
        }

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === pan else { return true }
            let velocity = pan.velocity(in: window)
            return abs(velocity.y) > abs(velocity.x) * 1.2
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event); pressAction?(true)
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event); pressAction?(false)
        }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesCancelled(touches, with: event); pressAction?(false)
        }
        @objc private func tapped() { pressAction?(false); tapAction?() }

        @objc private func panned(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: window).y / verticalScale
            switch gesture.state {
            case .began, .changed:
                pressAction?(true)
                motion?.drag(translation: translation, at: x, allowOvershoot: !reduceMotion)
            case .ended:
                pressAction?(false)
                let predicted = translation + gesture.velocity(in: window).y * 0.18 / verticalScale
                motion?.endDrag(translation: translation, predicted: predicted, reduceMotion: reduceMotion)
            case .cancelled, .failed:
                pressAction?(false)
                motion?.endDrag(translation: translation, predicted: translation, reduceMotion: reduceMotion)
            default: break
            }
        }
    }
}
