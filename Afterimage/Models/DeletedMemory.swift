import Foundation
import SwiftData

/// Value snapshot captured before deletion, including photos and explicit link choices.
struct DeletedMemory {
    struct Tag {
        let key: String
        let name: String
        let color: Int?
    }
    struct Link {
        let source: UUID
        let target: UUID
        let tag: String?
        let enabled: Bool
        let note: String?
    }
    let id: UUID
    let text: String
    let title: String?
    let occurredAt: Date
    let createdAt: Date
    let photo: Data?
    let extraPhotos: Data?
    let tags: [Tag]
    let links: [Link]

    init(record: MemoryRecord, in context: ModelContext) throws {
        id = record.id
        text = record.text
        title = record.title
        occurredAt = record.occurredAt
        createdAt = record.createdAt
        photo = record.photoData
        extraPhotos = record.additionalPhotoData
        tags = record.tags.map { Tag(key: $0.key, name: $0.name, color: $0.colorIndex) }
        links = try context.fetch(FetchDescriptor<MemoryLink>())
            .filter { $0.sourceID == record.id || $0.targetID == record.id }
            .map { Link(source: $0.sourceID, target: $0.targetID, tag: $0.tagKey, enabled: $0.isEnabled, note: $0.note) }
    }

    @discardableResult
    func restore(in context: ModelContext) throws -> MemoryRecord {
        let records = try context.fetch(FetchDescriptor<MemoryRecord>())
        if let existing = records.first(where: { $0.id == id }) { return existing }
        let existingTags = try context.fetch(FetchDescriptor<MemoryTag>())
        let restoredTags = tags.map { saved -> MemoryTag in
            if let tag = existingTags.first(where: { $0.key == saved.key }) { return tag }
            let tag = MemoryTag(name: saved.name)
            tag.key = saved.key
            tag.colorIndex = saved.color
            context.insert(tag)
            return tag
        }
        let record = MemoryRecord(text: text, occurredAt: occurredAt, photoData: photo, tags: restoredTags)
        record.id = id
        record.title = title
        record.createdAt = createdAt
        record.additionalPhotoData = extraPhotos
        context.insert(record)
        let available = Set(records.map(\.id)).union([id])
        for saved in links where available.contains(saved.source) && available.contains(saved.target) {
            let link = MemoryLink(source: saved.source, target: saved.target, tagKey: saved.tag, enabled: saved.enabled)
            link.note = saved.note
            context.insert(link)
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
        return record
    }
}
