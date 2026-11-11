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

/// Where one sheet of the pile sits: position, scale, tilt and opacity.
private struct DeckPose {
    var center: CGPoint
    var scale: CGFloat
    var angle: CGFloat
    var alpha: CGFloat

    func mixed(with other: DeckPose, _ t: CGFloat) -> DeckPose {
        let k = min(1, max(0, t))
        return DeckPose(
            center: CGPoint(x: center.x + (other.center.x - center.x) * k,
                            y: center.y + (other.center.y - center.y) * k),
            scale: scale + (other.scale - scale) * k,
            angle: angle + (other.angle - angle) * k,
            alpha: alpha + (other.alpha - alpha) * k
        )
    }
}

/// A pile of photos, not a carousel.
///
/// Dragging left carries the top sheet away and drops it onto the back of the pile;
/// the sheet underneath rises while the finger is still moving. Dragging right pulls
/// the buried sheet up from under the stack and lays it on top. Depth order is the
/// only state: `cards[0]` is the sheet the reader sees, `cards[3]` is the one waiting
/// beneath the pile, and a turn recycles views instead of rebuilding them.
final class MemoryPhotoStackController: UIViewController, UIGestureRecognizerDelegate, UIViewControllerTransitioningDelegate {
    var opensPhoto = true
    var onTap: (() -> Void)?
    var reduceMotion = false

    private enum Drag {
        case idle
        case carrying   // finger left: the front sheet is being carried off the pile
        case lifting    // finger right: the buried sheet is being drawn up
    }

    private var cover: Data?
    private var additional: Data?
    private var photos: [Data] = []
    private var images: [Int: UIImage] = [:]
    private var index = 0
    private var generation = UUID()
    private var pending = Set<Int>()
    private var incomingPosition: Int?

    private var cards = (0..<4).map { _ in UIImageView() }
    private let counter = UILabel()

    private var drag: Drag = .idle
    private var turning = false
    private var turnToken = UUID()
    private var photoPan: UIPanGestureRecognizer!
    private var hideCounter: DispatchWorkItem?

    private var footprint = CGSize(width: 4, height: 3)
    private var homeCenter = CGPoint.zero
    private var spread: CGFloat = 0

    private var visibleLayers: Int { min(3, photos.count) }
    private var busy: Bool { drag != .idle || turning }
    private var commitDistance: CGFloat { min(96, max(44, view.bounds.width * 0.28)) }

    // MARK: - Lifecycle

    override func loadView() {
        let surface = PhotoStackSurface()
        view = surface
        surface.activate = { [weak self] in self?.open() }
        surface.changePhoto = { [weak self] direction in self?.turn(direction) }
        surface.containsPhoto = { [weak self, weak surface] point in
            guard let self, let surface else { return false }
            return self.cards.contains { card in
                !card.isHidden && card.image != nil && card.alpha > 0.05 &&
                UIBezierPath(roundedRect: card.bounds, cornerRadius: 9)
                    .contains(card.convert(point, from: surface))
            }
        }
        view.backgroundColor = .clear
        for card in cards.reversed() {
            card.contentMode = .scaleAspectFill
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
        drag = .idle
        turning = false
        turnToken = UUID()
        incomingPosition = nil
        hideCounter?.cancel()
        counter.alpha = 0
        cards.forEach {
            $0.layer.removeAllAnimations()
            $0.alpha = 1
        }
        generation = UUID()
        pending.removeAll()
        images.removeAll()
        restack()
        refresh()
    }

    // MARK: - Geometry

    private func restPose(_ depth: Int) -> DeckPose {
        switch depth {
        case 0:
            return DeckPose(center: homeCenter, scale: 1, angle: 0, alpha: 1)
        case 1:
            return DeckPose(center: CGPoint(x: homeCenter.x - spread * 0.3, y: homeCenter.y - 5),
                            scale: 0.962, angle: -0.024, alpha: 1)
        case 2:
            return DeckPose(center: CGPoint(x: homeCenter.x + spread * 0.3, y: homeCenter.y - 10),
                            scale: 0.924, angle: 0.022, alpha: 1)
        default:
            // Not a resting slot: where a sheet waits before it is drawn up over the pile.
            return DeckPose(center: CGPoint(x: homeCenter.x - 10, y: homeCenter.y + 26),
                            scale: 0.9, angle: -0.012, alpha: 0)
        }
    }

    private func apply(_ pose: DeckPose, to card: UIImageView) {
        card.center = pose.center
        card.transform = CGAffineTransform(rotationAngle: pose.angle).scaledBy(x: pose.scale, y: pose.scale)
        card.alpha = pose.alpha
    }

    private func ease(_ p: CGFloat) -> CGFloat {
        let k = min(1, max(0, p))
        return 1 - (1 - k) * (1 - k)
    }

    private func photoIndex(_ depth: Int) -> Int { (index + depth) % max(1, photos.count) }

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
        guard !busy else { return }
        layoutDeck()
    }

    private func layoutDeck() {
        let stacked = photos.count > 1
        let showsCounter = stacked && view.bounds.height >= 70
        counter.isHidden = !showsCounter
        spread = min(14, view.bounds.width * 0.065)
        let areaWidth = max(1, view.bounds.width - (stacked ? spread * 2 + 8 : 0))
        let area = CGRect(x: (view.bounds.width - areaWidth) / 2,
                          y: stacked ? 12 : 0,
                          width: areaWidth,
                          height: max(1, view.bounds.height - (showsCounter ? 42 : stacked ? 20 : 0)))
        homeCenter = CGPoint(x: area.midX, y: area.midY)
        // One shared footprint for every sheet: mixed portrait and landscape photos
        // must not resize the pile when a layer comes forward.
        let source = images[0]?.size ?? CGSize(width: 4, height: 3)
        let fit = min(area.width / max(1, source.width), area.height / max(1, source.height))
        footprint = CGSize(width: source.width * fit, height: source.height * fit)
        for (depth, card) in cards.enumerated() {
            card.layer.removeAllAnimations()
            card.bounds = CGRect(origin: .zero, size: footprint)
            card.layer.borderWidth = stacked ? 0.5 : 0
            card.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
            apply(restPose(depth), to: card)
        }
        restack()
        positionCounter()
    }

    // MARK: - Content

    private func refresh() {
        let layers = visibleLayers
        for depth in cards.indices {
            let position = photoIndex(depth)
            cards[depth].isHidden = depth >= layers
            cards[depth].image = images[position]
            if depth < layers || depth == 3 { prepare(position) }
        }
        if photos.count > 1 { prepare(photoIndex(photos.count - 1)) }
        // Keep only the visible pile and its immediate neighbours decoded.
        let keep = Set((0..<4).map(photoIndex) + [photoIndex(max(1, photos.count) - 1)])
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
            guard let image else { return }
            self.images[position] = image
            if self.incomingPosition == position { self.cards[3].image = image }
            for depth in self.cards.indices where !self.busy && self.photoIndex(depth) == position {
                self.cards[depth].image = image
            }
            self.view.setNeedsLayout()
        }
    }

    // MARK: - Counter

    private func positionCounter() {
        guard !counter.isHidden else { return }
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

    // MARK: - Gesture

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        return photos.count > 1 && abs(velocity.x) > abs(velocity.y) * 1.2
    }

    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view).x
        switch gesture.state {
        case .began:
            beginDrag(gesture)
        case .changed:
            if drag == .idle {
                guard abs(translation) > 3 else { return }
                drag = translation < 0 ? .carrying : .lifting
                if drag == .lifting { liftIncomingSheet() }
            }
            let p = drag == .carrying
                ? min(1, max(0, -translation) / commitDistance)
                : min(1, max(0, translation) / commitDistance)
            if drag == .carrying { renderCarry(p, translation: translation) }
            else if drag == .lifting { renderLift(p) }
        case .ended:
            finishDrag(translation: translation, velocity: gesture.velocity(in: view).x)
        case .cancelled, .failed:
            settleBack()
        default:
            break
        }
    }

    private func beginDrag(_ gesture: UIPanGestureRecognizer) {
        if turning {
            // A second gesture interrupts the tail of a turn: land it where it was going.
            turnToken = UUID()
            turning = false
            for card in cards { card.layer.removeAllAnimations() }
            layoutDeck()
        }
        revealCounter(hideAfterDelay: false)
        gesture.setTranslation(CGPoint(x: cards[0].center.x - homeCenter.x, y: 0), in: view)
    }

    /// Left drag: the front sheet follows the finger and the pile rises underneath it.
    private func renderCarry(_ p: CGFloat, translation: CGFloat) {
        let e = ease(p)
        let travel = max(-commitDistance, min(0, translation))
        var front = restPose(0)
        front.center = CGPoint(x: homeCenter.x + travel, y: homeCenter.y + abs(travel) * 0.02)
        front.scale = 1 - 0.05 * p
        front.angle = -0.11 * p
        front.alpha = 1 - 0.1 * p
        apply(front, to: cards[0])
        apply(restPose(1).mixed(with: restPose(0), e), to: cards[1])
        apply(restPose(2).mixed(with: restPose(1), e), to: cards[2])
        positionCounter()
    }

    /// Right drag: the buried sheet is drawn up from under the pile and laid on top.
    private func renderLift(_ p: CGFloat) {
        let e = ease(p)
        var incoming = restPose(3).mixed(with: restPose(0), e)
        incoming.alpha = min(1, p * 6)
        apply(incoming, to: cards[3])
        apply(restPose(0).mixed(with: restPose(1), e), to: cards[0])
        apply(restPose(1).mixed(with: restPose(2), e), to: cards[1])
        var leaving = restPose(2).mixed(with: restPose(3), e)
        leaving.alpha = max(0, 1 - e * 1.4)
        apply(leaving, to: cards[2])
        positionCounter()
    }

    private func liftIncomingSheet() {
        guard photos.count > 1 else { return }
        let position = photoIndex(photos.count - 1)
        let card = cards[3]
        if images[position] == nil { prepare(position) }
        incomingPosition = position
        card.image = images[position]
        card.isHidden = false
        apply(restPose(3), to: card)
        card.alpha = 0
        view.bringSubviewToFront(card)
        view.bringSubviewToFront(counter)
    }

    private func finishDrag(translation: CGFloat, velocity: CGFloat) {
        let direction = drag
        drag = .idle
        guard direction != .idle else { settleBack(); return }
        let projected = translation + velocity * 0.14
        let threshold = max(34, view.bounds.width * 0.18)
        let committed = direction == .carrying ? projected < -threshold : projected > threshold
        if committed {
            turn(direction == .carrying ? 1 : -1)
        } else {
            settleBack()
        }
    }

    private func settleBack() {
        drag = .idle
        guard photos.count > 1, !turning else { return }
        turning = true
        let token = UUID()
        turnToken = token
        UIView.animate(withDuration: 0.34, delay: 0,
                       usingSpringWithDamping: 0.86, initialSpringVelocity: 0.2,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            for depth in self.cards.indices { self.apply(self.restPose(depth), to: self.cards[depth]) }
        } completion: { [weak self] _ in
            guard let self, self.turnToken == token else { return }
            self.turning = false
            self.incomingPosition = nil
            self.restack()
            self.refresh()
        }
        revealCounter(hideAfterDelay: true)
    }

    // MARK: - Turns

    private func turn(_ direction: Int) {
        guard photos.count > 1 else { return }
        if reduceMotion {
            drag = .idle
            index = (index + direction + photos.count) % photos.count
            refresh()
            revealCounter(hideAfterDelay: true)
            return
        }
        guard !turning else { return }
        if direction < 0 && drag != .lifting {
            liftIncomingSheet()
        }
        drag = .idle
        turning = true
        let token = UUID()
        turnToken = token
        revealCounter(hideAfterDelay: true)

        if direction > 0 { carryToBack(token) } else { liftToFront(token) }
    }

    /// Left: the front sheet leaves, lands on the back of the pile, the next one takes its place.
    private func carryToBack(_ token: UUID) {
        let leaving = cards[0]
        index = (index + 1) % photos.count
        cards = [cards[1], cards[2], leaving, cards[3]]
        updateCounterText()
        view.bringSubviewToFront(leaving)
        view.bringSubviewToFront(counter)

        UIView.animate(withDuration: 0.24, delay: 0,
                       options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]) {
            leaving.center = CGPoint(x: self.homeCenter.x - self.view.bounds.width * 0.55,
                                     y: self.homeCenter.y - 4)
            leaving.transform = CGAffineTransform(rotationAngle: -0.22).scaledBy(x: 0.93, y: 0.93)
            leaving.alpha = 0
        }
        UIView.animate(withDuration: 0.44, delay: 0,
                       usingSpringWithDamping: 0.84, initialSpringVelocity: 0.25,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.apply(self.restPose(0), to: self.cards[0])
            self.apply(self.restPose(1), to: self.cards[1])
        } completion: { [weak self] _ in
            guard let self, self.turnToken == token else { return }
            self.turning = false
            self.restack()
            self.refresh()
        }
        // The sheet is out of frame before it re-enters at the back, so the wrap is never
        // seen as a return trip across the pile.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { [weak self] in
            guard let self, self.turnToken == token else { return }
            self.recycle(leaving, depth: 2)
        }
    }

    /// Right: the buried sheet rises over the pile while the others settle back one place.
    private func liftToFront(_ token: UUID) {
        let incoming = cards[3]
        index = (index - 1 + photos.count) % photos.count
        cards = [incoming, cards[0], cards[1], cards[2]]
        updateCounterText()
        view.bringSubviewToFront(incoming)
        view.bringSubviewToFront(counter)

        UIView.animate(withDuration: 0.46, delay: 0,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.3,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.apply(self.restPose(0), to: incoming)
            self.apply(self.restPose(1), to: self.cards[1])
            self.apply(self.restPose(2), to: self.cards[2])
            self.apply(self.restPose(3), to: self.cards[3])
        } completion: { [weak self] _ in
            guard let self, self.turnToken == token else { return }
            self.turning = false
            self.incomingPosition = nil
            self.restack()
            self.refresh()
        }
    }

    private func recycle(_ card: UIImageView, depth: Int) {
        let position = photoIndex(depth)
        card.image = images[position]
        prepare(position)
        apply(restPose(depth), to: card)
        card.alpha = 0
        card.isHidden = depth >= visibleLayers
        restack()
        UIView.animate(withDuration: 0.18, delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            card.alpha = 1
        }
    }

    private func updateCounterText() {
        counter.text = "\(index + 1) / \(photos.count)"
        view.accessibilityValue = "\(index + 1)"
    }

    /// Layer order is depth order: cards[0] on top, the waiting sheet at the bottom.
    private func restack() {
        for card in cards.reversed() { view.insertSubview(card, belowSubview: counter) }
    }

    @objc private func showPreviousPhoto() -> Bool { turn(-1); return true }
    @objc private func showNextPhoto() -> Bool { turn(1); return true }

    // MARK: - Opening

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
