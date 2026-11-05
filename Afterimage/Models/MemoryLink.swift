import Foundation
import SwiftData

/// Automatic links are derived from tags. Persist only explicit user choices.
@Model
final class MemoryLink {
    @Attribute(.unique) var key: String
    var sourceID: UUID
    var targetID: UUID
    var tagKey: String?
    var isEnabled: Bool
    var note: String? = nil

    init(source: UUID, target: UUID, tagKey: String?, enabled: Bool) {
        sourceID = source
        targetID = target
        self.tagKey = tagKey
        isEnabled = enabled
        key = Resonance.key(source, target, tag: tagKey)
    }
}

enum Resonance {
    static func manual(_ a: UUID, _ b: UUID, choices: [MemoryLink]) -> MemoryLink? {
        choices.first { $0.key == key(a, b, tag: nil) && $0.isEnabled }
    }

    static func setManual(a: UUID, b: UUID, note: String, in context: ModelContext) throws {
        guard a != b else { return }
        let choices = try context.fetch(FetchDescriptor<MemoryLink>())
        let link = choices.first { $0.key == key(a, b, tag: nil) }
            ?? MemoryLink(source: a, target: b, tagKey: nil, enabled: true)
        if link.modelContext == nil { context.insert(link) }
        link.isEnabled = true
        let clean = note.trimmingCharacters(in: .whitespacesAndNewlines)
        link.note = clean.isEmpty ? nil : clean
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    static func threadMembers(tag: String, memories: [MemoryRecord], choices: [MemoryLink]) -> Set<UUID> {
        let candidates = memories.filter { $0.tags.contains { $0.key == tag } }.map(\.id)
        return activeIDs(candidates, tag: tag, choices: choices)
    }

    private static func activeIDs(_ candidates: [UUID], tag: String, choices: [MemoryLink]) -> Set<UUID> {
        let valid = Set(candidates)
        guard valid.count > 1 else { return [] }
        var hiddenCounts: [UUID: Int] = [:]
        var seen = Set<String>()
        for choice in choices where choice.tagKey == tag && !choice.isEnabled {
            guard choice.sourceID != choice.targetID, valid.contains(choice.sourceID), valid.contains(choice.targetID),
                  seen.insert(choice.key).inserted else { continue }
            hiddenCounts[choice.sourceID, default: 0] += 1
            hiddenCounts[choice.targetID, default: 0] += 1
        }
        return Set(valid.filter { hiddenCounts[$0, default: 0] < valid.count - 1 })
    }

    static func key(_ a: UUID, _ b: UUID, tag: String?) -> String {
        [a.uuidString, b.uuidString].sorted().joined(separator: ":") + (tag.map { ":tag:\($0)" } ?? ":manual")
    }

    static func sharedTags(_ a: MemoryRecord, _ b: MemoryRecord) -> [MemoryTag] {
        let keys = Set(b.tags.map(\.key))
        return a.tags.filter { keys.contains($0.key) }.sorted { $0.name < $1.name }
    }

    static func enabled(_ a: UUID, _ b: UUID, tag: String?, choices: [MemoryLink]) -> Bool {
        let choice = choices.first { $0.key == key(a, b, tag: tag) }
        return choice?.isEnabled ?? (tag != nil)
    }

    static func related(_ a: MemoryRecord, _ b: MemoryRecord, choices: [MemoryLink]) -> Bool {
        enabled(a.id, b.id, tag: nil, choices: choices) ||
        sharedTags(a, b).contains { enabled(a.id, b.id, tag: $0.key, choices: choices) }
    }

    static func set(_ enabled: Bool, a: UUID, b: UUID, tag: String?, in context: ModelContext) throws {
        guard a != b else { return }
        let choices = try context.fetch(FetchDescriptor<MemoryLink>())
        if let existing = choices.first(where: { $0.key == key(a, b, tag: tag) }) {
            existing.isEnabled = enabled
            if tag == nil && !enabled { existing.note = nil }
        } else {
            context.insert(MemoryLink(source: a, target: b, tagKey: tag, enabled: enabled))
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    struct Edge: Hashable {
        let source: UUID
        let target: UUID

        init(source: UUID, target: UUID) {
            let ids = [source, target].sorted { $0.uuidString < $1.uuidString }
            self.source = ids[0]
            self.target = ids[1]
        }
    }

    static func linkedIDs(in memories: [MemoryRecord], choices: [MemoryLink]) -> Set<UUID> {
        var grouped: [String: [UUID]] = [:]
        for memory in memories {
            for tag in memory.tags { grouped[tag.key, default: []].append(memory.id) }
        }
        var linked = Set<UUID>()
        for (tag, ids) in grouped {
            linked.formUnion(activeIDs(ids, tag: tag, choices: choices))
        }
        let valid = Set(memories.map(\.id))
        for choice in choices where choice.tagKey == nil && choice.isEnabled && valid.contains(choice.sourceID) && valid.contains(choice.targetID) {
            linked.formUnion([choice.sourceID, choice.targetID])
        }
        return linked
    }

    /// Draw chronological neighbours per tag, avoiding a dense all-to-all web.
    static func edges(in ordered: [MemoryRecord], choices: [MemoryLink]) -> [Edge] {
        var grouped: [String: [UUID]] = [:]
        for memory in ordered {
            for tag in memory.tags { grouped[tag.key, default: []].append(memory.id) }
        }
        let hidden = Set(choices.filter { !$0.isEnabled }.map(\.key))
        var edges = Set<Edge>()
        for (tag, ids) in grouped {
            for (a, b) in zip(ids, ids.dropFirst()) where !hidden.contains(key(a, b, tag: tag)) {
                edges.insert(Edge(source: a, target: b))
            }
        }
        let valid = Set(ordered.map(\.id))
        for choice in choices where choice.tagKey == nil && choice.isEnabled && valid.contains(choice.sourceID) && valid.contains(choice.targetID) {
            edges.insert(Edge(source: choice.sourceID, target: choice.targetID))
        }
        return edges.sorted { $0.source.uuidString + $0.target.uuidString < $1.source.uuidString + $1.target.uuidString }
    }
}
