import XCTest
@testable import Afterimage

@MainActor final class EnergyOptimizationTests: XCTestCase {
    func testDecorativeClockStopsWhileCoveredAndResumesWithoutJump() async throws {
        let clock = DecorativeMotion()
        clock.setVisible(true)
        try await Task.sleep(for: .milliseconds(200))
        clock.setVisible(false)
        let frozen = clock.time
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(clock.time, frozen)
        clock.wake()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(clock.time, frozen, "Touches must not wake a covered home")
        clock.setVisible(true)
        XCTAssertEqual(clock.time, frozen, "Resume must retain the rendered phase")
        clock.setVisible(false)
    }
    func testDecorativeClockQuietsAfterIdle() async throws {
        let clock = DecorativeMotion()
        clock.setVisible(true)
        try await Task.sleep(for: .milliseconds(3400))
        let frozen = clock.time
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(clock.time, frozen)
        clock.setVisible(false)
    }
    func testPreparationReusesScrollingWorkButInvalidatesChangedData() {
        let cache = TimelinePreparationCache()
        let filter = TimelineDateFilter()
        var calls = 0
        func key(width: Double) -> TimelinePreparationCache.Key {
            .init(records: [], links: [], filter: filter, width: width, theme: nil, focus: nil)
        }
        func build() -> TimelinePreparationCache.Value {
            calls += 1
            return .init(memories: [], themes: [], layout: .init(dates: [], viewport: 390), linkedIDs: [], spans: [], members: [], memberPositions: [])
        }
        _ = cache.resolve(key: key(width: 390), build: build)
        for _ in 0..<100 { _ = cache.resolve(key: key(width: 390), build: build) }
        XCTAssertEqual(calls, 1)
        _ = cache.resolve(key: key(width: 402), build: build)
        XCTAssertEqual(calls, 2)
    }
}
