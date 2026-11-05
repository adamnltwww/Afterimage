import Foundation
import SwiftData

struct MemoryArchive: Codable {
    var format = "AFTERIMAGE"
    var version = 1
    var createdAt = Date()
    var memories: [Moment]
    var themes: [Theme]
    var links: [Link]
    struct Moment: Codable {
        var id: UUID
        var title: String?
        var text: String
        var occurredAt: Date
        var createdAt: Date
        var photos: [Data]
        var themeKeys: [String]
    }
    struct Theme: Codable { var key: String; var name: String; var colorIndex: Int? }
    struct Link: Codable { var source: UUID; var target: UUID; var themeKey: String?; var enabled: Bool; var note: String? }
    enum ArchiveError: LocalizedError {
        case invalid
        var errorDescription: String? { "这份文件不是完整、受支持的 AFTERIMAGE 备份，现有记录未改变。" }
    }

    @MainActor static func snapshot(in context: ModelContext) throws -> Self {
        let memories = try context.fetch(FetchDescriptor<MemoryRecord>()).map {
            Moment(id: $0.id, title: $0.title, text: $0.text, occurredAt: $0.occurredAt, createdAt: $0.createdAt, photos: $0.photos, themeKeys: $0.tags.map(\.key))
        }
        let themes = try context.fetch(FetchDescriptor<MemoryTag>()).map { Theme(key: $0.key, name: $0.name, colorIndex: $0.colorIndex) }
        let links = try context.fetch(FetchDescriptor<MemoryLink>()).map { Link(source: $0.sourceID, target: $0.targetID, themeKey: $0.tagKey, enabled: $0.isEnabled, note: $0.note) }
        return Self(memories: memories, themes: themes, links: links)
    }

    func encoded() throws -> Data {
        let data = try JSONEncoder().encode(self)
        guard data.count <= 256 * 1024 * 1024 else { throw ArchiveError.invalid }
        return data
    }
    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 256 * 1024 * 1024 else { throw ArchiveError.invalid }
        let value = try JSONDecoder().decode(Self.self, from: data)
        try value.validate()
        return value
    }

    func validate() throws {
        let ids = Set(memories.map(\.id)), keys = Set(themes.map(\.key))
        guard format == "AFTERIMAGE", version == 1, ids.count == memories.count, keys.count == themes.count,
              memories.count <= 100_000, themes.allSatisfy({ !$0.key.isEmpty && !TagInput.names(from: $0.name).isEmpty }),
              memories.allSatisfy({ Set($0.themeKeys).isSubset(of: keys) && $0.photos.count <= 9 && $0.occurredAt.timeIntervalSince1970.isFinite && $0.createdAt.timeIntervalSince1970.isFinite }),
              links.allSatisfy({ $0.source != $0.target && ids.contains($0.source) && ids.contains($0.target) && ($0.themeKey == nil || keys.contains($0.themeKey!)) }) else { throw ArchiveError.invalid }
        guard Set(links.map { Resonance.key($0.source, $0.target, tag: $0.themeKey) }).count == links.count else { throw ArchiveError.invalid }
    }

    /// Restore missing items. Current versions of existing UUIDs always win.
    @MainActor func restore(into container: ModelContainer) throws -> Int {
        try validate()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let existing = try context.fetch(FetchDescriptor<MemoryRecord>())
            var ids = Set(existing.map(\.id))
            let knownTags = try context.fetch(FetchDescriptor<MemoryTag>())
            var tagsByKey = Dictionary(uniqueKeysWithValues: knownTags.map { ($0.key, $0) })
            var remap: [String: String] = [:]
            for saved in themes {
                if let known = tagsByKey[saved.key] ?? tagsByKey.values.first(where: { TagInput.key(for: $0.name) == TagInput.key(for: saved.name) }) {
                    remap[saved.key] = known.key
                } else {
                    let tag = MemoryTag(name: saved.name); tag.key = saved.key; tag.colorIndex = saved.colorIndex
                    context.insert(tag); tagsByKey[tag.key] = tag; remap[saved.key] = tag.key
                }
            }
            var count = 0
            for saved in memories where !ids.contains(saved.id) {
                let record = MemoryRecord(text: saved.text, occurredAt: saved.occurredAt, photoData: saved.photos.first)
                record.id = saved.id; record.title = saved.title; record.createdAt = saved.createdAt
                record.additionalPhotoData = saved.photos.count > 1 ? try JSONEncoder().encode(Array(saved.photos.dropFirst())) : nil
                record.tags = Array(Set(saved.themeKeys.compactMap { remap[$0] })).compactMap { tagsByKey[$0] }
                context.insert(record); ids.insert(record.id); count += 1
            }
            var linkKeys = Set(try context.fetch(FetchDescriptor<MemoryLink>()).map(\.key))
            for saved in links {
                let theme = saved.themeKey.flatMap { remap[$0] }
                let key = Resonance.key(saved.source, saved.target, tag: theme)
                guard linkKeys.insert(key).inserted else { continue }
                let link = MemoryLink(source: saved.source, target: saved.target, tagKey: theme, enabled: saved.enabled)
                link.note = saved.note; context.insert(link)
            }
            try context.save()
            return count
        } catch { context.rollback(); throw error }
    }
}
