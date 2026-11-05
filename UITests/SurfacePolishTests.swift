import XCTest

final class SurfacePolishTests: XCTestCase {
    func testBodyDragExpandsBeforeListScrollsAndComparisonStartsAtFirstMoment() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-reading-fixture", "--ui-collection-fixture", "--ui-drawer-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["thread.themePicker"].waitForExistence(timeout: 10))
        app.buttons["thread.themePicker"].tap()
        let picker = app.descendants(matching: .any).matching(identifier: "themes.picker").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let first = app.buttons["不选择主题"]
        let initialY = picker.frame.minY
        let rowInset = first.frame.minY - initialY
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)))
        XCTAssertLessThan(picker.frame.minY, initialY - 100)
        XCTAssertEqual(first.frame.minY - picker.frame.minY, rowInset, accuracy: 4)
        capture(app, "drawer-body-drag-expands-without-scrolling-list")
        let expandedY = picker.frame.minY
        picker.swipeUp(); picker.swipeUp()
        XCTAssertEqual(picker.frame.minY, expandedY, accuracy: 1)
        XCTAssertTrue(app.buttons["thread.theme.scope17"].isHittable)
        capture(app, "expanded-drawer-list-can-scroll")
        app.navigationBars["选择主题"].buttons["完成"].tap()
        openMore(app)
        app.buttons["并行抽丝"].tap()
        XCTAssertTrue(app.navigationBars["并行抽丝"].waitForExistence(timeout: 5))
        let firstMoment = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "瞬间：Lake morning")).firstMatch
        XCTAssertTrue(firstMoment.waitForExistence(timeout: 5))
        XCTAssertTrue(firstMoment.isHittable)
        XCTAssertLessThan(firstMoment.frame.midX, app.frame.width * 0.6)
        capture(app, "comparison-opens-at-first-selected-moment")
        app.navigationBars["并行抽丝"].buttons["完成"].tap()
        let axis = app.scrollViews["timeline.scroll"]
        axis.swipeRight(); capture(app, "native-axis-scroll-right")
        axis.swipeLeft(); capture(app, "native-axis-scroll-left")
    }
    func testAxisAtBothEdgesAndExpandedDrawerCollapsesWithoutRelayout() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-reading-fixture", "--ui-collection-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["timeline.index"].waitForExistence(timeout: 10))
        app.buttons["timeline.index"].tap()
        app.buttons["最早"].tap()
        let axis = app.scrollViews["timeline.scroll"]
        XCTAssertTrue(axis.waitForExistence(timeout: 5))
        axis.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: axis.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)), withVelocity: .slow, thenHoldForDuration: 1)
        capture(app, "continuous-axis-leading-edge-after-bounce")
        app.buttons["timeline.index"].tap(); app.buttons["最近"].tap()
        axis.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: axis.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)), withVelocity: .slow, thenHoldForDuration: 1)
        capture(app, "continuous-axis-trailing-edge-after-bounce")
        openMore(app)
        let row = app.buttons["时间回顾与长图"]
        let openingInset = row.frame.minY - app.navigationBars["更多"].frame.minY
        expand("更多", app: app)
        XCTAssertEqual(row.frame.minY - app.navigationBars["更多"].frame.minY, openingInset, accuracy: 3)
        capture(app, "drawer-expanded-fixed-content-layout")
        app.navigationBars["更多"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.61)), withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertTrue(app.navigationBars["更多"].exists)
        XCTAssertGreaterThan(app.navigationBars["更多"].frame.minY, app.frame.height * 0.4)
        XCTAssertEqual(row.frame.minY - app.navigationBars["更多"].frame.minY, openingInset, accuracy: 3)
        XCTAssertGreaterThan(app.buttons["演示空间"].frame.minY, app.frame.maxY)
        capture(app, "drawer-collapsed-fixed-content-layout")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func expand(_ title: String, app: XCUIApplication) {
        let bar = app.navigationBars[title]
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)))
    }
    private func openMore(_ app: XCUIApplication) {
        let more = app.buttons["library.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5)); more.tap()
        XCTAssertTrue(app.buttons["时间回顾与长图"].waitForExistence(timeout: 5))
    }
    func testDrawerWidthsThemeActionsAndSoftNavigationSurfaces() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-reading-fixture", "--ui-collection-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["thread.themePicker"].waitForExistence(timeout: 10))
        app.buttons["thread.themePicker"].tap()
        let picker = app.descendants(matching: .any).matching(identifier: "themes.picker").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.frame.minX, 0, accuracy: 1)
        XCTAssertEqual(picker.frame.width, app.frame.width, accuracy: 1)
        let initialY = picker.frame.minY
        capture(app, "theme-picker-edge-to-edge-collapsed")
        expand("选择主题", app: app)
        XCTAssertLessThan(picker.frame.minY, initialY - 80)
        XCTAssertEqual(picker.frame.width, app.frame.width, accuracy: 1)
        capture(app, "theme-picker-edge-to-edge-expanded")
        app.navigationBars["选择主题"].buttons["完成"].tap()

        openMore(app)
        let moreScroll = app.scrollViews["more.scroll"]
        XCTAssertGreaterThanOrEqual(app.buttons["演示空间"].frame.minY, app.frame.maxY)
        XCTAssertEqual(moreScroll.frame.minX, 0, accuracy: 1)
        XCTAssertEqual(moreScroll.frame.width, app.frame.width, accuracy: 1)
        capture(app, "more-four-actions-collapsed")
        expand("更多", app: app)
        XCTAssertTrue(app.buttons["演示空间"].isHittable)
        XCTAssertEqual(moreScroll.frame.width, app.frame.width, accuracy: 1)
        capture(app, "more-options-revealed-expanded")
        app.buttons["主题管理"].tap()
        XCTAssertTrue(app.buttons["选择主题：Lake"].waitForExistence(timeout: 5))
        capture(app, "theme-management-unboxed-introduction")
        app.buttons["选择主题：Lake"].tap()
        app.buttons["选择主题：Walk"].tap()
        XCTAssertTrue(app.buttons["themes.merge"].isHittable)
        XCTAssertTrue(app.buttons["themes.delete"].isHittable)
        XCTAssertGreaterThan(app.buttons["themes.merge"].frame.minY, app.frame.height - 160)
        capture(app, "theme-management-pinned-selection-actions")
        app.buttons["themes.merge"].tap()
        XCTAssertTrue(app.navigationBars["保留哪个主题"].waitForExistence(timeout: 5))
        capture(app, "theme-merge-destination")
        app.buttons["取消"].tap()
        app.navigationBars["主题管理"].buttons["完成"].tap()

        openMore(app)
        app.buttons["时间回顾与长图"].tap()
        XCTAssertTrue(app.buttons["review.export"].waitForExistence(timeout: 5))
        app.swipeUp()
        capture(app, "review-soft-scroll-edge")
        app.buttons["review.export"].tap()
        XCTAssertTrue(app.navigationBars["长图预览"].waitForExistence(timeout: 10))
        capture(app, "continuous-main-axis-share-image")
        app.buttons["返回"].tap()
        app.navigationBars["时间回顾"].buttons["完成"].tap()
        app.terminate()
        app.launchArguments.append("--ui-stress")
        app.launch()
        XCTAssertTrue(app.buttons["timeline.index"].waitForExistence(timeout: 10))
        app.buttons["timeline.index"].tap()
        XCTAssertTrue(app.navigationBars["时间索引"].waitForExistence(timeout: 5))
        app.swipeUp()
        capture(app, "index-ios26-soft-scroll-edge")
    }
}
