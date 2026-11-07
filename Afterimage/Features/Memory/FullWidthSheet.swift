import SwiftUI
import UIKit

/// A constant-width drawer. Only its height changes while the user drags.
struct FullWidthSheet<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var initialHeight: CGFloat = 390
    var fixedHeight = false
    var onDismiss: () -> Void = {}
    @ViewBuilder var content: () -> Content
    @Environment(\.afterimageReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.requested = isPresented
        coordinator.onDismiss = { isPresented = false; onDismiss() }
        coordinator.initialHeight = initialHeight
        coordinator.fixedHeight = fixedHeight
        coordinator.reduceMotion = reduceMotion
        if isPresented {
            if let host = coordinator.host {
                host.rootView = AnyView(content().preferredColorScheme(.dark).tint(AfterimageStyle.amber))
            } else if !coordinator.scheduled {
                coordinator.scheduled = true
                let root = AnyView(content().preferredColorScheme(.dark).tint(AfterimageStyle.amber))
                DispatchQueue.main.async {
                    coordinator.scheduled = false
                    guard coordinator.requested, controller.view.window != nil, coordinator.host == nil else { return }
                    let host = DrawerHost(rootView: root)
                    host.view.backgroundColor = UIColor(red: 0.035, green: 0.043, blue: 0.055, alpha: 1)
                    host.modalPresentationStyle = .custom
                    host.transitioningDelegate = coordinator
                    coordinator.host = host
                    controller.present(host, animated: !coordinator.reduceMotion)
                }
            }
        } else if coordinator.host != nil {
            coordinator.close()
        }
    }
    final class Coordinator: NSObject, UIViewControllerTransitioningDelegate {
        var host: DrawerHost?
        var scheduled = false
        var requested = false
        var initialHeight: CGFloat = 390
        var fixedHeight = false
        var reduceMotion = false
        var onDismiss: () -> Void = {}
        private var closing = false
        func close() {
            guard let host, !closing else { return }
            closing = true
            host.dismiss(animated: !reduceMotion) { [weak self] in
                guard let self else { return }
                self.host = nil; self.closing = false; self.onDismiss()
            }
        }
        func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
            DrawerPresentation(presentedViewController: presented, presenting: presenting, height: initialHeight,
                               fixedHeight: fixedHeight, reduceMotion: reduceMotion, close: { [weak self] in self?.close() })
        }
        func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? { DrawerTransition(appearing: true) }
        func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? { DrawerTransition(appearing: false) }
    }
}

final class DrawerHost: UIViewController {
    private let hosting: UIHostingController<AnyView>
    private var contentHeight: NSLayoutConstraint?
    var contentDidLayout: (() -> Void)?
    var rootView: AnyView { get { hosting.rootView } set { hosting.rootView = newValue } }
    init(rootView: AnyView) { hosting = UIHostingController(rootView: rootView); super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        hosting.safeAreaRegions = []
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 16)
        ])
        let height = hosting.view.heightAnchor.constraint(equalToConstant: 1)
        height.isActive = true; contentHeight = height
        hosting.didMove(toParent: self)
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); contentDidLayout?() }
    func setViewportHeight(_ maximum: CGFloat, bottomInset: CGFloat) {
        loadViewIfNeeded()
        let value = max(1, maximum - 16 - bottomInset)
        if contentHeight?.constant != value { contentHeight?.constant = value }
    }
}

private final class DrawerTransition: NSObject, UIViewControllerAnimatedTransitioning {
    let appearing: Bool
    init(appearing: Bool) { self.appearing = appearing }
    func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval { 0.42 }
    func animateTransition(using context: UIViewControllerContextTransitioning) {
        let key: UITransitionContextViewControllerKey = appearing ? .to : .from
        guard let controller = context.viewController(forKey: key), let view = context.view(forKey: appearing ? .to : .from) else { context.completeTransition(false); return }
        if appearing {
            context.containerView.addSubview(view)
            view.frame = context.finalFrame(for: controller)
            view.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
        }
        UIView.animate(withDuration: transitionDuration(using: context), delay: 0, usingSpringWithDamping: 0.94, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            view.transform = self.appearing ? .identity : CGAffineTransform(translationX: 0, y: view.bounds.height)
        } completion: { _ in context.completeTransition(!context.transitionWasCancelled) }
    }
}

private final class DrawerPresentation: UIPresentationController, UIGestureRecognizerDelegate {
    let initialHeight: CGFloat
    let fixedHeight: Bool
    let reduceMotion: Bool
    let close: () -> Void
    private var height: CGFloat
    private var startHeight: CGFloat = 0
    private var dragging = false
    private var settling = false
    private let dimmer = UIControl()
    private let handle = UIView()
    private var pan: UIPanGestureRecognizer!
    init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?, height: CGFloat, fixedHeight: Bool, reduceMotion: Bool, close: @escaping () -> Void) {
        self.fixedHeight = fixedHeight
        initialHeight = height; self.height = height; self.reduceMotion = reduceMotion; self.close = close
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }
    private var maximum: CGFloat { guard let containerView else { return height }; return containerView.bounds.height - containerView.safeAreaInsets.top - 8 }
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }
        let actual = min(maximum, max(100, height))
        return CGRect(x: 0, y: containerView.bounds.height - actual, width: containerView.bounds.width, height: actual)
    }
    override func presentationTransitionWillBegin() {
        guard let containerView, let presentedView else { return }
        dimmer.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        dimmer.alpha = 0; dimmer.addTarget(self, action: #selector(backdropTapped), for: .touchUpInside)
        containerView.insertSubview(dimmer, at: 0)
        presentedView.layer.cornerRadius = 28
        presentedView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        presentedView.clipsToBounds = true
        handle.backgroundColor = UIColor.white.withAlphaComponent(0.25); handle.layer.cornerRadius = 2.5
        handle.isUserInteractionEnabled = false; presentedView.addSubview(handle)
        // Leave space above the native navigation bar for the grabber.
        (presentedViewController as? DrawerHost)?.setViewportHeight(maximum, bottomInset: containerView.safeAreaInsets.bottom)
        pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.delegate = self; presentedView.addGestureRecognizer(pan)
        (presentedViewController as? DrawerHost)?.contentDidLayout = { [weak self] in self?.updateScrollAccess() }
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in self.dimmer.alpha = 1 })
        if presentedViewController.transitionCoordinator == nil { dimmer.alpha = 1 }
    }
    override func dismissalTransitionWillBegin() {
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in self.dimmer.alpha = 0 })
    }
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        dimmer.frame = containerView?.bounds ?? .zero
        (presentedViewController as? DrawerHost)?.setViewportHeight(fixedHeight ? min(initialHeight, maximum) : maximum, bottomInset: containerView?.safeAreaInsets.bottom ?? 0)
        presentedView?.frame = frameOfPresentedViewInContainerView
        handle.frame = CGRect(x: frameOfPresentedViewInContainerView.width / 2 - 22, y: 6, width: 44, height: 5)
        presentedView?.bringSubviewToFront(handle)
        updateScrollAccess()
    }
    override func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)
        if completed { updateScrollAccess(); DispatchQueue.main.async { [weak self] in self?.updateScrollAccess() } }
    }
    private func updateScrollAccess() {
        guard pan != nil, let view = presentedView else { return }
        configureScrolls(in: view, enabled: !dragging && !settling && (fixedHeight || height >= maximum - 1))
    }
    private func configureScrolls(in view: UIView, enabled: Bool) {
        if let scroll = view as? UIScrollView {
            if scroll.isScrollEnabled != enabled { scroll.isScrollEnabled = enabled }
            scroll.panGestureRecognizer.require(toFail: pan)
        }
        for child in view.subviews { configureScrolls(in: child, enabled: enabled) }
    }
    private func enclosingScroll(_ view: UIView?) -> UIScrollView? {
        var current = view
        while let candidate = current {
            if let scroll = candidate as? UIScrollView { return scroll }
            current = candidate.superview
        }
        return nil
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let velocity = pan.velocity(in: containerView)
        guard abs(velocity.y) > abs(velocity.x) * 1.15 else { return false }
        let point = pan.location(in: presentedView)
        if fixedHeight {
            guard velocity.y > 0 else { return false }
            if let scroll = enclosingScroll(presentedView?.hitTest(point, with: nil)) {
                return scroll.contentOffset.y <= -scroll.adjustedContentInset.top + 1
            }
            return true
        }
        if height < maximum - 1 || settling { return true }
        if let scroll = enclosingScroll(presentedView?.hitTest(point, with: nil)) {
            return velocity.y > 0 && scroll.contentOffset.y <= -scroll.adjustedContentInset.top + 1
        }
        return true
    }
    @objc private func backdropTapped() { close() }
    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        guard let containerView else { return }
        switch gesture.state {
        case .began:
            if settling, let frame = presentedView?.layer.presentation()?.frame {
                height = frame.height
                presentedView?.layer.removeAllAnimations()
                presentedView?.frame = frame
                settling = false
            }
            startHeight = height; dragging = true; updateScrollAccess()
        case .changed:
            height = min(fixedHeight ? min(initialHeight, maximum) : maximum, max(100, startHeight - gesture.translation(in: containerView).y))
            containerView.setNeedsLayout(); containerView.layoutIfNeeded()
        case .ended, .cancelled, .failed:
            dragging = false
            let velocity = gesture.velocity(in: containerView).y
            if gesture.state == .ended && (height < initialHeight * 0.7 || (velocity > 1000 && height < initialHeight + 20)) { close(); return }
            let projected = height - velocity * 0.16
            let target = !fixedHeight && projected > (initialHeight + maximum) / 2 ? maximum : min(initialHeight, maximum)
            height = target; settling = true
            UIView.animate(withDuration: reduceMotion ? 0 : 0.36, delay: 0, usingSpringWithDamping: 0.92, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                containerView.setNeedsLayout(); containerView.layoutIfNeeded()
            } completion: { _ in
                self.settling = false; self.updateScrollAccess()
            }
        default: break
        }
    }
}
