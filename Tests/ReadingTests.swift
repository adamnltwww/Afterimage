import XCTest
import SwiftData
@testable import Afterimage

@MainActor
final class ReadingTests: XCTestCase {
    func testRenameRetainsIdentityColorAndSuppressionAfterReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("reading.store")
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            for index in 0..<2 {
                try MemoryStore.save(record: nil, text: "\(index)", occurredAt: Date(timeIntervalSince1970: Double(index)), photoData: nil, tagText: "Lake", in: context)
            }
            let records = try context.fetch(FetchDescriptor<MemoryRecord>(sortBy: [SortDescriptor(\.occurredAt)]))
            let tag = try XCTUnwrap(records[0].tags.first)
            tag.colorIndex = 4
            try Resonance.set(false, a: records[0].id, b: records[1].id, tag: tag.key, in: context)
            try MemoryStore.rename(tag, to: "  Water  ", in: context)
            XCTAssertEqual(tag.key, "lake")
            try MemoryStore.save(record: records[0], text: "edited", occurredAt: records[0].occurredAt, photoData: nil, tagText: "water", in: context)
            XCTAssertEqual(records[0].tags.first?.key, "lake")
            try MemoryStore.save(record: nil, text: "A new theme with the former name", occurredAt: Date(), photoData: nil, tagText: "Lake", in: context)
        }
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            let tags = try context.fetch(FetchDescriptor<MemoryTag>())
            let renamed = try XCTUnwrap(tags.first { $0.name == "Water" })
            let recreated = try XCTUnwrap(tags.first { $0.name == "Lake" })
            XCTAssertEqual(renamed.key, "lake")
            XCTAssertNotEqual(recreated.key, renamed.key)
            XCTAssertEqual(renamed.colorIndex, 4)
            XCTAssertEqual(renamed.memories.count, 2, "Suppressed records still belong to the reading space")
            let choices = try context.fetch(FetchDescriptor<MemoryLink>())
            XCTAssertTrue(Resonance.threadMembers(tag: renamed.key, memories: renamed.memories, choices: choices).isEmpty)
            XCTAssertEqual(choices.first?.tagKey, renamed.key)
            XCTAssertEqual(choices.first?.isEnabled, false)
        }
    }

    func testNormalizedRenameCollisionAndRemovingMembershipDoNotDeleteRecords() throws {
        let container = try MemoryStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try MemoryStore.save(record: nil, text: "One", occurredAt: Date(), photoData: nil, tagText: "Café、Lake", in: context)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<MemoryRecord>()).first)
        let tag = try XCTUnwrap(record.tags.first { $0.name == "Lake" })
        XCTAssertThrowsError(try MemoryStore.rename(tag, to: " CAFE\u{301} ", in: context))
        XCTAssertThrowsError(try MemoryStore.rename(tag, to: "A、B", in: context))
        XCTAssertThrowsError(try MemoryStore.rename(tag, to: " \n ", in: context))
        XCTAssertEqual(tag.name, "Lake")
        try MemoryStore.remove(tag, from: record, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryRecord>()), 1)
        XCTAssertEqual(record.tags.map(\.name), ["Café"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryTag>()), 2)
    }

    func testManualNoteIsBidirectionalAndIndependentOfAutomaticSources() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("notes.store")
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            for text in ["Spring", "Autumn"] {
                try MemoryStore.save(record: nil, text: text, occurredAt: Date(), photoData: nil, tagText: "Lake", in: context)
            }
            let records = try context.fetch(FetchDescriptor<MemoryRecord>())
            let a = records[0].id, b = records[1].id
            try Resonance.setManual(a: a, b: b, note: "Same place", in: context)
            try Resonance.setManual(a: b, b: a, note: "Three months later", in: context)
            let choices = try context.fetch(FetchDescriptor<MemoryLink>())
            XCTAssertEqual(choices.count, 1)
            XCTAssertEqual(Resonance.manual(a, b, choices: choices)?.note, "Three months later")
            XCTAssertEqual(Resonance.manual(b, a, choices: choices)?.note, "Three months later")
        }
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            let records = try context.fetch(FetchDescriptor<MemoryRecord>())
            let a = records[0].id, b = records[1].id
            var choices = try context.fetch(FetchDescriptor<MemoryLink>())
            XCTAssertEqual(Resonance.manual(b, a, choices: choices)?.note, "Three months later")
            try Resonance.set(false, a: a, b: b, tag: nil, in: context)
            choices = try context.fetch(FetchDescriptor<MemoryLink>())
            XCTAssertNil(Resonance.manual(a, b, choices: choices))
            XCTAssertTrue(Resonance.related(records[0], records[1], choices: choices))
            try Resonance.setManual(a: a, b: b, note: "", in: context)
            try Resonance.set(false, a: a, b: b, tag: "lake", in: context)
            choices = try context.fetch(FetchDescriptor<MemoryLink>())
            XCTAssertNotNil(Resonance.manual(a, b, choices: choices))
            XCTAssertNil(Resonance.manual(a, b, choices: choices)?.note)
            XCTAssertTrue(Resonance.related(records[0], records[1], choices: choices))
        }
    }

    func testSearchFindsBodyAndRenamedThemeWithBoundedUnicodeExcerpt() {
        let tag = MemoryTag(name: "Café")
        let body = String(repeating: "🌱旧日细节", count: 30) + "湖面的微光" + String(repeating: "后来", count: 100)
        let record = MemoryRecord(text: body, occurredAt: Date(), tags: [tag])
        record.title = "Evening"
        XCTAssertTrue(MemorySearch.matches(record, query: " EVENING "))
        XCTAssertTrue(MemorySearch.matches(record, query: "湖面的微光"))
        XCTAssertTrue(MemorySearch.matches(record, query: "cafe"))
        XCTAssertFalse(MemorySearch.matches(record, query: "Missing"))
        let excerpt = MemorySearch.excerpt(body, query: "湖面的微光")
        XCTAssertTrue(excerpt?.contains("湖面的微光") == true)
        XCTAssertLessThanOrEqual(excerpt?.count ?? 0, 102)
        XCTAssertNil(MemorySearch.excerpt(body, query: "  "))
        tag.name = "Reading"
        XCTAssertTrue(MemorySearch.matches(record, query: "reading"))
        XCTAssertFalse(MemorySearch.matches(record, query: "cafe"))
    }
}
