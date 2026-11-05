import XCTest
import SwiftData
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Afterimage

@MainActor
final class MemoryStoreTests: XCTestCase {
    func testTitleBodyAndThemeColorPersistIndependently() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("titles.store")
        let body = String(repeating: "长正文保留所有细节。", count: 80)
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            try MemoryStore.save(record: nil, text: body, occurredAt: Date(), photoData: nil,
                                 tagText: "摄影、湖边", title: "湖边的晚风", in: context)
            let record = try XCTUnwrap(context.fetch(FetchDescriptor<MemoryRecord>()).first)
            XCTAssertEqual(record.displayTitle, "湖边的晚风")
            XCTAssertEqual(record.text, body)
            XCTAssertEqual(Set(record.tags.compactMap(\.colorIndex)).count, 2)
            record.tags.first { $0.name == "摄影" }?.colorIndex = 4
            try context.save()
        }
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            let record = try XCTUnwrap(context.fetch(FetchDescriptor<MemoryRecord>()).first)
            XCTAssertEqual(record.displayTitle, "湖边的晚风")
            XCTAssertEqual(record.text, body)
            XCTAssertEqual(record.tags.first { $0.name == "摄影" }?.colorIndex, 4)
            try MemoryStore.save(record: record, text: "", occurredAt: record.occurredAt, photoData: nil,
                                 tagText: "摄影", title: "只有标题也能记录", in: context)
            XCTAssertEqual(record.displayTitle, "只有标题也能记录")
            XCTAssertTrue(record.text.isEmpty)
        }
    }

    func testLegacyTitleFallbackAndPaletteAllocation() {
        let body = "第一次去湖边拍日出。\n" + String(repeating: "完整正文不能丢失。", count: 40)
        let record = MemoryRecord(text: body, occurredAt: Date())
        XCTAssertNil(record.title)
        XCTAssertEqual(record.displayTitle, "第一次去湖边拍日出。")
        XCTAssertEqual(record.text, body)
        XCTAssertEqual(MemoryRecord.suggestedTitle(from: String(repeating: "字", count: 100)).count, 40)
        var used: [Int] = []
        for _ in ThemePalette.inks { used.append(ThemePalette.nextIndex(used: used)) }
        XCTAssertEqual(Set(used).count, ThemePalette.inks.count)
        XCTAssertEqual(ThemePalette.nextIndex(used: used + [0]), 1)
    }

    func testWhitespaceSaveDoesNotMutateExistingRecordOrInsertTags() throws {
        let container = try MemoryStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try MemoryStore.save(record: nil, text: "原内容", occurredAt: Date(), photoData: nil, tagText: "原标签", in: context)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<MemoryRecord>()).first)
        XCTAssertThrowsError(try MemoryStore.save(record: record, text: " \n ", occurredAt: Date(), photoData: nil, tagText: "新标签", in: context))
        XCTAssertEqual(record.text, "原内容")
        XCTAssertEqual(record.tags.map(\.name), ["原标签"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryTag>()), 1)
    }
    func testDiskRoundTripEditDeleteAndSharedTags() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
        let photo = renderer.jpegData(withCompressionQuality: 0.8) { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let id: UUID
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            try MemoryStore.save(record: nil, text: "  湖边  ", occurredAt: date,
                                 photoData: photo, tagText: "摄影、摄影, Film，film", in: context)
            let first = try XCTUnwrap(context.fetch(FetchDescriptor<MemoryRecord>()).first)
            id = first.id
            XCTAssertEqual(first.tags.count, 2)
            try MemoryStore.save(record: nil, text: "镜头", occurredAt: date.addingTimeInterval(100),
                                 photoData: nil, tagText: "摄影", in: context)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryTag>()), 2)
        }
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            let records = try context.fetch(FetchDescriptor<MemoryRecord>())
            XCTAssertEqual(records.count, 2)
            let first = try XCTUnwrap(records.first { $0.id == id })
            XCTAssertEqual(first.text, "湖边")
            XCTAssertEqual(first.occurredAt, date)
            XCTAssertEqual(first.photoData, photo)
            try MemoryStore.save(record: first, text: "重访湖边", occurredAt: date,
                                 photoData: nil, tagText: "湖边", in: context)
        }
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            let records = try context.fetch(FetchDescriptor<MemoryRecord>())
            let first = try XCTUnwrap(records.first { $0.id == id })
            XCTAssertEqual(first.text, "重访湖边")
            XCTAssertNil(first.photoData)
            XCTAssertEqual(first.tags.map(\.name), ["湖边"])
            try MemoryStore.delete(first, in: context)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryRecord>()), 1)
            let remaining = try XCTUnwrap(context.fetch(FetchDescriptor<MemoryRecord>()).first)
            XCTAssertEqual(remaining.tags.map(\.name), ["摄影"])
        }
        do {
            let container = try MemoryStore.makeContainer(url: url)
            XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<MemoryRecord>()), 1)
        }
    }

    func testDemoIsIsolatedAndRecreated() throws {
        let real = try MemoryStore.makeContainer(inMemory: true)
        let demo = try MemoryStore.makeDemoContainer()
        XCTAssertEqual(try ModelContext(real).fetchCount(FetchDescriptor<MemoryRecord>()), 0)
        let context = ModelContext(demo)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryRecord>()), 18)
        let tags = try context.fetch(FetchDescriptor<MemoryTag>())
        XCTAssertEqual(tags.first { $0.name == "摄影" }?.memories.count, 7)
        XCTAssertEqual(tags.first { $0.name == "湖边" }?.memories.count, 3)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MemoryRecord>()).filter { $0.photoData != nil }.count, 4)
        try MemoryStore.delete(try XCTUnwrap(context.fetch(FetchDescriptor<MemoryRecord>()).first), in: context)
        let freshDemo = try MemoryStore.makeDemoContainer()
        XCTAssertEqual(try ModelContext(freshDemo).fetchCount(FetchDescriptor<MemoryRecord>()), 18)
        XCTAssertEqual(try ModelContext(real).fetchCount(FetchDescriptor<MemoryRecord>()), 0)
    }

    func testPhotoDownsamplingAndInvalidData() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1000), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }())
        let original = renderer.jpegData(withCompressionQuality: 1) { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1000))
        }
        let processed = try PhotoImport.prepare(original)
        let image = try XCTUnwrap(UIImage(data: processed)?.cgImage)
        XCTAssertLessThanOrEqual(max(image.width, image.height), 2000)
        XCTAssertThrowsError(try PhotoImport.prepare(Data([0, 1, 2])))
        XCTAssertNil(PhotoImport.captureDate(from: original))
        XCTAssertNil(PhotoImport.captureDate(from: Data([0, 1, 2])))
    }

    func testOriginalPhotoDateUsesEmbeddedTimezoneBeforeReencoding() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { _ in UIColor.red.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 10, height: 10)) }
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: "2026:03:12 07:15:00",
                "OffsetTimeOriginal": "+08:00"
            ]
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let expected = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-11T23:15:00Z"))
        XCTAssertEqual(PhotoImport.captureDate(from: output as Data), expected)
        let processed = try PhotoImport.prepare(output as Data)
        XCTAssertNil(PhotoImport.captureDate(from: processed))
    }
}
