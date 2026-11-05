import XCTest

final class OpeningAnimationTests: XCTestCase {
    func testSilkOpeningFinishesOnUsableTimeline() {
        let app = launchOpening()
        // Native toolbar elements can exist in AX before their fade has finished.
        // Wait for the full ending, rather than treating existence as readiness.
        expectation(for: NSPredicate { _, _ in
            !app.buttons["opening.skip"].exists && app.buttons["timeline.index"].isHittable
        }, evaluatedWith: app)
        waitForExpectations(timeout: 15)
        XCTAssertFalse(app.buttons["opening.skip"].exists)
        XCTAssertTrue(app.buttons["memory.add"].isHittable)
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
