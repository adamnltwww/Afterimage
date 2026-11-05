import SwiftUI
import UIKit

/// A UIKit image source gives the fullscreen transition an exact, reversible origin.
struct PhotoViewerEntry: UIViewControllerRepresentable {
    let data: Data
    func makeUIViewController(context: Context) -> PhotoSourceController { PhotoSourceController() }
    func updateUIViewController(_ controller: PhotoSourceController, context: Context) {
        if controller.data != data { controller.data = data; controller.imageView.image = UIImage(data: data) }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: PhotoSourceController, context: Context) -> CGSize? {
        guard let image = uiViewController.imageView.image, let width = proposal.width, image.size.width > 0 else { return nil }
        return CGSize(width: width, height: width * image.size.height / image.size.width)
    }
}

final class PhotoSourceController: UIViewController, UIViewControllerTransitioningDelegate {
    let imageView = UIImageView()
    var data: Data?

    override func loadView() {
        let button = UIButton(type: .custom)
        button.accessibilityLabel = "全屏查看照片"
        button.accessibilityIdentifier = "photo.open"
        button.addTarget(self, action: #selector(openPhoto), for: .touchUpInside)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        button.addSubview(imageView)
        view = button
    }

    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); imageView.frame = view.bounds }

    @objc private func openPhoto() {
        guard let image = imageView.image, presentedViewController == nil else { return }
        let viewer = PhotoZoomController(image: image)
        viewer.modalPresentationStyle = .overFullScreen
        viewer.transitioningDelegate = self
        present(viewer, animated: true)
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PhotoTransition(source: imageView, opening: true)
    }
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PhotoTransition(source: imageView, opening: false)
    }
}

final class PhotoZoomController: UIViewController, UIScrollViewDelegate {
    let imageView: UIImageView
    let scroll = UIScrollView()
    private let closeButton = UIButton(type: .system)
    private let zoomButton = UIButton(type: .system)
    private var fittedBounds = CGSize.zero

    init(image: UIImage) {
        imageView = UIImageView(image: image)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        scroll.delegate = self
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.bouncesZoom = true
        scroll.accessibilityIdentifier = "photo.canvas"
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scroll.addSubview(imageView)
        view.addSubview(scroll)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        configure(closeButton, symbol: "xmark", label: "关闭照片", identifier: "photo.close", action: #selector(closePhoto))
        configure(zoomButton, symbol: "plus.magnifyingglass", label: "放大照片", identifier: "photo.zoom", action: #selector(toggleZoom))
    }

    private func configure(_ button: UIButton, symbol: String, label: String, identifier: String, action: Selector) {
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .white
        if #available(iOS 26.0, *) {
            var configuration = UIButton.Configuration.glass()
            configuration.image = UIImage(systemName: symbol)
            configuration.baseForegroundColor = .white
            configuration.cornerStyle = .capsule
            button.configuration = configuration
        } else {
            button.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            button.layer.cornerRadius = 24
        }
        button.accessibilityLabel = label
        button.accessibilityIdentifier = identifier
        button.addTarget(self, action: action, for: .touchUpInside)
        view.addSubview(button)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scroll.frame = view.bounds
        closeButton.frame = CGRect(x: view.bounds.width - view.safeAreaInsets.right - 64,
                                   y: view.safeAreaInsets.top + 12, width: 48, height: 48)
        zoomButton.frame = CGRect(x: view.safeAreaInsets.left + 16, y: view.safeAreaInsets.top + 12, width: 48, height: 48)
        guard fittedBounds != scroll.bounds.size, let image = imageView.image else { return }
        fittedBounds = scroll.bounds.size
        scroll.minimumZoomScale = 0.001
        scroll.maximumZoomScale = 10
        scroll.zoomScale = 1
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scroll.contentSize = image.size
        let fit = min(scroll.bounds.width / image.size.width, scroll.bounds.height / image.size.height)
        scroll.minimumZoomScale = fit
        scroll.maximumZoomScale = fit * 5
        scroll.zoomScale = fit
        centerImage()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }

    private func centerImage() {
        let x = max(0, (scroll.bounds.width - scroll.contentSize.width) / 2)
        let y = max(0, (scroll.bounds.height - scroll.contentSize.height) / 2)
        scroll.contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
        let zoomed = scroll.zoomScale > scroll.minimumZoomScale * 1.01
        zoomButton.accessibilityLabel = zoomed ? "还原照片" : "放大照片"
        zoomButton.accessibilityValue = zoomed ? "已放大" : "完整照片"
        let image = UIImage(systemName: zoomed ? "minus.magnifyingglass" : "plus.magnifyingglass")
        if var configuration = zoomButton.configuration { configuration.image = image; zoomButton.configuration = configuration }
        else { zoomButton.setImage(image, for: .normal) }
    }

    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) { zoom(at: gesture.location(in: imageView)) }
    @objc private func toggleZoom() {
        zoom(at: scroll.convert(CGPoint(x: scroll.bounds.midX, y: scroll.bounds.midY), to: imageView))
    }
    private func zoom(at point: CGPoint) {
        let animated = !UIAccessibility.isReduceMotionEnabled
        if scroll.zoomScale > scroll.minimumZoomScale * 1.01 {
            scroll.setZoomScale(scroll.minimumZoomScale, animated: animated)
        } else {
            let scale = scroll.minimumZoomScale * 2.5
            let size = CGSize(width: scroll.bounds.width / scale, height: scroll.bounds.height / scale)
            scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                  width: size.width, height: size.height), animated: animated)
        }
    }
    @objc private func closePhoto() { dismiss(animated: true) }
}

final class PhotoTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private weak var source: UIImageView?
    private let opening: Bool
    init(source: UIImageView, opening: Bool) { self.source = source; self.opening = opening }
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        UIAccessibility.isReduceMotionEnabled ? 0.18 : 0.32
    }
    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let viewer = context.viewController(forKey: opening ? .to : .from) as? PhotoZoomController else {
            context.completeTransition(false); return
        }
        let container = context.containerView
        if opening {
            viewer.view.frame = context.finalFrame(for: viewer)
            container.addSubview(viewer.view)
        }
        viewer.view.layoutIfNeeded()
        let canMove = !UIAccessibility.isReduceMotionEnabled && source?.window != nil
            && viewer.scroll.zoomScale <= viewer.scroll.minimumZoomScale * 1.01
        let snapshot = UIImageView(image: viewer.imageView.image)
        snapshot.contentMode = .scaleAspectFit
        let large = viewer.imageView.convert(viewer.imageView.bounds, to: container)
        let small = source.map { $0.convert($0.bounds, to: container) } ?? large
        if canMove {
            snapshot.frame = opening ? small : large
            container.addSubview(snapshot)
            viewer.imageView.isHidden = true
            source?.isHidden = true
        }
        viewer.view.alpha = opening ? 0 : 1
        UIView.animate(withDuration: transitionDuration(using: context), delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            viewer.view.alpha = self.opening ? 1 : 0
            snapshot.frame = self.opening ? large : small
        } completion: { _ in
            viewer.imageView.isHidden = false
            self.source?.isHidden = false
            snapshot.removeFromSuperview()
            context.completeTransition(!context.transitionWasCancelled)
        }
    }
}
