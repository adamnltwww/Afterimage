import XCTest
import UIKit
@testable import Afterimage

@MainActor
final class PhotoStackTests: XCTestCase {
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
        XCTAssertTrue(deck.view.point(inside: CGPoint(x: 30, y: 60), with: nil))
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
