import XCTest
import UIKit

final class OpeningAnimationTests: XCTestCase {
    func testSilkOpeningFinishesOnUsableTimeline() throws {
        let app = launchOpening()
        // Native toolbar elements can exist in AX before their fade has finished.
        // Wait for the full ending, rather than treating existence as readiness.
        expectation(for: NSPredicate { _, _ in
            !app.buttons["opening.skip"].exists && app.buttons["timeline.index"].isHittable
        }, evaluatedWith: app)
        waitForExpectations(timeout: 15)
        XCTAssertFalse(app.buttons["opening.skip"].exists)
        XCTAssertTrue(app.buttons["memory.add"].isHittable)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "timeline.progress").count, 1,
                       "The landing must leave exactly one persistent wordmark")
        let wordmark = app.descendants(matching: .any).matching(identifier: "timeline.progress").firstMatch
        try assertVisibleTitleAlignsWithButton(app, wordmark: wordmark)
        capture(app, "opening-landed-on-real-timeline")
        app.buttons["timeline.index"].tap()
        XCTAssertTrue(app.navigationBars["时间索引"].waitForExistence(timeout: 5))
    }

    func testSkipImmediatelyReleasesUnderlyingControls() {
        let app = launchOpening(hold: true)
        let skip = app.buttons["opening.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        capture(app, "opening-real-silk-formation")
        XCTAssertFalse(app.buttons["memory.add"].isHittable)
        skip.tap()
        XCTAssertTrue(app.buttons["timeline.index"].waitForExistence(timeout: 5))
        app.buttons["memory.add"].tap()
        XCTAssertTrue(app.buttons["memory.cancel"].waitForExistence(timeout: 5))
    }

    func testBackgroundingDoesNotReplayOrLeaveOpeningOverTimeline() {
        let app = launchOpening(hold: true)
        XCTAssertTrue(app.buttons["opening.skip"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["timeline.index"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["opening.skip"].exists)
        XCTAssertTrue(app.buttons["memory.add"].isHittable)
        capture(app, "opening-resume-enters-timeline")
    }

    private func assertVisibleTitleAlignsWithButton(_ app: XCUIApplication, wordmark: XCUIElement) throws {
        // Text's AX box includes baseline space; compare the actual gold cap-height ink.
        let image = try XCTUnwrap(app.screenshot().image.cgImage)
        let width = image.width, height = image.height
        let scale = CGFloat(width) / app.frame.width
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        func inkCenter(in rect: CGRect, flipped: Bool) -> CGFloat? {
            var top = height, bottom = -1
            for y in max(0, Int(rect.minY * scale))..<min(height, Int(ceil(rect.maxY * scale))) {
                for x in max(0, Int(rect.minX * scale))..<min(width, Int(ceil(rect.maxX * scale))) {
                    let index = ((flipped ? height - 1 - y : y) * width + x) * 4
                    let r = Double(bytes[index]), g = Double(bytes[index + 1]), b = Double(bytes[index + 2])
                    if r > 140, g > 90, r > g * 1.03, g > b * 1.1 { top = min(top, y); bottom = max(bottom, y) }
                }
            }
            return bottom >= top ? CGFloat(top + bottom) / (2 * scale) : nil
        }
        let button = app.buttons["memory.add"].frame
        let flipped = inkCenter(in: button, flipped: false) == nil
        let buttonCenter = try XCTUnwrap(inkCenter(in: button, flipped: flipped))
        let titleCenter = try XCTUnwrap(inkCenter(in: wordmark.frame.insetBy(dx: -2, dy: -6), flipped: flipped))
        XCTAssertEqual(titleCenter, buttonCenter, accuracy: 1, "Visible capitals and toolbar symbols must share a centreline")
    }

    private func launchOpening(hold: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-reading-fixture", "--ui-opening"]
        if hold { app.launchArguments.append("--ui-opening-hold") }
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
