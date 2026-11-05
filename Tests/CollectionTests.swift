import XCTest
import SwiftData
import SwiftUI
@testable import Afterimage

@MainActor
final class CollectionTests: XCTestCase {
    func testArchiveRoundTripPreservesPhotosNotesAndSuppressionWithoutDuplicates() throws {
        let source = try MemoryStore.makeContainer(inMemory: true)
        let context = ModelContext(source)
        try MemoryStore.save(record: nil, text: "First", occurredAt: Date(timeIntervalSince1970: 1), photoData: Data([1]), tagText: "Lake", extraPhotos: [Data([2]), Data([3])], in: context)
        try MemoryStore.save(record: nil, text: "Second", occurredAt: Date(timeIntervalSince1970: 2), photoData: nil, tagText: "Lake", in: context)
        let records = try context.fetch(FetchDescriptor<MemoryRecord>(sortBy: [SortDescriptor(\.occurredAt)]))
        let theme = try XCTUnwrap(records[0].tags.first)
        theme.colorIndex = 4
        try Resonance.set(false, a: records[0].id, b: records[1].id, tag: theme.key, in: context)
        try Resonance.setManual(a: records[0].id, b: records[1].id, note: "Another season", in: context)
        let archive = try MemoryArchive.decode(MemoryArchive.snapshot(in: context).encoded())
        let destination = try MemoryStore.makeContainer(inMemory: true)
        XCTAssertEqual(try archive.restore(into: destination), 2)
        XCTAssertEqual(try archive.restore(into: destination), 0)
        let reopened = ModelContext(destination)
        let restored = try reopened.fetch(FetchDescriptor<MemoryRecord>(sortBy: [SortDescriptor(\.occurredAt)]))
        XCTAssertEqual(restored[0].photos, [Data([1]), Data([2]), Data([3])])
        XCTAssertEqual(restored[0].id, records[0].id)
        XCTAssertEqual(restored[0].tags.first?.colorIndex, 4)
        let links = try reopened.fetch(FetchDescriptor<MemoryLink>())
        XCTAssertFalse(Resonance.enabled(restored[0].id, restored[1].id, tag: theme.key, choices: links))
        XCTAssertEqual(Resonance.manual(restored[0].id, restored[1].id, choices: links)?.note, "Another season")
        restored[0].text = "Newer text"; try reopened.save()
        XCTAssertEqual(try archive.restore(into: destination), 0)
        XCTAssertEqual(try ModelContext(destination).fetch(FetchDescriptor<MemoryRecord>()).first(where: { $0.id == restored[0].id })?.text, "Newer text")
    }

    func testInvalidArchiveIsRejectedBeforeMutation() throws {
        let container = try MemoryStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try MemoryStore.save(record: nil, text: "Keep me", occurredAt: Date(), photoData: nil, tagText: "", in: context)
        var archive = try MemoryArchive.snapshot(in: context)
        archive.memories.append(archive.memories[0])
        XCTAssertThrowsError(try archive.restore(into: container))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryRecord>()), 1)
        archive.memories.removeLast(); archive.version = 999
        XCTAssertThrowsError(try MemoryArchive.decode(archive.encoded()))
    }

    func testMergePreservesCancelledConnectionsAndManualNotesThenDeleteKeepsRecords() throws {
        let container = try MemoryStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        for text in ["A", "B"] { try MemoryStore.save(record: nil, text: text, occurredAt: Date(), photoData: nil, tagText: "Lake、Water", in: context) }
        let records = try context.fetch(FetchDescriptor<MemoryRecord>())
        let tags = try context.fetch(FetchDescriptor<MemoryTag>())
        let lake = try XCTUnwrap(tags.first { $0.name == "Lake" }), water = try XCTUnwrap(tags.first { $0.name == "Water" })
        water.colorIndex = 5
        try Resonance.set(false, a: records[0].id, b: records[1].id, tag: lake.key, in: context)
        try Resonance.set(true, a: records[0].id, b: records[1].id, tag: water.key, in: context)
        try Resonance.setManual(a: records[0].id, b: records[1].id, note: "Keep this note", in: context)
        try ThemeManagement.merge(keys: [lake.key], into: water, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryTag>()), 1)
        XCTAssertTrue(records.allSatisfy { $0.tags.count == 1 && $0.tags[0].key == water.key })
        XCTAssertEqual(water.colorIndex, 5)
        XCTAssertFalse(Resonance.enabled(records[0].id, records[1].id, tag: water.key, choices: try context.fetch(FetchDescriptor<MemoryLink>())))
        try ThemeManagement.delete(keys: [water.key], in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryRecord>()), 2)
        XCTAssertTrue(records.allSatisfy { $0.tags.isEmpty })
        XCTAssertEqual(Resonance.manual(records[0].id, records[1].id, choices: try context.fetch(FetchDescriptor<MemoryLink>()))?.note, "Keep this note")
    }

    func testMultiplePhotosSurviveReopenAndLegacyCoverRemainsFirst() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("photos.store")
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            try MemoryStore.save(record: nil, text: "Photos", occurredAt: Date(), photoData: Data([1]), tagText: "", extraPhotos: [Data([2])], in: context)
        }
        let container = try MemoryStore.makeContainer(url: url)
        let context = ModelContext(container)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<MemoryRecord>()).first)
        XCTAssertEqual(record.photos, [Data([1]), Data([2])])
        try MemoryStore.save(record: record, text: record.text, occurredAt: record.occurredAt, photoData: Data([2]), tagText: "", extraPhotos: [], in: context)
        XCTAssertEqual(record.photos, [Data([2])])
    }

    func testRangeIncludesWholeLastDayAndAcceptsReversedDates() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 0), end = Date(timeIntervalSince1970: 86400)
        XCTAssertTrue(MemoryReview.contains(Date(timeIntervalSince1970: 172799), from: end, through: start, calendar: calendar))
        XCTAssertFalse(MemoryReview.contains(Date(timeIntervalSince1970: 172800), from: start, through: end, calendar: calendar))
        XCTAssertFalse(MemoryReview.contains(Date(timeIntervalSince1970: -1), from: start, through: end, calendar: calendar))
    }

    func testSharePageRendersAsBoundedLongImage() throws {
        let record = MemoryRecord(text: "Some details to remember.", occurredAt: Date(), photoData: DemoArtwork.data(scene: 1))
        record.title = "A quiet morning"
        let second = MemoryRecord(text: "Returning along the same road, in another season.", occurredAt: Date().addingTimeInterval(86_400), photoData: DemoArtwork.data(scene: 2))
        second.title = "Another afternoon"
        let renderer = ImageRenderer(content: MemorySharePage(records: [record, second], page: 1, total: 1).environment(\.colorScheme, .dark))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        XCTAssertEqual(image.size.width, 390)
        XCTAssertGreaterThan(image.size.height, 390)
        XCTAssertLessThan(image.size.height, 2000)
        let attachment = XCTAttachment(image: image)
        attachment.name = "vertical-silk-long-image"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
