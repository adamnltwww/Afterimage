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
    private(set) var gatheringStartedAt: Double?
    private var gatheringDuration = 1.75
    private var gatheringFrom = 1.0
    private(set) var isBlocking: Bool
    private(set) var finishing = false
    private var started = false
    private var ending: Task<Void, Never>?

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
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled, !finishing, isBlocking else { return }
        withAnimation(.easeOut(duration: 0.7)) { silkOpacity = 1 }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-opening-hold") { return }
        #endif
        try? await Task.sleep(for: .milliseconds(1000))
        guard !Task.isCancelled, !finishing, isBlocking else { return }
        finish(reduceMotion: false)
    }

    func finish(reduceMotion: Bool, shortened: Bool = false) {
        guard isBlocking, !finishing else { return }
        finishing = true
        let now = Date.timeIntervalSinceReferenceDate
        gatheringFrom = reduceMotion ? 0 : silkAmount(at: now)
        gatheringDuration = shortened ? 0.7 : 1.75
        gatheringStartedAt = reduceMotion ? nil : now
        ending = Task { @MainActor in
            let gathering = shortened ? 0.7 : 1.75
            withAnimation(reduceMotion ? nil : .timingCurve(0.22, 0.62, 0.2, 1, duration: gathering)) {
                spread = 1; silkOpacity = 1
                wordmarkOpacity = 1
            }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: shortened ? 0.7 : 1.5).delay(shortened ? 0 : 0.15)) {
                wordmarkTravel = 0
            }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(shortened ? 700 : 1750)) }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: reduceMotion ? 0.25 : 1.15)) { contentOpacity = 1 }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 1150))
            guard !Task.isCancelled else { return }
            isBlocking = false
            ending = nil
        }
    }

    /// The drawing clock owns convergence; canvas refreshes cannot cancel it.
    func silkAmount(at time: Double) -> Double {
        guard let start = gatheringStartedAt else { return max(0, (spread - 1) / 1.6) }
        let progress = min(1, max(0, (time - start) / gatheringDuration))
        return gatheringFrom * (1 - ThreadGeometry.smooth(progress))
    }

    func enterBackground() {
        ending?.cancel(); ending = nil
        gatheringStartedAt = nil
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) {
            spread = 1; silkOpacity = 1; contentOpacity = 1; wordmarkTravel = 0; wordmarkOpacity = 1
            finishing = true; isBlocking = false
        }
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
        GeometryReader { geometry in
            let surface = geometry.frame(in: .global)
            if let title = presentation.titleFrame {
                let axis = presentation.axisFrame ?? surface
                let worldX = surface.midX - axis.minX
                let start = axis.minY + TimelineLayout.y(at: worldX) * axis.height / 530 - 66
                let travel = presentation.wordmarkTravel
                let y = title.midY + (start - title.midY) * travel
                AfterimageWordmark(progress: presentation.wordmarkSheen * travel
                                   + presentation.readingProgress * (1 - travel))
                    .frame(width: 190, height: 32)
                    .scaleEffect(1 + 0.32 * travel)
                    .brightness(0.08 * travel)
                    .shadow(color: AfterimageStyle.amber.opacity(0.5 * travel), radius: 9 * travel)
                    .position(x: title.midX - surface.minX, y: y - surface.minY)
                    .opacity(presentation.isBlocking ? presentation.wordmarkOpacity : 1)
                    .accessibilityHidden(presentation.isBlocking)
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
