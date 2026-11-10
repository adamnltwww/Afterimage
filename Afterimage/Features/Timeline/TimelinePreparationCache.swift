import Foundation

/// Cache only derived timeline data; live record bodies and photos still come from SwiftData.
final class TimelinePreparationCache {
    struct RecordKey: Equatable {
        let id: UUID
        let occurredAt: Date
        let createdAt: Date
        let tags: [TagKey]
    }
    struct TagKey: Equatable { let key: String; let name: String; let color: Int? }
    struct LinkKey: Equatable { let key: String; let enabled: Bool }
    struct Key: Equatable {
        let records: [RecordKey]
        let links: [LinkKey]
        let filter: TimelineDateFilter
        let width: Double
        let theme: String?
        let focus: UUID?
    }
    struct Value {
        let memories: [MemoryRecord]
        let themes: [MemoryTag]
        let layout: TimelineLayout
        let linkedIDs: Set<UUID>
        let spans: [ThemeWeave.Span]
        let members: Set<UUID>
        let memberPositions: [Double]
    }
    private var key: Key?
    private var value: Value?
    func resolve(key: Key, build: () -> Value) -> Value {
        if self.key == key, let value { return value }
        let result = build()
        self.key = key
        value = result
        return result
    }
}
