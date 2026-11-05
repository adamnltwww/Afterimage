import XCTest

final class CollectionPresentationTests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-reading-fixture", "--ui-collection-fixture"]
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["library.more"].waitForExistence(timeout: 10))
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    private func more(_ title: String, app: XCUIApplication) {
        app.buttons["library.more"].tap()
        XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5))
        app.buttons[title].tap()
    }

    func testReviewSharePreviewAndLocalBackupEntry() {
        let app = launch()
        more("时间回顾与长图", app: app)
        XCTAssertTrue(app.staticTexts["review.count"].waitForExistence(timeout: 5))
        capture(app, "review-time-range")
        let export = app.buttons["review.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.tap()
        XCTAssertTrue(app.navigationBars["长图预览"].waitForExistence(timeout: 10))
        capture(app, "memory-long-image-preview")
        app.buttons["返回"].tap()
        app.buttons["完成"].tap()
        more("iCloud 备份与恢复", app: app)
        XCTAssertTrue(app.buttons["backup.export"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["backup.import"].exists)
        capture(app, "icloud-backup-entry")
    }

    func testMultiplePhotosAndParallelThreads() {
        let app = launch()
        app.buttons["timeline.index"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "index.memory.")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5)); first.tap()
        let photos = app.buttons.matching(identifier: "photo.open")
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(photos.count, 3)
        photos.firstMatch.tap()
        XCTAssertTrue(app.buttons["photo.close"].waitForExistence(timeout: 5)); app.buttons["photo.close"].tap()
        capture(app, "multiple-photo-reading")
        app.navigationBars["瞬间"].buttons["完成"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.navigationBars["瞬间"])
        waitForExpectations(timeout: 5)
        app.navigationBars["时间索引"].buttons["完成"].tap()
        more("并行抽丝", app: app)
        XCTAssertTrue(app.navigationBars["并行抽丝"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["收回Lake"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["收回Walk"].exists)
        XCTAssertEqual(app.scrollViews["compare.canvas"].buttons.matching(NSPredicate(format: "label == %@", "瞬间：Lake morning")).count, 1, "Shared moments should appear once in the common canvas")
        capture(app, "parallel-threads")
        app.swipeLeft()
        capture(app, "parallel-threads-scrolled")
        app.buttons["完成"].tap()
        more("主题管理", app: app)
        XCTAssertTrue(app.navigationBars["主题管理"].waitForExistence(timeout: 5))
        capture(app, "theme-management")
    }
}
