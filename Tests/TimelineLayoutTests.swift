import XCTest
@testable import Afterimage

final class TimelineLayoutTests: XCTestCase {
    func testParallelStrandsSeparateAtNodesButRejoinTheSameAxis() {
        let positions = [290.0, 310.0]
        let bounds = 0.0...600.0
        for extra in [0.0, 52.0, 104.0] {
            XCTAssertEqual(ThreadGeometry.y(at: 290, progress: 1, positions: positions, bounds: bounds, additionalLift: extra), TimelineLayout.y(at: 290) - ThreadGeometry.lift - extra, accuracy: 0.001)
            for x in [0.0, 600.0] {
                XCTAssertEqual(ThreadGeometry.y(at: x, progress: 1, positions: positions, bounds: bounds, additionalLift: extra), TimelineLayout.y(at: x), accuracy: 0.001)
            }
        }
    }
    func testBrowsingProgressSnapsCoalescedShortScrollEndpoints() {
        let dates = [0.0, 86_400.0].map { Date(timeIntervalSince1970: $0) }
        let layout = TimelineLayout(dates: dates, viewport: 402)
        let span = layout.width - 402
        XCTAssertEqual(layout.browsingProgress(at: 0.4, viewport: 402), 0)
        XCTAssertEqual(layout.browsingProgress(at: span - 0.4, viewport: 402), 1)
        XCTAssertEqual(layout.browsingProgress(at: span / 2, viewport: 402), 0.5, accuracy: 0.0001)
        XCTAssertEqual(layout.browsingProgress(at: -50, viewport: 402), 0)
        XCTAssertEqual(layout.browsingProgress(at: span + 50, viewport: 402), 1)
    }
    func testEmptySingleAndEqualDatesRemainReachable() {
        XCTAssertGreaterThanOrEqual(TimelineLayout(dates: [], viewport: 390).width, 390)
        let date = Date(timeIntervalSince1970: 0)
        let layout = TimelineLayout(dates: Array(repeating: date, count: 100), viewport: 390)
        XCTAssertEqual(layout.positions.count, 100)
        for pair in zip(layout.positions, layout.positions.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1 - pair.0, 190)
        }
        XCTAssertLessThan(layout.positions.last!, layout.width)
    }

    func testBothReturnCurvesFitInsideScrollContent() {
        let layout = TimelineLayout(dates: [Date(), Date().addingTimeInterval(86400)], viewport: 390)
        XCTAssertGreaterThan(layout.positions.first! - ThreadGeometry.joinLength, 0)
        XCTAssertLessThan(layout.positions.last! + ThreadGeometry.joinLength, layout.width)
    }

    func testLongGapsCompressAndDatesRemainMonotonic() {
        let dates = [0.0, 86_400.0, 86_400.0 * 365 * 100].map { Date(timeIntervalSince1970: $0) }
        let layout = TimelineLayout(dates: dates, viewport: 390)
        let nearGap = layout.positions[1] - layout.positions[0]
        let farGap = layout.positions[2] - layout.positions[1]
        XCTAssertGreaterThan(farGap, nearGap)
        XCTAssertLessThanOrEqual(farGap, 440)
        XCTAssertLessThan(layout.width, 1500)
    }
}
