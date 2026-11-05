import XCTest

final class DemoPresentationTests: XCTestCase {
    func testTitleOnlyTimelineAndEditableThemeColor() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["memory.add"].waitForExistence(timeout: 10))
        app.buttons["memory.add"].tap()
        let title = app.descendants(matching: .any).matching(identifier: "memory.title").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Evening light")
        let body = app.descendants(matching: .any).matching(identifier: "memory.text").firstMatch
        body.tap()
        body.typeText("The complete story belongs in the detail view, away from the timeline.")
        let tags = app.textFields["memory.tags"]
        tags.tap()
        tags.typeText("Lake")
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["memory.save"])
        waitForExpectations(timeout: 5)
        app.buttons["memory.save"].tap()
        let node = app.descendants(matching: .any).matching(identifier: "timeline.node").firstMatch
        XCTAssertTrue(node.waitForExistence(timeout: 5))
        XCTAssertTrue(node.label.contains("Evening light"))
        XCTAssertTrue(app.staticTexts["The complete story belongs in the detail view, away from the timeline."].exists, "Short body previews now appear beneath an independent title")
        node.tap()
        XCTAssertTrue(app.staticTexts["memory.body"].waitForExistence(timeout: 5))
        let picker = app.buttons.matching(identifier: "theme.colorPicker").firstMatch
        picker.tap()
        app.buttons["theme.color.4"].tap()
        XCTAssertTrue(picker.label.contains("玫瑰"))
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "title-body-theme-color"
        image.lifetime = .keepAlways
        add(image)
    }

    func testPhotoAspectAndSilkComposition() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-visual-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["timeline.index"].waitForExistence(timeout: 10))
        for label in ["最早", "最近"] {
            jump(label, in: app)
            let progress = app.descendants(matching: .any).matching(identifier: "timeline.progress").firstMatch
            expectation(for: NSPredicate(format: "value == %@", label == "最早" ? "0%" : "100%"), evaluatedWith: progress)
            waitForExpectations(timeout: 5)
            let image = XCTAttachment(screenshot: app.screenshot())
            image.name = "photo-composition-\(label)"
            image.lifetime = .keepAlways
            add(image)
        }
    }
    func testOpeningAndWordmarkBrowsingProgress() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-stress", "--ui-opening"]
        app.launch()
        // Let the finite opening finish; its skip button can disappear between discovery and tap.
        XCTAssertTrue(app.buttons["timeline.index"].waitForExistence(timeout: 15))
        jump("最早", in: app)
        let progress = app.descendants(matching: .any).matching(identifier: "timeline.progress").firstMatch
        expectation(for: NSPredicate(format: "value == %@", "0%"), evaluatedWith: progress)
        waitForExpectations(timeout: 5)
        let first = XCTAttachment(screenshot: app.screenshot())
        first.name = "silk-axis-earliest"
        first.lifetime = .keepAlways
        add(first)
        jump("最近", in: app)
        expectation(for: NSPredicate(format: "value == %@", "100%"), evaluatedWith: progress)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.staticTexts["那些留下来的瞬间。"].exists)
        let last = XCTAttachment(screenshot: app.screenshot())
        last.name = "silk-axis-latest"
        last.lifetime = .keepAlways
        add(last)
    }
    func testLongTimelineCanReachBothEndsAndPullThread() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-stress"]
        app.launch()
        XCTAssertTrue(app.buttons["timeline.index"].waitForExistence(timeout: 15))
        jump("最早", in: app)
        let first = app.descendants(matching: .any).matching(identifier: "timeline.node")
            .matching(NSPredicate(format: "label ENDSWITH %@", "Stress memory 0")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(app.staticTexts["Stress memory 0"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
        jump("最近", in: app)
        let last = app.descendants(matching: .any).matching(identifier: "timeline.node")
            .matching(NSPredicate(format: "label ENDSWITH %@", "Stress memory 199")).firstMatch
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        last.tap()
        XCTAssertTrue(app.staticTexts["Stress memory 199"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
        app.buttons["thread.themePicker"].tap()
        app.buttons["thread.theme.摄影"].tap()
        app.buttons["thread.toggle"].tap()
        expectation(for: NSPredicate(format: "value == %@", "已抽出"), evaluatedWith: last)
        waitForExpectations(timeout: 8)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "stress-200-extracted"
        image.lifetime = .keepAlways
        add(image)
    }
    func testEmptyDraftDiscardAndDeletingLastMemory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["memory.add"].waitForExistence(timeout: 10))
        app.buttons["memory.add"].tap()
        let save = app.buttons["memory.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        let text = app.descendants(matching: .any).matching(identifier: "memory.text").firstMatch
        text.tap()
        text.typeText("Unsaved draft")
        app.buttons["memory.cancel"].tap()
        app.buttons.matching(identifier: "memory.discard").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["从一个瞬间开始。"].waitForExistence(timeout: 5))
        app.buttons["memory.add"].tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "Discarded text must not leak into a new draft")
        text.tap()
        text.typeText("Boundary memory")
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 5)
        save.tap()
        let node = app.descendants(matching: .any).matching(identifier: "timeline.node")
            .matching(NSPredicate(format: "label CONTAINS %@", "Boundary memory")).firstMatch
        XCTAssertTrue(node.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["thread.themePicker"].exists)
        node.tap()
        let delete = app.buttons["memory.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        app.buttons.matching(identifier: "memory.confirmDelete").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["从一个瞬间开始。"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "timeline.node").firstMatch.exists)
    }
    func testThreadDragButtonsAndEventExploration() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["demo.open"].waitForExistence(timeout: 10))
        app.buttons["demo.open"].tap()
        let picker = app.buttons["thread.themePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.tap()
        app.buttons["thread.theme.摄影"].tap()
        XCTAssertEqual(app.buttons["thread.toggle"].label, "抽出主题")
        jump("最近", in: app)
        let handle = app.descendants(matching: .any).matching(identifier: "timeline.node")
            .matching(NSPredicate(format: "label CONTAINS %@", "又回到了春天拍日出的湖边。"))
            .firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertEqual(handle.value as? String, "已收回", handle.debugDescription)
        let horizontalStart = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        horizontalStart.press(forDuration: 0.1, thenDragTo: horizontalStart.withOffset(CGVector(dx: -90, dy: 0)))
        XCTAssertEqual(handle.value as? String, "已收回", "Horizontal browsing must not extract the thread")
        jump("最近", in: app)
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -25)))
        expectation(for: NSPredicate(format: "value == %@", "已收回"), evaluatedWith: handle)
        waitForExpectations(timeout: 5)
        let fullStart = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let up = fullStart.withOffset(CGVector(dx: 0, dy: -170))
        fullStart.press(forDuration: 0.1, thenDragTo: up)
        let expanded = NSPredicate(format: "value == %@", "已抽出")
        expectation(for: expanded, evaluatedWith: handle)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.otherElements["thread.handle"].exists, "Manipulation belongs to the memory node")
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "thread-extracted"
        image.lifetime = .keepAlways
        add(image)
        let toggle = app.buttons["thread.toggle"]
        XCTAssertEqual(toggle.label, "收回主题")
        jump("最早", in: app)
        let leading = XCTAttachment(screenshot: app.screenshot())
        leading.name = "thread-leading-return"
        leading.lifetime = .keepAlways
        add(leading)
        jump("最近", in: app)
        let trailing = XCTAttachment(screenshot: app.screenshot())
        trailing.name = "thread-trailing-return"
        trailing.lifetime = .keepAlways
        add(trailing)
        toggle.tap()
        expectation(for: NSPredicate(format: "value == %@", "已收回"), evaluatedWith: handle)
        waitForExpectations(timeout: 5)
        toggle.tap()
        expectation(for: expanded, evaluatedWith: handle)
        waitForExpectations(timeout: 5)
        jump("最近", in: app)
        let node = app.descendants(matching: .any).matching(identifier: "timeline.node")
            .matching(NSPredicate(format: "label CONTAINS %@", "又回到了春天拍日出的湖边。"))
            .firstMatch
        node.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "关联瞬间")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
        let downStart = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        downStart.press(forDuration: 0.1, thenDragTo: downStart.withOffset(CGVector(dx: 0, dy: 180)))
        expectation(for: NSPredicate(format: "value == %@", "已收回"), evaluatedWith: handle)
        waitForExpectations(timeout: 5)
        app.buttons["demo.close"].tap()
        XCTAssertTrue(app.buttons["demo.open"].waitForExistence(timeout: 5))
    }

    func testDemoFirstPresentationDetailsAndRepeatedExit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let open = app.buttons["demo.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        for cycle in 0..<3 {
            open.tap()
            let close = app.buttons["demo.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 10), "Demo must always have an exit")
            XCTAssertTrue(app.staticTexts["独立演示空间"].exists, "Demo content must load on first entry")
            jump("最近", in: app)
            let node = app.descendants(matching: .any).matching(identifier: "timeline.node")
                .matching(NSPredicate(format: "label CONTAINS %@", "又回到了春天拍日出的湖边。"))
                .firstMatch
            XCTAssertTrue(node.waitForExistence(timeout: 5))
            let before = XCTAttachment(screenshot: app.screenshot())
            before.name = "demo-before-node-\(cycle)"
            before.lifetime = .keepAlways
            add(before)
            node.tap()
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "关联瞬间")).firstMatch.waitForExistence(timeout: 5))
            app.buttons["完成"].tap()
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            if cycle == 0 {
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "demo-visible-with-exit"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
            close.tap()
            XCTAssertTrue(open.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["从一个瞬间开始。"].exists, "Demo must not populate the real library")
        }
    }
    private func jump(_ label: String, in app: XCUIApplication) {
        let index = app.buttons["timeline.index"]
        XCTAssertTrue(index.waitForExistence(timeout: 5))
        index.tap()
        XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 5))
        app.buttons[label].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.navigationBars["时间索引"])
        waitForExpectations(timeout: 5)
    }

}
