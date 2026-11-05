import XCTest
@testable import Afterimage

@MainActor
final class ThreadTests: XCTestCase {
    func testHighRefreshOptInIsPresentInAppBundle() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CADisableMinimumFrameDurationOnPhone") as? Bool, true)
    }
    func testSettlingKeepsWallClockPaceWhenRefreshesAreSkipped() {
        for hz in [10.0, 20, 60, 120] {
            let motion = ThreadMotion(drivesDisplayLink: false)
            motion.configure(positions: (0..<200).map { Double($0) * 200 })
            motion.settle(expanded: true, immediately: false)
            for _ in 0..<Int(hz * 2) { motion.advance(by: 1 / hz) }
            XCTAssertEqual(motion.progress, 1, accuracy: 0.001)
            XCTAssertTrue(motion.displacements.allSatisfy { $0 > 0.999 })
            motion.settle(expanded: false, immediately: false)
            for _ in 0..<Int(hz * 2) { motion.advance(by: 1 / hz) }
            XCTAssertEqual(motion.progress, 0, accuracy: 0.001)
            XCTAssertTrue(motion.displacements.allSatisfy { $0 < 0.001 })
        }
    }

    func testIndependentChainTransmitsTensionWhileFingerIsStationary() {
        let motion = ThreadMotion(drivesDisplayLink: false)
        motion.configure(positions: [130, 400, 1900, 2200, 2600, 3000])
        motion.drag(translation: -ThreadGeometry.lift * 0.4, at: 400)
        XCTAssertEqual(motion.displacements[1], 0.4, accuracy: 0.0001)
        XCTAssertEqual(motion.displacements[2], 0)
        for _ in 0..<6 { motion.advance(by: 1.0 / 120) }
        let early = motion.displacements
        XCTAssertGreaterThan(early[2], early[3])
        XCTAssertGreaterThan(early[3], early[4])
        let evenlySpaced = ThreadMotion(drivesDisplayLink: false)
        evenlySpaced.configure(positions: [0, 100, 200, 300, 400, 500])
        evenlySpaced.drag(translation: -ThreadGeometry.lift * 0.4, at: 100)
        for _ in 0..<6 { evenlySpaced.advance(by: 1.0 / 120) }
        XCTAssertEqual(early, evenlySpaced.displacements, "Calendar spacing must not alter tension transmission")
        for _ in 0..<30 { motion.advance(by: 1.0 / 120) }
        XCTAssertGreaterThan(motion.displacements[2], early[2], "Holding the finger still must still transmit tension")
        XCTAssertLessThan(motion.displacements[5], 0.02, "Short pulls must leave distant events near the main line")
        motion.drag(translation: -ThreadGeometry.lift, at: 400)
        for _ in 0..<240 { motion.advance(by: 1.0 / 120) }
        XCTAssertTrue(motion.displacements.allSatisfy { $0 > 0.99 })
    }

    func testCatchDifferentNodePreservesLiveShapeAndReturnsAtBothRefreshRates() {
        for hz in [60.0, 120.0] {
            let motion = ThreadMotion(drivesDisplayLink: false)
            let positions = [130.0, 400, 1900, 2200]
            motion.configure(positions: positions)
            motion.drag(translation: -60, at: positions[1])
            for _ in 0..<12 { motion.advance(by: 1 / hz) }
            motion.endDrag(translation: -60, predicted: -120, reduceMotion: false)
            for _ in 0..<5 { motion.advance(by: 1 / hz) }
            let live = motion.displacements
            motion.drag(translation: 0, at: positions[2])
            XCTAssertEqual(motion.displacements, live, "Catching a different node must not teleport the chain")
            XCTAssertEqual(motion.progress, live[2], accuracy: 0.0001)
            motion.drag(translation: 40, at: positions[2])
            motion.endDrag(translation: 40, predicted: 140, reduceMotion: false)
            for _ in 0..<Int(hz * 4) { motion.advance(by: 1 / hz) }
            XCTAssertEqual(motion.displacements, positions.map { _ in 0 })
            XCTAssertNil(motion.focusX)
            motion.settle(expanded: true, immediately: true)
            XCTAssertEqual(motion.displacements, positions.map { _ in 1 })
            motion.configure(positions: [130, 800])
            XCTAssertEqual(motion.displacements, [0, 0])
        }
    }

    func testSampledChainAndLongJoinsHaveNoOvershootOrNodeMismatch() {
        let positions = [130.0, 400, 1900, 2200]
        let values = [0.1, 0.7, 0.3, 0.05]
        let bounds = (positions[0] - ThreadGeometry.joinLength)...(positions.last! + ThreadGeometry.joinLength)
        for i in positions.indices {
            let y = ThreadGeometry.y(at: positions[i], progress: 0.7, positions: positions, bounds: bounds, displacements: values)
            XCTAssertEqual(y, TimelineLayout.y(at: positions[i]) - ThreadGeometry.lift * values[i], accuracy: 0.0001)
        }
        for x in stride(from: bounds.lowerBound, through: bounds.upperBound, by: 1) {
            let value = ThreadGeometry.sample(at: x, positions: positions, values: values, fallback: 0)
            XCTAssertTrue(value.isFinite && value >= 0.05 && value <= 0.7)
        }
        for x in [bounds.lowerBound, bounds.upperBound] {
            let next = x + (x == bounds.lowerBound ? 0.01 : -0.01)
            let delta = ThreadGeometry.y(at: next, progress: 1, positions: positions, bounds: bounds, displacements: values) - TimelineLayout.y(at: next)
            XCTAssertEqual(delta, 0, accuracy: 0.0001)
        }
    }
    func testDragTracksFingerAndSpringsInBothDirections() {
        let motion = ThreadMotion(drivesDisplayLink: false)
        motion.drag(translation: -ThreadGeometry.lift / 2)
        XCTAssertEqual(motion.progress, 0.5, accuracy: 0.0001)
        motion.endDrag(translation: -ThreadGeometry.lift / 2, predicted: -180, reduceMotion: false)
        for _ in 0..<200 { motion.advance(by: 1.0 / 60) }
        XCTAssertEqual(motion.progress, 1)
        motion.drag(translation: ThreadGeometry.lift / 2)
        XCTAssertEqual(motion.progress, 0.5, accuracy: 0.0001)
        motion.endDrag(translation: ThreadGeometry.lift / 2, predicted: 180, reduceMotion: false)
        for _ in 0..<200 { motion.advance(by: 1.0 / 60) }
        XCTAssertEqual(motion.progress, 0)
    }

    func testOppositeStrandsMirrorTheirDisplacementAndRejoinAtBothEnds() {
        let positions = [130.0, 400, 800]
        let bounds = (positions[0] - ThreadGeometry.joinLength)...(positions.last! + ThreadGeometry.joinLength)
        for x in [bounds.lowerBound, 130, 270, 400, 800, bounds.upperBound] {
            let base = TimelineLayout.y(at: x)
            let upper = ThreadGeometry.y(at: x, progress: 1, positions: positions, bounds: bounds)
            let lower = ThreadGeometry.y(at: x, progress: 1, positions: positions, bounds: bounds, direction: -1)
            XCTAssertEqual(base - upper, lower - base, accuracy: 0.0001)
            if x == bounds.lowerBound || x == bounds.upperBound {
                XCTAssertEqual(lower, base, accuracy: 0.0001)
            }
        }
    }

    func testElasticOverpullReturnsToExpandedHeightAndCanBeInterrupted() {
        let motion = ThreadMotion(drivesDisplayLink: false)
        let positions = [314.0, 600, 900]
        motion.configure(positions: positions)
        motion.settle(expanded: true, immediately: true)
        motion.drag(translation: -40, at: positions[1])
        let stretched = motion.displacements[1]
        XCTAssertGreaterThan(stretched, 1)
        XCTAssertLessThan(stretched, 1 + ThreadMotion.overshootLimit)
        XCTAssertEqual(ThreadGeometry.y(at: positions[1], progress: motion.progress, positions: positions,
                                        displacements: motion.displacements),
                       TimelineLayout.y(at: positions[1]) - ThreadGeometry.lift * stretched, accuracy: 0.0001)
        motion.endDrag(translation: -40, predicted: -40, reduceMotion: false)
        for _ in 0..<12 { motion.advance(by: 1.0 / 120) }
        XCTAssertLessThan(motion.progress, stretched)
        let liveHeight = motion.displacements[1]
        motion.drag(translation: 0, at: positions[1])
        XCTAssertEqual(motion.progress, liveHeight, accuracy: 0.0001)
        motion.endDrag(translation: 0, predicted: 0, reduceMotion: false)
        for _ in 0..<360 { motion.advance(by: 1.0 / 120) }
        XCTAssertEqual(motion.progress, 1, accuracy: 0.001)
        XCTAssertTrue(motion.displacements.allSatisfy { abs($0 - 1) < 0.001 })
        motion.drag(translation: -40, at: positions[1], allowOvershoot: false)
        XCTAssertEqual(motion.progress, 1)
    }

    func testInterruptUsesCurrentProgressAndClampsOverscroll() {
        let motion = ThreadMotion(drivesDisplayLink: false)
        motion.settle(expanded: true, immediately: false)
        for _ in 0..<8 { motion.advance(by: 1.0 / 60) }
        let current = motion.progress
        motion.drag(translation: 0)
        XCTAssertEqual(motion.progress, current)
        motion.drag(translation: 10000)
        XCTAssertEqual(motion.progress, 0)
        motion.drag(translation: -10000)
        XCTAssertGreaterThan(motion.progress, 1)
        XCTAssertLessThanOrEqual(motion.progress, 1 + ThreadMotion.overshootLimit)
        motion.endDrag(translation: -10000, predicted: -10000, reduceMotion: true)
        XCTAssertEqual(motion.progress, 1)
        motion.settle(expanded: false, immediately: true)
        XCTAssertEqual(motion.progress, 0)
    }

    func testCurveMatchesNodeAtEveryProgressAndSuppressionIsRespected() throws {
        for p in stride(from: 0.0, through: 1, by: 0.1) {
            for x in stride(from: 130.0, through: 2000, by: 100) {
                let y = ThreadGeometry.y(at: x, progress: p)
                XCTAssertTrue(y.isFinite)
                XCTAssertGreaterThan(y, 60)
                XCTAssertLessThan(y, 290)
            }
        }
        let a = MemoryRecord(text: "A", occurredAt: Date(), tags: [MemoryTag(name: "摄影")])
        let b = MemoryRecord(text: "B", occurredAt: Date(), tags: [MemoryTag(name: "摄影")])
        XCTAssertEqual(Resonance.threadMembers(tag: "摄影", memories: [a, b], choices: []).count, 2)
        let suppression = MemoryLink(source: a.id, target: b.id, tagKey: "摄影", enabled: false)
        XCTAssertTrue(Resonance.threadMembers(tag: "摄影", memories: [a, b], choices: [suppression]).isEmpty)
        XCTAssertEqual(a.text, "A")
    }

    func testPullPropagatesByNeighbourOrderThenReleasesWholeThread() {
        let positions = [130.0, 400, 1900, 2200, 2600, 3000]
        let focus = positions[1]
        let local = positions.map { ThreadGeometry.influence(at: $0, progress: 0.3, positions: positions, focus: focus) }
        XCTAssertEqual(local[1], 0.3, accuracy: 0.0001)
        XCTAssertGreaterThan(local[0], 0)
        XCTAssertEqual(local[0], local[2], accuracy: 0.0001, "Date spacing must not break neighbour propagation")
        XCTAssertEqual(local[3], 0)
        for x in positions {
            XCTAssertEqual(ThreadGeometry.influence(at: x, progress: 1, positions: positions, focus: focus), 1, accuracy: 0.0001)
        }
        let bounds = 0.0...3130.0
        for x in [bounds.lowerBound, bounds.upperBound] {
            XCTAssertEqual(ThreadGeometry.y(at: x, progress: 1, positions: positions, focus: focus, bounds: bounds), TimelineLayout.y(at: x), accuracy: 0.0001)
            let sign = x == bounds.lowerBound ? 1.0 : -1.0
            let next = x + sign * 0.01
            let slope = (ThreadGeometry.y(at: next, progress: 1, positions: positions, focus: focus, bounds: bounds) - ThreadGeometry.y(at: x, progress: 1, positions: positions, focus: focus, bounds: bounds)) / (next - x)
            let mainSlope = (TimelineLayout.y(at: next) - TimelineLayout.y(at: x)) / (next - x)
            XCTAssertEqual(slope, mainSlope, accuracy: 0.001, "Thread must return tangentially to the main line")
        }
        let motion = ThreadMotion(drivesDisplayLink: false)
        motion.drag(translation: -30, at: focus)
        XCTAssertEqual(motion.focusX, focus)
        motion.endDrag(translation: -30, predicted: -30, reduceMotion: true)
        XCTAssertEqual(motion.progress, 0)
        XCTAssertNil(motion.focusX)
        motion.drag(translation: -90, at: positions[3])
        motion.endDrag(translation: -90, predicted: -90, reduceMotion: true)
        XCTAssertEqual(motion.progress, 1)
        motion.suspend()
        XCTAssertFalse(motion.isDragging)
    }
}
