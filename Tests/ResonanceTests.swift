import XCTest
import SwiftData
@testable import Afterimage

@MainActor
final class ResonanceTests: XCTestCase {
    func testIndexedMembershipMatchesEveryThreeNodeSuppressionGraph() {
        let tag = MemoryTag(name: "摄影")
        let records = (0..<3).map { MemoryRecord(text: "\($0)", occurredAt: Date(), tags: [tag]) }
        let pairs = [(0, 1), (0, 2), (1, 2)]
        for mask in 0..<8 {
            var choices = pairs.enumerated().compactMap { index, pair -> MemoryLink? in
                guard mask & (1 << index) != 0 else { return nil }
                return MemoryLink(source: records[pair.0].id, target: records[pair.1].id, tagKey: tag.key, enabled: false)
            }
            // Stale suppression endpoints and repeated choices must not hide live records.
            choices.append(MemoryLink(source: records[0].id, target: UUID(), tagKey: tag.key, enabled: false))
            if let first = choices.first { choices.append(first) }
            let expected = Set(records.filter { a in records.contains { b in a.id != b.id && Resonance.related(a, b, choices: choices) } }.map(\.id))
            XCTAssertEqual(Resonance.threadMembers(tag: tag.key, memories: records, choices: choices), expected)
            XCTAssertEqual(Resonance.linkedIDs(in: records, choices: choices), expected)
        }
        let many = (0..<1000).map { MemoryRecord(text: "\($0)", occurredAt: Date(), tags: [tag]) }
        XCTAssertEqual(Resonance.threadMembers(tag: tag.key, memories: many, choices: []).count, 1000)
    }
    func testExistingPhaseTwoStoreMigratesWithoutDroppingRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("old.store")
        do {
            let schema = Schema([MemoryRecord.self, MemoryTag.self])
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let old = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(old)
            let record = MemoryRecord(text: "升级前的记录", occurredAt: Date())
            context.insert(record)
            try context.save()
        }
        let upgraded = try MemoryStore.makeContainer(url: url)
        let context = ModelContext(upgraded)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MemoryRecord>()).first?.text, "升级前的记录")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryLink>()), 0)
    }

    func testAutomaticSuppressionManualAndDeletionSurviveReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("resonance.store")
        var ids: [UUID] = []
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            for (index, tags) in ["摄影", "摄影", "音乐"].enumerated() {
                try MemoryStore.save(record: nil, text: "\(index)", occurredAt: Date(timeIntervalSince1970: Double(index)), photoData: nil, tagText: tags, in: context)
            }
            let memories = try context.fetch(FetchDescriptor<MemoryRecord>(sortBy: [SortDescriptor(\.occurredAt)]))
            ids = memories.map(\.id)
            XCTAssertTrue(Resonance.related(memories[0], memories[1], choices: []))
            XCTAssertFalse(Resonance.related(memories[0], memories[2], choices: []))
            try Resonance.set(false, a: ids[0], b: ids[1], tag: "摄影", in: context)
            try Resonance.set(true, a: ids[0], b: ids[2], tag: nil, in: context)
            try Resonance.set(true, a: ids[2], b: ids[0], tag: nil, in: context)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryLink>()), 2)
        }
        do {
            let container = try MemoryStore.makeContainer(url: url)
            let context = ModelContext(container)
            let memories = try context.fetch(FetchDescriptor<MemoryRecord>(sortBy: [SortDescriptor(\.occurredAt)]))
            var choices = try context.fetch(FetchDescriptor<MemoryLink>())
            XCTAssertFalse(Resonance.related(memories[0], memories[1], choices: choices))
            XCTAssertTrue(Resonance.related(memories[0], memories[2], choices: choices))
            XCTAssertEqual(Resonance.edges(in: memories, choices: choices).count, 1)
            try Resonance.set(true, a: ids[0], b: ids[1], tag: "摄影", in: context)
            try Resonance.set(false, a: ids[0], b: ids[2], tag: nil, in: context)
            choices = try context.fetch(FetchDescriptor<MemoryLink>())
            XCTAssertTrue(Resonance.related(memories[0], memories[1], choices: choices))
            XCTAssertFalse(Resonance.related(memories[0], memories[2], choices: choices))
            try MemoryStore.save(record: memories[1], text: "改标签", occurredAt: memories[1].occurredAt, photoData: nil, tagText: "音乐", in: context)
            XCTAssertFalse(Resonance.related(memories[0], memories[1], choices: choices))
            try MemoryStore.delete(memories[0], in: context)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryLink>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MemoryRecord>()), 2)
        }
    }
}
