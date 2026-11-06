import XCTest
import SwiftUI
@testable import Afterimage

@MainActor final class SilkFieldTests: XCTestCase {
    private func pixels(at offset: Double, opening: OpeningPresentation? = nil) throws -> [UInt8] {
        let view = TimelineSilkField(offset: offset, viewport: 402, contentWidth: 1200, height: 530, sampleTime: 18)
            .offset(x: -offset).frame(width: 402, height: 530, alignment: .topLeading)
            .clipped().background(AfterimageStyle.background).environment(\.colorScheme, .dark)
            .environment(\.openingPresentation, opening)
        let renderer = ImageRenderer(content: view); renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage?.cgImage)
        XCTAssertEqual(image.width, 402); XCTAssertEqual(image.height, 530)
        var bytes = [UInt8](repeating: 0, count: 402 * 530 * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: 402, height: 530, bitsPerComponent: 8,
                                            bytesPerRow: 402 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 402, height: 530))
        return bytes
    }
    func testFieldCoversBothRubberBandRegionsWithoutBlackColumns() throws {
        for offset in [-120.0, 0, 383, 384, 798, 918] {
            let image = try pixels(at: offset)
            let missing = (0..<402).filter { x in
                let red = (220..<310).map { image[($0 * 402 + x) * 4] }.max() ?? 0
                return red <= 45
            }
            XCTAssertTrue(missing.isEmpty, "Missing silk at offset \(offset), columns: \(Array(missing.prefix(12))), count: \(missing.count)")
        }
    }
    func testRetainedWorldPixelsDoNotJumpWhenTileWindowAdvances() throws {
        let before = try pixels(at: 383), after = try pixels(at: 384)
        var difference = 0.0
        for y in 220..<310 {
            for x in 0..<401 {
                for channel in 0..<3 {
                    difference += abs(Double(before[(y * 402 + x + 1) * 4 + channel]) - Double(after[(y * 402 + x) * 4 + channel]))
                }
            }
        }
        XCTAssertLessThan(difference / Double(90 * 401 * 3), 1.5, "The same world coordinates must retain the same geometry and light after a window shift")
    }
    func testTileBufferCoversViewportWithCoalescedOffsets() {
        for actual in stride(from: -240.0, through: 7200, by: 17) {
            for reported in [floor(actual / 192) * 192, ceil(actual / 192) * 192] {
            let tiles = SilkTiling.indices(offset: reported, viewport: 402)
            XCTAssertLessThanOrEqual(Double(tiles.lowerBound) * SilkTiling.width, actual - 64)
            XCTAssertGreaterThanOrEqual(Double(tiles.upperBound + 1) * SilkTiling.width, actual + 402 + 64)
            }
        }
    }

    func testOpeningSilkAlreadyCoversTheFullViewport() throws {
        let opening = OpeningPresentation()
        opening.silkOpacity = 1
        let image = try pixels(at: 798, opening: opening)
        for x in 0..<402 {
            let red = (0..<530).map { image[($0 * 402 + x) * 4] }.max() ?? 0
            XCTAssertGreaterThan(red, 28, "Opening must reach both edges, missing column \(x)")
        }
    }

    func testEndingOpeningDoesNotChangeAnyAxisPixel() throws {
        let opening = OpeningPresentation()
        opening.spread = 1; opening.silkOpacity = 1; opening.contentOpacity = 1
        let before = try pixels(at: 798, opening: opening)
        opening.enterBackground()
        let after = try pixels(at: 798, opening: opening)
        XCTAssertFalse(opening.isBlocking)
        XCTAssertEqual(before, after, "Removing the input shield must not move, reset or replace the silk")
        XCTAssertEqual(after, try pixels(at: 798), "The final opening frame must be the normal timeline field")
    }

    func testEndingOpeningDoesNotChangeAnyWordmarkPixel() throws {
        let opening = OpeningPresentation()
        opening.titleFrame = CGRect(x: 0, y: 40, width: 402, height: 44)
        opening.axisFrame = CGRect(x: 0, y: 150, width: 402, height: 530)
        opening.wordmarkTravel = 0; opening.wordmarkOpacity = 1
        opening.contentOpacity = 0.25
        func render() throws -> [UInt8] {
            let view = OpeningWordmark(presentation: opening).frame(width: 402, height: 300)
                .background(AfterimageStyle.background).environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view); renderer.scale = 1
            let image = try XCTUnwrap(renderer.uiImage?.cgImage)
            var bytes = [UInt8](repeating: 0, count: 402 * 300 * 4)
            let context = try XCTUnwrap(CGContext(data: &bytes, width: 402, height: 300, bitsPerComponent: 8,
                bytesPerRow: 402 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 402, height: 300))
            return bytes
        }
        let landed = try render()
        XCTAssertTrue(stride(from: 0, to: landed.count, by: 4).contains { landed[$0] > 100 },
                      "The comparison must contain a visible wordmark")
        opening.contentOpacity = 1
        XCTAssertEqual(landed, try render(), "Revealing controls must not crossfade or replace the title")
        opening.enterBackground()
        XCTAssertEqual(landed, try render(), "Removing the launch shield must leave every title pixel in place")
    }

    func testGatheringUsesTheDrawingClockInsteadOfTheImmediateTarget() async throws {
        let opening = OpeningPresentation()
        opening.finish(reduceMotion: false)
        XCTAssertEqual(opening.spread, 2.6)
        try await Task.sleep(for: .milliseconds(180))
        let earlier = opening.spread
        XCTAssertGreaterThan(earlier, 1)
        XCTAssertLessThan(earlier, 2.6)
        try await Task.sleep(for: .milliseconds(220))
        XCTAssertLessThan(opening.spread, earlier)
        XCTAssertGreaterThan(opening.spread, 1)
        opening.enterBackground()
        XCTAssertEqual(opening.spread, 1)
    }

    func testOpeningBranchesGatherIntoExactNormalGeometry() {
        var initial: [Double] = []
        for strand in 0..<17 {
            for x in stride(from: 0.0, through: 402.0, by: 24) {
                let normal = SilkRenderer.point(x: x, strand: strand, time: 18, tension: 0)
                let settled = SilkRenderer.openingPoint(x: x, strand: strand, time: 18, tension: 0,
                                                       amount: 0, center: 201, viewport: 402)
                XCTAssertEqual(settled.y, normal.y)
                XCTAssertEqual(settled.depth, normal.depth)
                let loose = SilkRenderer.openingPoint(x: x, strand: strand, time: 18, tension: 0,
                                                     amount: 1, center: 201, viewport: 402)
                initial.append(loose.y)
                let nearly = SilkRenderer.openingPoint(x: x, strand: strand, time: 18, tension: 0,
                                                      amount: 0.00001, center: 201, viewport: 402)
                XCTAssertEqual(nearly.y, normal.y, accuracy: 0.01)
            }
        }
        XCTAssertGreaterThan((initial.max() ?? 0) - (initial.min() ?? 0), 300,
                             "Loose branches must occupy the surrounding space before gathering")
    }
}
