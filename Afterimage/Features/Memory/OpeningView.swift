import SwiftUI
import Observation
import UIKit

private struct OpeningPresentationKey: EnvironmentKey {
    static let defaultValue: OpeningPresentation? = nil
}
extension EnvironmentValues {
    var openingPresentation: OpeningPresentation? {
        get { self[OpeningPresentationKey.self] }
        set { self[OpeningPresentationKey.self] = newValue }
    }
}

/// One persistent timeline. Skip and automatic completion share the same gentle ending.
@MainActor @Observable final class OpeningPresentation {
    var spread = 2.6
    var silkOpacity = 0.0
    var contentOpacity = 0.0
    var wordmarkOpacity = 0.0
    var wordmarkTravel = 1.0
    var wordmarkSheen = 0.0
    var titleFrame: CGRect?
    var axisFrame: CGRect?
    var overlayFrame: CGRect?
    var readingProgress = 1.0
    private(set) var isBlocking: Bool
    private(set) var finishing = false
    private var started = false
    private var ending: OpeningFrameDriver?
    var silkBegan: Date?

    init(active: Bool = true) {
        isBlocking = active
        if !active { spread = 1; silkOpacity = 1; contentOpacity = 1; wordmarkTravel = 0 }
    }

    func start(reduceMotion: Bool) async {
        guard !started, isBlocking else { return }
        started = true
        if reduceMotion { finish(reduceMotion: true); return }
        // Wait for real UIKit/window coordinates, including the separately hosted toolbar.
        for _ in 0..<15 {
            if titleFrame != nil, axisFrame != nil, overlayFrame != nil { break }
            try? await Task.sleep(for: .milliseconds(20))
            guard !Task.isCancelled, isBlocking else { return }
        }
        guard !Task.isCancelled, !finishing, isBlocking else { return }
        withAnimation(.easeOut(duration: 0.45)) { wordmarkOpacity = 1 }
        withAnimation(.easeInOut(duration: 0.95)) { wordmarkSheen = 1 }
        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled, !finishing, isBlocking else { return }
        silkBegan = Date()
        withAnimation(.easeOut(duration: 0.3)) { silkOpacity = 1 }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-opening-hold") { return }
        #endif
        try? await Task.sleep(for: .milliseconds(650))
        guard !Task.isCancelled, !finishing, isBlocking else { return }
        finish(reduceMotion: false)
    }

    func finish(reduceMotion: Bool, shortened: Bool = false) {
        guard isBlocking else { return }
        if finishing {
            if reduceMotion { enterBackground() }
            return
        }
        finishing = true
        let gathering = reduceMotion ? 0.25 : (shortened ? 0.65 : 2.05)
        let initialSpread = spread
        let initialTravel = wordmarkTravel
        let initialSilk = silkOpacity
        let initialWordmark = wordmarkOpacity
        let initialContent = contentOpacity
        let driver = OpeningFrameDriver()
        ending = driver
        driver.start { [weak self] elapsed in
            guard let self else { return false }
            let p = min(1, elapsed / gathering)
            let travel = Self.smoother(min(1, elapsed / (gathering * 0.91)))
            let reveal = Self.smoother((p - (reduceMotion ? 0 : 0.52)) / (reduceMotion ? 1 : 0.48))
            var frame = Transaction(); frame.disablesAnimations = true
            withTransaction(frame) {
                self.spread = reduceMotion ? 1 : 1 + (initialSpread - 1) * (1 - p)
                self.wordmarkTravel = reduceMotion ? 0 : initialTravel * (1 - travel)
                self.silkOpacity = initialSilk + (1 - initialSilk) * Self.smoother(elapsed / 0.22)
                self.wordmarkOpacity = initialWordmark + (1 - initialWordmark) * Self.smoother(elapsed / 0.22)
                self.contentOpacity = initialContent + (1 - initialContent) * reveal
                if p >= 1 { self.isBlocking = false }
            }
            if p >= 1 { self.ending = nil }
            return p < 1
        }
    }

    private static func smoother(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    func enterBackground() {
        ending?.stop(); ending = nil
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) {
            spread = 1; silkOpacity = 1; contentOpacity = 1; wordmarkTravel = 0; wordmarkOpacity = 1
            finishing = true; isBlocking = false
        }
    }
}

@MainActor private final class OpeningFrameDriver: NSObject {
    private var link: CADisplayLink?
    private var began: CFTimeInterval?
    private var update: ((Double) -> Bool)?

    func start(_ update: @escaping (Double) -> Bool) {
        self.update = update
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        self.link = link
        link.add(to: .main, forMode: .common)
    }

    @objc private func tick(_ link: CADisplayLink) {
        if began == nil { began = link.timestamp }
        if update?(link.timestamp - (began ?? link.timestamp)) != true { stop() }
    }

    func stop() {
        link?.invalidate(); link = nil; update = nil; began = nil
    }
}

/// The wordmark belongs to the library for its entire lifetime, including after launch.
/// Only this input shield and skip control are removed when launch finishes.
struct OpeningView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let presentation: OpeningPresentation

    var body: some View {
            Color.clear.contentShape(Rectangle()).onTapGesture { }
            .overlay(alignment: .bottomTrailing) {
                Button("跳过") { presentation.finish(reduceMotion: reduceMotion, shortened: true) }
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(minWidth: 52, minHeight: 44)
                    .accessibilityIdentifier("opening.skip")
                    .padding(.horizontal, 24).padding(.bottom, 20)
                    .opacity(presentation.finishing ? 0 : 1)
                    .allowsHitTesting(!presentation.finishing)
                    .accessibilityHidden(presentation.finishing)
                    .animation(.easeOut(duration: 0.2), value: presentation.finishing)
            }
            .task { await presentation.start(reduceMotion: reduceMotion) }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { presentation.enterBackground() }
            }
            .onChange(of: reduceMotion) { _, enabled in
                if enabled { presentation.finish(reduceMotion: true) }
            }
    }
}

/// A single render node moves to the title slot and remains there during normal reading.
/// Content reveal never fades it into another copy hosted by the navigation bar.
struct OpeningWordmark: View {
    let presentation: OpeningPresentation

    var body: some View {
        // Read observable inputs in body, before GeometryReader defers its content.
        let titleFrame = presentation.titleFrame
        let axisFrame = presentation.axisFrame
        let travel = presentation.wordmarkTravel
        let sheen = presentation.wordmarkSheen
        let reading = presentation.readingProgress
        let blocking = presentation.isBlocking
        let opacity = blocking ? presentation.wordmarkOpacity : 1
        return GeometryReader { geometry in
            let surface = geometry.frame(in: .global)
            if let title = titleFrame {
                let axis = axisFrame ?? surface
                let worldX = surface.midX - axis.minX
                let start = axis.minY + TimelineLayout.y(at: worldX) * axis.height / 530 - 66
                let y = title.midY + (start - title.midY) * travel
                AfterimageWordmark(progress: sheen * travel + reading * (1 - travel))
                    .frame(width: 190, height: 32)
                    .scaleEffect(1 + 0.32 * travel)
                    .brightness(0.08 * travel)
                    .shadow(color: AfterimageStyle.amber.opacity(0.5 * travel), radius: 9 * travel)
                    .position(x: title.midX - surface.minX, y: y - surface.minY)
                    .opacity(opacity)
                    .accessibilityHidden(blocking)
            }
            Color.clear
                .onAppear { presentation.overlayFrame = surface }
                .onChange(of: surface) { _, frame in presentation.overlayFrame = frame }
        }
        .allowsHitTesting(false)
    }
}

/// Measure in window space: SwiftUI toolbar anchors belong to a different hosting root.
struct OpeningGeometryProbe: UIViewRepresentable {
    enum Target { case title, axis, overlay }
    let presentation: OpeningPresentation
    let target: Target
    var readingProgress = 1.0

    func makeUIView(context: Context) -> Marker { Marker() }
    func updateUIView(_ view: Marker, context: Context) {
        view.measured = { frame in
            switch target {
            case .title:
                if presentation.titleFrame != frame { presentation.titleFrame = frame }
                if presentation.readingProgress != readingProgress { presentation.readingProgress = readingProgress }
            case .axis:
                if presentation.axisFrame != frame { presentation.axisFrame = frame }
            case .overlay:
                if presentation.overlayFrame != frame { presentation.overlayFrame = frame }
            }
        }
        view.refresh()
    }

    final class Marker: UIView {
        var measured: ((CGRect) -> Void)?
        override func didMoveToWindow() { super.didMoveToWindow(); refresh() }
        override func layoutSubviews() { super.layoutSubviews(); refresh() }
        func refresh() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window, self.bounds.width > 0, self.bounds.height > 0 else { return }
                // The bar can include space above/below its actual controls on iOS 26.
                // Land on the controls' centerline, rather than the whole bar's midpoint.
                var ancestor = self.superview
                while let view = ancestor {
                    if let bar = view as? UINavigationBar {
                        self.measured?(Self.titleSlot(in: bar, window: window))
                        return
                    }
                    ancestor = view.superview
                }
                if let bar = Self.navigationBar(in: window) {
                    self.measured?(Self.titleSlot(in: bar, window: window))
                } else {
                    self.measured?(CGRect(x: 0, y: window.safeAreaInsets.top, width: window.bounds.width, height: 44))
                }
            }
        }
        private static func titleSlot(in bar: UINavigationBar, window: UIWindow) -> CGRect {
            let bounds = bar.convert(bar.bounds, to: window)
            let items = (bar.topItem?.leftBarButtonItems ?? []) + (bar.topItem?.rightBarButtonItems ?? [])
            let customFrames = items.compactMap { $0.customView }.map { $0.convert($0.bounds, to: window) }
                .filter { !$0.isEmpty && bounds.intersects($0) }
            let frames = customFrames.isEmpty ? controlFrames(in: bar, window: window, barBounds: bounds) : customFrames
            let centerY: CGFloat
            if !frames.isEmpty {
                centerY = frames.map(\.midY).reduce(0, +) / CGFloat(frames.count)
            } else if let title = bar.topItem?.titleView, !title.bounds.isEmpty {
                centerY = title.convert(title.bounds, to: window).midY
            } else {
                centerY = bounds.midY
            }
            return CGRect(x: bounds.minX, y: centerY - 16, width: bounds.width, height: 32)
        }
        private static func controlFrames(in view: UIView, window: UIWindow, barBounds: CGRect) -> [CGRect] {
            if view is UIControl {
                let frame = view.convert(view.bounds, to: window)
                let atSide = abs(frame.midX - barBounds.midX) > barBounds.width * 0.2
                if !view.isHidden, frame.height >= 20, frame.height <= 80, atSide, barBounds.intersects(frame) {
                    return [frame]
                }
            }
            return view.subviews.flatMap { controlFrames(in: $0, window: window, barBounds: barBounds) }
        }
        private static func navigationBar(in view: UIView) -> UINavigationBar? {
            if let bar = view as? UINavigationBar, !bar.isHidden { return bar }
            for child in view.subviews {
                if let bar = navigationBar(in: child) { return bar }
            }
            return nil
        }
    }
}
