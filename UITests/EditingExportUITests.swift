import XCTest

final class EditingExportUITests: XCTestCase {
    func testDraftResumesAndIndexSeparators() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-reading-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["memory.add"].waitForExistence(timeout: 10))
        app.buttons["memory.add"].tap()
        let input = app.descendants(matching: .any).matching(identifier: "memory.title").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("Draft continuity")
        app.buttons["memory.cancel"].tap()
        app.buttons["保存草稿并退出"].tap()
        XCTAssertTrue(app.buttons["memory.add"].waitForExistence(timeout: 5))
        app.buttons["memory.add"].tap()
        XCTAssertTrue(app.staticTexts["已恢复上次草稿"].waitForExistence(timeout: 5))
        XCTAssertTrue(String(describing: input.value ?? "").contains("Draft continuity"))
        app.buttons["memory.cancel"].tap()
        app.buttons.matching(identifier: "memory.discard").firstMatch.tap()
        app.buttons["timeline.index"].tap()
        XCTAssertTrue(app.navigationBars["时间索引"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "index-aligned-separators"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
}
