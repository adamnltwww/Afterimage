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
        try? await Task.sleep(for: .milliseconds(750))
        guard !Task.isCancelled, !finishing, isBlocking else { return }
        finish(reduceMotion: false)
    }

    func finish(reduceMotion: Bool) {
        guard isBlocking, !finishing else { return }
        finishing = true
        ending = Task { @MainActor in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.85)) {
                spread = 1; silkOpacity = 1; wordmarkTravel = 0
                wordmarkOpacity = reduceMotion ? 0 : 1
            }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(850)) }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: reduceMotion ? 0.25 : 1.15)) { contentOpacity = 1 }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 1150))
            guard !Task.isCancelled else { return }
            isBlocking = false
            ending = nil
        }
    }

    func enterBackground() {
        ending?.cancel(); ending = nil
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) {
            spread = 1; silkOpacity = 1; contentOpacity = 1; wordmarkTravel = 0; wordmarkOpacity = 0
            finishing = true; isBlocking = false
        }
    }
}

/// The only moving overlay is the wordmark; the actual silk never switches views.
struct OpeningView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let presentation: OpeningPresentation

    var body: some View {
        GeometryReader { geometry in
            Color.clear.contentShape(Rectangle()).onTapGesture { }
                .onAppear { presentation.overlayFrame = geometry.frame(in: .global) }
                .onChange(of: geometry.frame(in: .global)) { _, frame in presentation.overlayFrame = frame }
                .overlay {
                    if let surface = presentation.overlayFrame,
                       let axis = presentation.axisFrame, let title = presentation.titleFrame {
                        let worldX = surface.midX - axis.minX
                        let start = axis.minY + TimelineLayout.y(at: worldX) * axis.height / 530 - 66
                        let y = title.midY + (start - title.midY) * presentation.wordmarkTravel
                        AfterimageWordmark(progress: presentation.wordmarkSheen * presentation.wordmarkTravel
                                           + presentation.readingProgress * (1 - presentation.wordmarkTravel))
                            .frame(width: 190, height: 32)
                            .scaleEffect(1 + 0.32 * presentation.wordmarkTravel)
                            .brightness(0.08 * presentation.wordmarkTravel)
                            .shadow(color: AfterimageStyle.amber.opacity(0.5 * presentation.wordmarkTravel),
                                    radius: 9 * presentation.wordmarkTravel)
                            .position(x: title.midX - surface.minX, y: y - surface.minY)
                            .opacity(presentation.wordmarkOpacity * (1 - presentation.contentOpacity))
                            .accessibilityHidden(true).allowsHitTesting(false)
                    }
                }
            .overlay(alignment: .bottomTrailing) {
                Button("跳过") { presentation.finish(reduceMotion: reduceMotion) }
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
            guard presentation.isBlocking else { return }
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
                // The text's representable can retain a SwiftUI projection offset.
                // The enclosing native navigation bar is the physical landing surface.
                var ancestor = self.superview
                while let view = ancestor {
                    if let bar = view as? UINavigationBar {
                        self.measured?(bar.convert(bar.bounds, to: window))
                        return
                    }
                    ancestor = view.superview
                }
                if let bar = Self.navigationBar(in: window) {
                    self.measured?(bar.convert(bar.bounds, to: window))
                } else {
                    self.measured?(CGRect(x: 0, y: window.safeAreaInsets.top, width: window.bounds.width, height: 44))
                }
            }
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
