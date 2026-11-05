import XCTest

final class ThemeSuggestionPresentationTests: XCTestCase {
    func testAutomaticSelectionCanBeRemovedAndStaysRemovedWhenEditing() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["memory.add"].waitForExistence(timeout: 10))
        app.buttons["memory.add"].tap()
        let title = app.descendants(matching: .any).matching(identifier: "memory.title").firstMatch
        title.tap()
        title.typeText("Camera at Lake")
        let lake = app.buttons["memory.suggestion.湖边"]
        XCTAssertTrue(lake.waitForExistence(timeout: 8))
        app.swipeUp()
        XCTAssertEqual(lake.value as? String, "已选中")
        lake.tap()
        XCTAssertEqual(lake.value as? String, "未选中")
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "automatic-theme-choices"
        image.lifetime = .keepAlways
        add(image)
        let save = app.buttons["memory.save"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 5)
        save.tap()
        let node = app.descendants(matching: .any).matching(identifier: "timeline.node").firstMatch
        XCTAssertTrue(node.waitForExistence(timeout: 5))
        node.tap()
        XCTAssertTrue(app.buttons["memory.theme.摄影"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["memory.theme.湖边"].exists)
        app.buttons["memory.edit"].tap()
        XCTAssertTrue(lake.waitForExistence(timeout: 5))
        XCTAssertEqual(lake.value as? String, "未选中")
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 5)
        save.tap()
        XCTAssertTrue(app.buttons["memory.theme.摄影"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["memory.theme.湖边"].exists)
    }
}
