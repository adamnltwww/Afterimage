import Foundation
import SwiftData

enum ThemeManagement {
    @MainActor static func delete(keys: Set<String>, in context: ModelContext) throws {
        do {
            for record in try context.fetch(FetchDescriptor<MemoryRecord>()) { record.tags.removeAll { keys.contains($0.key) } }
            for link in try context.fetch(FetchDescriptor<MemoryLink>()) where link.tagKey.map(keys.contains) == true { context.delete(link) }
            for tag in try context.fetch(FetchDescriptor<MemoryTag>()) where keys.contains(tag.key) { context.delete(tag) }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    @MainActor static func merge(keys: Set<String>, into target: MemoryTag, in context: ModelContext) throws {
        let sources = keys.subtracting([target.key])
        guard !sources.isEmpty else { return }
        let affected = sources.union([target.key])
        do {
            for record in try context.fetch(FetchDescriptor<MemoryRecord>()) where record.tags.contains(where: { sources.contains($0.key) }) {
                record.tags.removeAll { sources.contains($0.key) }
                if !record.tags.contains(where: { $0.key == target.key }) { record.tags.append(target) }
            }
            struct Choice { var source: UUID; var target: UUID; var enabled: Bool; var note: String? }
            var choices: [String: Choice] = [:]
            var targets: [String: MemoryLink] = [:]
            for link in try context.fetch(FetchDescriptor<MemoryLink>()) where link.tagKey.map(affected.contains) == true {
                let key = Resonance.key(link.sourceID, link.targetID, tag: target.key)
                if var choice = choices[key] {
                    // An explicit cancellation survives merging equivalent themes.
                    choice.enabled = choice.enabled && link.isEnabled; choices[key] = choice
                } else { choices[key] = Choice(source: link.sourceID, target: link.targetID, enabled: link.isEnabled, note: link.note) }
                if link.tagKey == target.key { targets[key] = link } else { context.delete(link) }
            }
            for choice in choices.values {
                let key = Resonance.key(choice.source, choice.target, tag: target.key)
                if let existing = targets[key] { existing.isEnabled = choice.enabled; continue }
                let link = MemoryLink(source: choice.source, target: choice.target, tagKey: target.key, enabled: choice.enabled)
                link.note = choice.note; context.insert(link)
            }
            for tag in try context.fetch(FetchDescriptor<MemoryTag>()) where sources.contains(tag.key) { context.delete(tag) }
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
