import XCTest
import UIKit
@testable import Afterimage

@MainActor
final class PhotoStackTests: XCTestCase {
    func testLiveLayersKeepCenteredPileAndExchangeWithoutSnapshots() async throws {
        let deck = MemoryPhotoStackController()
        deck.update(cover: photo(.red), additional: try JSONEncoder().encode([photo(.green), photo(.blue)]))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 360)
        window.rootViewController = deck
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousKey?.makeKey() }
        try await Task.sleep(for: .milliseconds(250))
        deck.view.setNeedsLayout()
        deck.view.layoutIfNeeded()
        let original = deck.view.subviews.compactMap { $0 as? UIImageView }
        let front = try XCTUnwrap(original.last)
        XCTAssertEqual(front.center.x, deck.view.bounds.midX, accuracy: 0.5)
        let rear = original.filter { !$0.isHidden && $0 !== front }
        XCTAssertTrue(rear.contains { $0.center.x < front.center.x })
        XCTAssertTrue(rear.contains { $0.center.x > front.center.x })
        let identities = Set(original.map(ObjectIdentifier.init))
        deck.view.accessibilityIncrement()
        for frame in 0..<8 {
            try await Task.sleep(for: .milliseconds(90))
            XCTAssertEqual(Set(deck.view.subviews.compactMap { $0 as? UIImageView }.map(ObjectIdentifier.init)), identities)
            XCTAssertEqual(deck.view.subviews.count, 5, "Only live photo views and the counter should exist")
            let image = UIGraphicsImageRenderer(bounds: deck.view.bounds).image { context in
                (deck.view.layer.presentation() ?? deck.view.layer).render(in: context.cgContext)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "live-deck-\(frame)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertEqual(deck.view.accessibilityValue, "2")
        let newFront = try XCTUnwrap(deck.view.subviews.compactMap { $0 as? UIImageView }.last)
        XCTAssertFalse(front === newFront)
        XCTAssertEqual(newFront.center.x, deck.view.bounds.midX, accuracy: 0.5)
    }

    func testCounterFollowsPhotoAndHidesAfterBrowsingStops() async throws {
        let deck = MemoryPhotoStackController()
        deck.reduceMotion = true
        deck.update(cover: photo(.red), additional: try JSONEncoder().encode([photo(.green)]))
        deck.view.frame = CGRect(x: 0, y: 0, width: 168, height: 130)
        try await Task.sleep(for: .milliseconds(150))
        deck.view.layoutIfNeeded()
        let counter = try XCTUnwrap(deck.view.subviews.compactMap { $0 as? UILabel }.first)
        XCTAssertEqual(counter.alpha, 0)
        deck.view.accessibilityIncrement()
        XCTAssertEqual(counter.alpha, 1)
        let front = try XCTUnwrap(deck.view.subviews.compactMap { $0 as? UIImageView }.last)
        XCTAssertEqual(front.center.x, deck.view.bounds.midX, accuracy: 0.5, "The detail photo must be centered")
        XCTAssertEqual(counter.frame.maxX, front.frame.maxX, accuracy: 0.5)
        XCTAssertEqual(counter.frame.minY, front.frame.maxY + 4, accuracy: 0.5)
        try await Task.sleep(for: .milliseconds(1300))
        XCTAssertEqual(counter.alpha, 0)
    }

    private func photo(_ color: UIColor) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 80, height: 160)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 160))
        }.pngData()!
    }

    func testOnlyImagePixelsClaimTouchesAndTapKeepsTimelineAction() async throws {
        let deck = MemoryPhotoStackController()
        deck.opensPhoto = false
        var opened = false
        deck.onTap = { opened = true }
        deck.update(cover: photo(.red), additional: nil)
        deck.view.frame = CGRect(x: 0, y: 0, width: 168, height: 130)
        for _ in 0..<100 {
            if deck.view.subviews.compactMap({ $0 as? UIImageView }).contains(where: { $0.image != nil }) { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        deck.view.setNeedsLayout()
        deck.view.layoutIfNeeded()
        XCTAssertTrue(deck.view.point(inside: CGPoint(x: 84, y: 60), with: nil))
        XCTAssertFalse(deck.view.point(inside: CGPoint(x: 150, y: 60), with: nil), "Transparent space must belong to the timeline")
        XCTAssertFalse(deck.view.point(inside: CGPoint(x: 0, y: 0), with: nil), "Rounded corner must not intercept scrolling")
        XCTAssertTrue(deck.view.accessibilityActivate())
        XCTAssertTrue(opened)
    }

    func testBrowsingWrapsWithoutChangingCoverAndResetsAfterEdit() throws {
        let deck = MemoryPhotoStackController()
        deck.reduceMotion = true
        let cover = photo(.red)
        let additional = try JSONEncoder().encode([photo(.green), photo(.blue)])
        deck.update(cover: cover, additional: additional)
        deck.view.accessibilityIncrement()
        XCTAssertEqual(deck.view.accessibilityValue, "2")
        deck.update(cover: cover, additional: additional)
        XCTAssertEqual(deck.view.accessibilityValue, "2", "Unrelated timeline updates must preserve selection")
        deck.view.accessibilityDecrement()
        deck.view.accessibilityDecrement()
        XCTAssertEqual(deck.view.accessibilityValue, "3")
        deck.update(cover: cover, additional: nil)
        XCTAssertEqual(deck.view.accessibilityValue, "1")
    }
}

