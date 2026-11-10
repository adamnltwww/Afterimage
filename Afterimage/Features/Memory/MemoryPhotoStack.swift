import SwiftUI
import UIKit
import ImageIO

private final class PhotoStackSurface: UIView {
    var containsPhoto: ((CGPoint) -> Bool)?
    var activate: (() -> Void)?
    var changePhoto: ((Int) -> Void)?
    override func accessibilityActivate() -> Bool { activate?(); return true }
    override func accessibilityIncrement() { changePhoto?(1) }
    override func accessibilityDecrement() { changePhoto?(-1) }
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        super.point(inside: point, with: event) && (containsPhoto?(point) ?? false)
    }
}

/// Shared, event-driven photo deck. The stored order and cover never change when browsing.
struct MemoryPhotoStack: UIViewControllerRepresentable {
    let cover: Data?
    let additional: Data?
    var opensPhoto = true
    var onTap: (() -> Void)?
    @Environment(\.afterimageReduceMotion) private var reduceMotion

    func makeUIViewController(context: Context) -> MemoryPhotoStackController { MemoryPhotoStackController() }
    func updateUIViewController(_ controller: MemoryPhotoStackController, context: Context) {
        controller.opensPhoto = opensPhoto
        controller.onTap = onTap
        controller.reduceMotion = reduceMotion
        controller.update(cover: cover, additional: additional)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: MemoryPhotoStackController, context: Context) -> CGSize? {
        let width = proposal.width ?? 300
        return CGSize(width: width, height: proposal.height ?? min(360, width * 0.9))
    }
}

final class MemoryPhotoStackController: UIViewController, UIGestureRecognizerDelegate, UIViewControllerTransitioningDelegate {
    var opensPhoto = true
    var onTap: (() -> Void)?
    var reduceMotion = false
    private var cover: Data?
    private var additional: Data?
    private var photos: [Data] = []
    private var images: [Int: UIImage] = [:]
    private var index = 0
    private var generation = UUID()
    private var pending = Set<Int>()
    private let cards = (0..<3).map { _ in UIImageView() }
    private let counter = UILabel()
    private var dragging = false
    private var photoPan: UIPanGestureRecognizer!
    private var turningPhoto: UIView?
    private var turnToken = UUID()
    private var hideCounter: DispatchWorkItem?

    override func loadView() {
        let surface = PhotoStackSurface()
        view = surface
        surface.activate = { [weak self] in self?.open() }
        surface.changePhoto = { [weak self] direction in self?.turn(direction) }
        surface.containsPhoto = { [weak self, weak surface] point in
            guard let self, let surface else { return false }
            return self.cards.contains { card in
                !card.isHidden && card.image != nil &&
                UIBezierPath(roundedRect: card.bounds, cornerRadius: 9)
                    .contains(card.convert(point, from: surface))
            }
        }
        view.backgroundColor = .clear
        for card in cards.reversed() {
            card.contentMode = .scaleAspectFit
            card.clipsToBounds = true
            card.layer.cornerRadius = 9
            card.layer.cornerCurve = .continuous
            view.addSubview(card)
        }
        counter.font = .preferredFont(forTextStyle: .caption2)
        counter.textColor = .secondaryLabel
        counter.textAlignment = .right
        counter.alpha = 0
        view.addSubview(counter)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        photoPan = pan
        pan.delegate = self
        view.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(open))
        tap.require(toFail: pan)
        view.addGestureRecognizer(tap)
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "photo.stack"
        view.accessibilityTraits = [.button, .adjustable]
        view.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "上一张照片", target: self, selector: #selector(showPreviousPhoto)),
            UIAccessibilityCustomAction(name: "下一张照片", target: self, selector: #selector(showNextPhoto))
        ]
    }

    func update(cover: Data?, additional: Data?) {
        loadViewIfNeeded()
        guard self.cover != cover || self.additional != additional else { return }
        self.cover = cover
        self.additional = additional
        photos = (cover.map { [$0] } ?? []) + (additional.flatMap { try? JSONDecoder().decode([Data].self, from: $0) } ?? [])
        index = 0
        hideCounter?.cancel()
        counter.alpha = 0
        turnToken = UUID()
        turningPhoto?.removeFromSuperview()
        turningPhoto = nil
        dragging = false
        cards.forEach { $0.layer.removeAllAnimations() }
        generation = UUID()
        pending.removeAll()
        images.removeAll()
        refresh()
    }

    private func photoIndex(_ depth: Int) -> Int { (index + depth) % max(1, photos.count) }

    private func refresh() {
        for depth in cards.indices {
            let position = photoIndex(depth)
            cards[depth].isHidden = depth >= photos.count
            cards[depth].image = images[position]
            if depth < photos.count { prepare(position) }
        }
        if photos.count > 1 { prepare((index - 1 + photos.count) % photos.count) }
        // Keep only the visible deck and its immediate predecessor decoded.
        let keep = Set((0..<min(3, photos.count)).map(photoIndex) + [((index - 1 + photos.count) % max(1, photos.count))])
        images = images.filter { keep.contains($0.key) }
        counter.text = photos.count > 1 ? "\(index + 1) / \(photos.count)" : nil
        view.accessibilityLabel = "照片，\(index + 1) / \(photos.count)"
        view.accessibilityValue = "\(index + 1)"
        view.accessibilityHint = opensPhoto ? "左右轻扫翻看，轻点放大" : "左右轻扫翻看，轻点查看瞬间"
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func prepare(_ position: Int) {
        guard images[position] == nil, !pending.contains(position) else { return }
        pending.insert(position)
        let data = photos[position]
        let token = generation
        let pixels = opensPhoto ? 1200 : 600
        Task { [weak self] in
            let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: pixels,
                        kCGImageSourceShouldCacheImmediately: true
                      ] as CFDictionary) else { return nil }
                return UIImage(cgImage: thumbnail)
            }.value
            guard let self, self.generation == token else { return }
            self.pending.remove(position)
            if let image { self.images[position] = image }
            for depth in self.cards.indices where self.photoIndex(depth) == position {
                self.cards[depth].image = image
            }
            self.view.setNeedsLayout()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Only touches which hit a real photo enter this recognizer. Give it first
        // refusal there; elsewhere the parent timeline scrolls immediately.
        var ancestor = view.superview
        while let current = ancestor {
            if let scroll = current as? UIScrollView {
                scroll.panGestureRecognizer.require(toFail: photoPan)
            }
            ancestor = current.superview
        }
        guard !dragging else { return }
        let stacked = photos.count > 1
        let showsCounter = stacked && view.bounds.height >= 70
        counter.isHidden = !showsCounter
        let spread = min(14, view.bounds.width * 0.065)
        let area = CGRect(x: stacked ? 4 : 0, y: stacked ? 12 : 0,
                          width: max(1, view.bounds.width - (stacked ? spread * 2 + 8 : 0)),
                          height: max(1, view.bounds.height - (showsCounter ? 42 : stacked ? 20 : 0)))
        for depth in cards.indices {
            let card = cards[depth]
            card.transform = .identity
            let size = card.image?.size ?? CGSize(width: 4, height: 3)
            let scale = min(area.width / max(1, size.width), area.height / max(1, size.height))
            let fitted = CGSize(width: size.width * scale, height: size.height * scale)
            card.bounds = CGRect(origin: .zero, size: fitted)
            card.center = CGPoint(x: area.minX + fitted.width / 2 + CGFloat(depth) * spread,
                                  y: area.midY - CGFloat(depth) * 4)
            card.layer.borderWidth = stacked ? 0.5 : 0
            card.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
            card.transform = restingTransform(depth)
        }
        positionCounter()
    }

    private func positionCounter() {
        counter.sizeToFit()
        let photo = cards[0].frame
        counter.frame = CGRect(x: photo.maxX - counter.bounds.width,
                               y: photo.maxY + 4, width: counter.bounds.width, height: 16)
    }

    private func revealCounter(hideAfterDelay: Bool) {
        hideCounter?.cancel()
        counter.layer.removeAllAnimations()
        counter.alpha = photos.count > 1 ? 1 : 0
        positionCounter()
        guard hideAfterDelay else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            UIView.animate(withDuration: 0.18) { self.counter.alpha = 0 }
        }
        hideCounter = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func restingTransform(_ depth: Int) -> CGAffineTransform {
        CGAffineTransform(rotationAngle: depth == 1 ? -0.075 : CGFloat(depth) * 0.06)
            .scaledBy(x: 1 - CGFloat(depth) * 0.025, y: 1 - CGFloat(depth) * 0.025)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        return photos.count > 1 && abs(velocity.x) > abs(velocity.y) * 1.2
    }

    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view).x
        switch gesture.state {
        case .began:
            revealCounter(hideAfterDelay: false)
            if let shown = cards[0].layer.presentation() { cards[0].transform = shown.affineTransform() }
            gesture.setTranslation(CGPoint(x: cards[0].transform.tx, y: 0), in: view)
            cards[0].layer.removeAllAnimations()
            dragging = true
        case .changed:
            cards[0].transform = reduceMotion ? .identity : CGAffineTransform(translationX: translation, y: -abs(translation) * 0.06)
                .rotated(by: translation / max(1, view.bounds.width) * 0.12)
            positionCounter()
        case .ended:
            let projected = translation + gesture.velocity(in: view).x * 0.16
            dragging = false
            if abs(projected) > max(32, view.bounds.width * 0.22) {
                turn(projected < 0 ? 1 : -1)
            } else { settle() }
        case .cancelled, .failed:
            dragging = false
            settle()
        default: break
        }
    }

    private func settle() {
        revealCounter(hideAfterDelay: true)
        UIView.animate(withDuration: reduceMotion ? 0 : 0.36, delay: 0,
                       usingSpringWithDamping: 0.86, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.cards[0].transform = .identity
            self.positionCounter()
        }
    }

    private func turn(_ direction: Int) {
        guard photos.count > 1 else { return }
        turnToken = UUID()
        let token = turnToken
        turningPhoto?.removeFromSuperview()
        let outgoing = cards[0].snapshotView(afterScreenUpdates: false)
        outgoing?.bounds = cards[0].bounds
        outgoing?.center = cards[0].center
        outgoing?.transform = cards[0].transform
        if let outgoing { outgoing.isUserInteractionEnabled = false; view.insertSubview(outgoing, belowSubview: counter) }
        turningPhoto = outgoing
        let incoming = cards[direction > 0 ? 1 : min(2, photos.count - 1)]
        let incomingCenter = incoming.center
        let incomingTransform = incoming.transform
        index = (index + direction + photos.count) % photos.count
        cards.forEach { $0.layer.removeAllAnimations() }
        refresh()
        revealCounter(hideAfterDelay: true)
        let frontCenter = cards[0].center
        if !reduceMotion {
            cards[0].center = incomingCenter
            cards[0].transform = incomingTransform
        }
        UIView.animate(withDuration: reduceMotion ? 0 : 0.24, delay: 0,
                       usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.cards[0].center = frontCenter
            self.cards[0].transform = .identity
            self.positionCounter()
            if !self.reduceMotion {
                outgoing?.transform = CGAffineTransform(translationX: -CGFloat(direction) * self.view.bounds.width * 0.8, y: -12)
                    .rotated(by: -CGFloat(direction) * 0.2)
            }
        } completion: { [weak self] _ in
            guard let self, self.turnToken == token, let outgoing else { return }
            // Change depth only once the photograph has cleared the front card,
            // then return it behind the deck at full opacity.
            self.view.insertSubview(outgoing, belowSubview: self.cards[min(2, self.photos.count - 1)])
            let back = self.cards[min(2, self.photos.count - 1)]
            UIView.animate(withDuration: self.reduceMotion ? 0 : 0.3, delay: 0,
                           usingSpringWithDamping: 0.88, initialSpringVelocity: 0,
                           options: [.beginFromCurrentState, .allowUserInteraction]) {
                outgoing.center = back.center
                outgoing.bounds = back.bounds
                outgoing.transform = back.transform
            } completion: { [weak self] _ in
                outgoing.removeFromSuperview()
                if self?.turnToken == token { self?.turningPhoto = nil }
            }
        }
    }

    @objc private func showPreviousPhoto() -> Bool { turn(-1); return true }
    @objc private func showNextPhoto() -> Bool { turn(1); return true }

    @objc private func open() {
        guard opensPhoto else { onTap?(); return }
        guard photos.indices.contains(index), presentedViewController == nil,
              let image = UIImage(data: photos[index]) else { return }
        let viewer = PhotoZoomController(image: image)
        viewer.modalPresentationStyle = .overFullScreen
        viewer.transitioningDelegate = self
        present(viewer, animated: true)
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PhotoTransition(source: cards[0], opening: true)
    }
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PhotoTransition(source: cards[0], opening: false)
    }
}
