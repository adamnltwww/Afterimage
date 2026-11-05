import SwiftUI
import UIKit

/// Read the actual native scroll position, including programmatic jumps and deceleration.
struct TimelineScrollObserver: UIViewRepresentable {
    @Binding var offset: Double
    var granularity = 0.5
    var onOffset: ((Double) -> Void)?

    func makeUIView(context: Context) -> Marker { Marker() }
    func updateUIView(_ view: Marker, context: Context) {
        view.changed = { value in
            onOffset?(value)
            if abs(offset - value) > granularity { offset = value }
        }
        view.connectWhenReady()
    }

    final class Marker: UIView {
        var changed: ((Double) -> Void)?
        private var observation: NSKeyValueObservation?
        private weak var observedScroll: UIScrollView?

        func connectWhenReady() {
            DispatchQueue.main.async { [weak self] in self?.connect() }
        }

        override func didMoveToSuperview() { super.didMoveToSuperview(); connectWhenReady() }
        override func layoutSubviews() { super.layoutSubviews(); connectWhenReady() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { observation = nil; observedScroll = nil }
            else { connectWhenReady() }
        }

        private func connect() {
            guard window != nil else { return }
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    if observedScroll === scroll {
                        changed?(Double(scroll.contentOffset.x + scroll.adjustedContentInset.left))
                        return
                    }
                    observedScroll = scroll
                    observation = scroll.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scroll, _ in
                        let value = Double(scroll.contentOffset.x + scroll.adjustedContentInset.left)
                        DispatchQueue.main.async { [weak self] in self?.changed?(value) }
                    }
                    break
                }
                ancestor = view.superview
            }
        }
    }
}

struct TimelineScrollTracking: ViewModifier {
    @Binding var offset: Double
    var granularity = 0.5
    var onOffset: ((Double) -> Void)?
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Double.self) { geometry in
                geometry.contentOffset.x + geometry.contentInsets.leading
            } action: { _, value in
                onOffset?(value)
                if abs(offset - value) > granularity { offset = value }
            }
        } else {
            content
        }
    }
}

