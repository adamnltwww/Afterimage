import Foundation
import SwiftData

@Model
final class MemoryRecord {
    @Attribute(.unique) var id: UUID
    var text: String
    var title: String? = nil
    var occurredAt: Date
    var createdAt: Date
    @Attribute(.externalStorage) var photoData: Data?
    @Attribute(.externalStorage) var additionalPhotoData: Data? = nil
    @Relationship(inverse: \MemoryTag.memories) var tags: [MemoryTag]

    init(text: String, occurredAt: Date, photoData: Data? = nil, tags: [MemoryTag] = []) {
        id = UUID()
        self.text = text
        self.occurredAt = occurredAt
        createdAt = Date()
        self.photoData = photoData
        self.tags = tags
    }

    var displayTitle: String {
        let explicit = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return explicit.isEmpty ? Self.suggestedTitle(from: text) : explicit
    }

    var photos: [Data] {
        (photoData.map { [$0] } ?? []) + ((additionalPhotoData.flatMap { try? JSONDecoder().decode([Data].self, from: $0) }) ?? [])
    }

    static func suggestedTitle(from text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = clean.firstIndex { "。！？!?\n".contains($0) }
        let sentence = end.map { String(clean[...$0]) } ?? clean
        return String(sentence.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@Model
final class MemoryTag {
    @Attribute(.unique) var key: String
    var name: String
    var colorIndex: Int? = nil
    var memories: [MemoryRecord]

    init(name: String) {
        self.name = name
        key = TagInput.key(for: name)
        memories = []
    }
}

enum TagInput {
    static func key(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping.lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    static func names(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",，、\n")
        var seen = Set<String>()
        return text.components(separatedBy: separators).compactMap { component in
            let name = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(key(for: name)).inserted else { return nil }
            return name
        }
    }
}

enum MemoryStore {
    enum ValidationError: LocalizedError {
        case emptyText
        var errorDescription: String? { "请填写标题或正文，再保存这个瞬间。" }
    }
    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([MemoryRecord.self, MemoryTag.self, MemoryLink.self])
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        // Optional additions allow existing stores to migrate without replacing body or photos.
        let context = ModelContext(container)
        let tags = try context.fetch(FetchDescriptor<MemoryTag>()).sorted { $0.key < $1.key }
        var used = tags.compactMap(\.colorIndex)
        for tag in tags where tag.colorIndex == nil {
            let index = ThemePalette.nextIndex(used: used)
            tag.colorIndex = index
            used.append(index)
        }
        if context.hasChanges { try context.save() }
        return container
    }

    static func save(record: MemoryRecord?, text: String, occurredAt: Date,
                     photoData: Data?, tagText: String, title: String? = nil, extraPhotos: [Data]? = nil, in context: ModelContext) throws {
        let heading = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !heading.isEmpty else {
            throw ValidationError.emptyText
        }
        let existingTags = try context.fetch(FetchDescriptor<MemoryTag>())
        var used = existingTags.compactMap(\.colorIndex)
        let tags = TagInput.names(from: tagText).map { name in
            if let tag = existingTags.first(where: { TagInput.key(for: $0.name) == TagInput.key(for: name) }) { return tag }
            let tag = MemoryTag(name: name)
            // A renamed theme retains its identity. Its former name may become a new theme.
            if existingTags.contains(where: { $0.key == tag.key }) { tag.key = UUID().uuidString }
            tag.colorIndex = ThemePalette.nextIndex(used: used)
            used.append(tag.colorIndex!)
            context.insert(tag)
            return tag
        }
        let target = record ?? MemoryRecord(text: text, occurredAt: occurredAt)
        if record == nil { context.insert(target) }
        target.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        target.title = heading.isEmpty ? MemoryRecord.suggestedTitle(from: text) : String(heading.prefix(40))
        target.occurredAt = occurredAt
        target.photoData = photoData
        if let extraPhotos { target.additionalPhotoData = extraPhotos.isEmpty ? nil : try JSONEncoder().encode(extraPhotos) }
        target.tags = tags
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    enum ThemeError: LocalizedError {
        case invalidName, duplicateName
        var errorDescription: String? {
            switch self {
            case .invalidName: return "请填写一个主题名称，不使用逗号、顿号或换行。"
            case .duplicateName: return "已有同名主题，请换一个名称。"
            }
        }
    }

    static func rename(_ tag: MemoryTag, to rawName: String, in context: ModelContext) throws {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.rangeOfCharacter(from: CharacterSet(charactersIn: ",，、\n\r")) == nil else {
            throw ThemeError.invalidName
        }
        let tags = try context.fetch(FetchDescriptor<MemoryTag>())
        guard !tags.contains(where: { $0.key != tag.key && TagInput.key(for: $0.name) == TagInput.key(for: name) }) else {
            throw ThemeError.duplicateName
        }
        tag.name = name
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    static func remove(_ tag: MemoryTag, from record: MemoryRecord, in context: ModelContext) throws {
        record.tags.removeAll { $0.key == tag.key }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    static func delete(_ record: MemoryRecord, in context: ModelContext) throws {
        let choices = try context.fetch(FetchDescriptor<MemoryLink>())
        for choice in choices where choice.sourceID == record.id || choice.targetID == record.id {
            context.delete(choice)
        }
        context.delete(record)
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    static func makeDemoContainer() throws -> ModelContainer {
        let container = try makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let samples: [(Int, Int, String, String)] = [
            (1, 8, "在书页里发现去年夹进去的车票。", "读书、日常"),
            (1, 22, "傍晚的城市，窗户一盏一盏亮起来。", "摄影、城市"),
            (2, 14, "朋友分享了一首歌，回家的路变短了。", "音乐、朋友"),
            (2, 28, "常去的咖啡店换了新杯子。", "日常、咖啡"),
            (3, 12, "第一次去湖边拍日出。", "摄影、湖边"),
            (3, 28, "绕远路散步，发现一条安静的小巷。", "散步、城市"),
            (4, 6, "和朋友一起听了一场演出。", "音乐、朋友"),
            (4, 23, "把喜欢的那本书借给了朋友。", "读书、朋友"),
            (5, 18, "买了一支新镜头。", "摄影"),
            (6, 2, "列车越过河岸，窗外忽然开阔起来。", "旅行、摄影"),
            (6, 21, "夏至的湖边，很晚才等到天黑。", "湖边、夏天"),
            (7, 3, "雨后拍到了很喜欢的照片。", "摄影、夏天"),
            (7, 19, "晚风里听完了一整张专辑。", "音乐、夏天"),
            (8, 15, "再次听到那首歌。", "音乐、夏天"),
            (8, 29, "拍下末班车离站后，空下来的街口。", "摄影、城市"),
            (9, 10, "旅途中寄出的明信片，今天终于收到了。", "旅行、日常"),
            (9, 24, "读完最后一页，坐着发了一会儿呆。", "读书、日常"),
            (10, 20, "又回到了春天拍日出的湖边。", "摄影、湖边")
        ]
        for (month, day, text, tags) in samples {
            let date = Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: 7))!
            let scene: Int? = month == 1 && day == 22 ? 0 : month == 3 && day == 12 ? 1 : month == 6 && day == 2 ? 2 : month == 8 && day == 29 ? 3 : nil
            let detail: String
            switch scene {
            case 0: detail = "在桥上停了很久，看对岸的窗户从暮色里慢慢浮出来。没有急着按快门，只是等天光和灯光刚好一样亮的那几分钟。\n\n回家翻照片时，才发现最喜欢的是最后一张：画面里没什么特别的事，却记得那天风吹在脸上的感觉。"
            case 1: detail = "五点多出门，湖边还没有什么人。架好相机之后等了半个小时，太阳并没有从预想的位置升起。\n\n但水面先亮了起来。那一刻觉得，早起的意义也许就是有机会看见一天开始的样子。"
            case 2: detail = "列车驶出隧道时，河岸突然展开。前一秒还是玻璃上的倒影，后一秒全是水和天空。想拍下来，又怕低头找相机会错过，于是先看了一会儿。"
            case 3: detail = "末班车开走后，街口一下安静下来。店招还亮着，路面留着一点雨水，远处有人收起最后一把椅子。\n\n等红灯的时候拍了这张。它没有记录什么大事，只留下了城市快睡着之前的一分钟。"
            default: detail = text
            }
            try save(record: nil, text: detail, occurredAt: date, photoData: scene.flatMap { DemoArtwork.data(scene: $0) }, tagText: tags, title: text, in: context)
        }
        let records = try context.fetch(FetchDescriptor<MemoryRecord>(sortBy: [SortDescriptor(\.occurredAt)]))
        for (a, b, note) in [(4, 17, "同一片湖，春天的日出与秋天的重访。"),
                             (0, 7, "从书里的旧车票，到把这本书借给朋友。"),
                             (2, 6, "朋友分享的歌，后来在现场一起听到了。" )] {
            try Resonance.setManual(a: records[a].id, b: records[b].id, note: note, in: context)
        }
        return container
    }
}
