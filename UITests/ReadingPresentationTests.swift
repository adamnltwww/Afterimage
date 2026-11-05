import XCTest

final class ReadingPresentationTests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-reading-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["timeline.index"].waitForExistence(timeout: 10))
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func search(_ query: String, in app: XCUIApplication) {
        app.buttons["timeline.index"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(query)
    }

    func testThemeRenameReadingAndReturnPreserveExtraction() {
        let app = launch()
        app.buttons["thread.themePicker"].tap()
        app.buttons["thread.theme.lake"].tap()
        app.buttons["thread.toggle"].tap()
        let node = app.descendants(matching: .any).matching(identifier: "timeline.node").matching(NSPredicate(format: "label CONTAINS %@", "Lake return")).firstMatch
        expectation(for: NSPredicate(format: "value == %@", "已抽出"), evaluatedWith: node)
        waitForExpectations(timeout: 8)
        let before = app.descendants(matching: .any).matching(identifier: "timeline.progress").firstMatch.value as? String
        capture(app, "compact-axis-extracted")
        app.buttons["theme.open"].tap()
        XCTAssertTrue(app.staticTexts["theme.heading"].waitForExistence(timeout: 5))
        capture(app, "theme-reading-photo")
        app.buttons["theme.rename"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "Water")
        app.alerts.buttons["保存"].tap()
        XCTAssertEqual(app.staticTexts["theme.heading"].label, "Water")
        app.buttons["theme.close"].tap()
        XCTAssertTrue(app.buttons["thread.themePicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["thread.themePicker"].label.contains("Water"))
        XCTAssertEqual(node.value as? String, "已抽出")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "timeline.progress").firstMatch.value as? String, before)
        app.buttons["thread.themePicker"].tap(); app.buttons["thread.theme.solo"].tap()
        XCTAssertFalse(app.buttons["thread.toggle"].isEnabled)
        app.buttons["theme.open"].tap()
        XCTAssertTrue(app.staticTexts["A quiet page"].waitForExistence(timeout: 5))
    }

    func testBodySearchPhotoZoomPanAndClose() {
        let app = launch()
        let indexFrame = app.buttons["timeline.index"].frame
        app.swipeUp()
        XCTAssertEqual(app.buttons["timeline.index"].frame.minY, indexFrame.minY, accuracy: 1, "The library must not scroll vertically")
        capture(app, "compact-axis-one-screen")
        search("hiddenkeyword", in: app)
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "index.memory.", "Lake morning")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "index.memory.")).count, 1)
        capture(app, "index-body-match")
        result.tap()
        let photo = app.buttons["photo.open"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        capture(app, "detail-photo-reading")
        photo.tap()
        let zoom = app.buttons["photo.zoom"]
        XCTAssertTrue(zoom.waitForExistence(timeout: 5))
        zoom.tap()
        expectation(for: NSPredicate(format: "value == %@", "已放大"), evaluatedWith: zoom)
        waitForExpectations(timeout: 3)
        app.scrollViews["photo.canvas"].swipeLeft()
        XCTAssertTrue(app.buttons["photo.close"].exists)
        capture(app, "photo-zoomed")
        zoom.tap()
        expectation(for: NSPredicate(format: "value == %@", "完整照片"), evaluatedWith: zoom)
        waitForExpectations(timeout: 3)
        capture(app, "photo-full-ratio")
        app.buttons["photo.close"].tap()
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        app.buttons["完成"].firstMatch.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "hiddenkeyword")
    }

    func testManualExplanationCanBeEditedFromEitherSide() {
        let app = launch()
        search("Lake return", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "index.memory.", "Lake return")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["link.savedNote"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["共同主题 · Lake"].exists)
        app.buttons["管理手动关联"].tap()
        app.buttons["编辑说明"].tap()
        let note = app.descendants(matching: .any).matching(identifier: "link.note").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("Three months later. ")
        app.buttons["link.save"].tap()
        XCTAssertTrue(app.staticTexts["link.savedNote"].waitForExistence(timeout: 5))
        let saved = app.staticTexts["link.savedNote"].label
        XCTAssertTrue(saved.contains("Three months later."))
        XCTAssertTrue(saved.contains("Same place, another season."))
        capture(app, "manual-and-theme-sources")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "related.")).firstMatch.tap()
        for _ in 0..<4 {
            if app.staticTexts.matching(identifier: "link.savedNote").allElementsBoundByIndex.contains(where: { $0.isHittable }) { break }
            app.swipeUp()
        }
        let explanation = app.staticTexts.matching(identifier: "link.savedNote").allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertEqual(explanation?.label, saved)
        app.buttons.matching(identifier: "管理手动关联").allElementsBoundByIndex.first { $0.isHittable }?.tap()
        app.buttons["移除手动关联"].tap()
        XCTAssertEqual(app.staticTexts.matching(identifier: "link.savedNote").count, 0)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "共同主题 · Lake")).firstMatch.exists)
    }
}
