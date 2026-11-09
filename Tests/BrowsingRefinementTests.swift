import XCTest
import SwiftData
@testable import Afterimage

@MainActor
final class BrowsingRefinementTests: XCTestCase {
    func testUndoRestoresIdentityPhotosThemesAndExplicitLinks() throws {
        let container = try MemoryStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let tag = MemoryTag(name: "旅行")
        tag.key = "stable-renamed-key"
        tag.colorIndex = 3
        let record = MemoryRecord(text: "正文", occurredAt: Date(timeIntervalSince1970: 100), photoData: Data([1, 2, 3]), tags: [tag])
        record.title = "标题"
        record.createdAt = Date(timeIntervalSince1970: 200)
        record.additionalPhotoData = try JSONEncoder().encode([Data([4, 5])])
        let other = MemoryRecord(text: "另一条", occurredAt: Date(), tags: [tag])
        context.insert(record)
        context.insert(other)
        try context.save()
        try Resonance.setManual(a: record.id, b: other.id, note: "手动关联说明", in: context)
        try Resonance.set(false, a: record.id, b: other.id, tag: tag.key, in: context)
        let id = record.id
        let snapshot = try DeletedMemory(record: record, in: context)
        try MemoryStore.delete(record, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryLink>()), 0)
        let restored = try snapshot.restore(in: context)
        XCTAssertEqual(restored.id, id)
        XCTAssertEqual(restored.title, "标题")
        XCTAssertEqual(restored.text, "正文")
        XCTAssertEqual(restored.createdAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(restored.occurredAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(restored.photos, [Data([1, 2, 3]), Data([4, 5])])
        XCTAssertEqual(restored.tags.first?.key, "stable-renamed-key")
        XCTAssertEqual(restored.tags.first?.colorIndex, 3)
        let links = try context.fetch(FetchDescriptor<MemoryLink>())
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links.first(where: { $0.tagKey == nil })?.note, "手动关联说明")
        XCTAssertEqual(links.first(where: { $0.tagKey != nil })?.isEnabled, false)
        _ = try snapshot.restore(in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryRecord>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryLink>()), 2)
    }

    func testUndoDoesNotRecreateLinkToDeletedOtherRecord() throws {
        let container = try MemoryStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let first = MemoryRecord(text: "一", occurredAt: Date())
        let second = MemoryRecord(text: "二", occurredAt: Date())
        context.insert(first); context.insert(second)
        try context.save()
        try Resonance.setManual(a: first.id, b: second.id, note: "联系", in: context)
        let snapshot = try DeletedMemory(record: first, in: context)
        try MemoryStore.delete(first, in: context)
        try MemoryStore.delete(second, in: context)
        _ = try snapshot.restore(in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryLink>()), 0)
    }

    func testScrubDateUsesClosestVisibleRecordAndClampsEndpoints() {
        let dates = [0.0, 86400, 86400 * 365].map { Date(timeIntervalSince1970: $0) }
        let layout = TimelineLayout(dates: dates, viewport: 390)
        XCTAssertNil(TimelineLayout(dates: [], viewport: 390).nearestIndex(at: 0, viewport: 390))
        XCTAssertEqual(layout.nearestIndex(at: -10000, viewport: 390), 0)
        XCTAssertEqual(layout.nearestIndex(at: 10000, viewport: 390), 2)
        for index in dates.indices {
            XCTAssertEqual(layout.nearestIndex(at: layout.positions[index] - 195, viewport: 390), index)
        }
    }
}
