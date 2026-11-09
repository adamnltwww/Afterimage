import Foundation

/// A plain ZIP of readable text, metadata and the exact image bytes stored by the app.
enum ContentExport {
    struct Entry { let name: String; let data: Data }
    enum ExportError: LocalizedError {
        case tooLarge
        var errorDescription: String? { "内容较多，请缩小导出时间范围后重试。" }
    }

    static func entries(archive: MemoryArchive) throws -> [Entry] {
        let names = Dictionary(uniqueKeysWithValues: archive.themes.map { ($0.key, $0.name) })
        var files = [Entry(name: "README.txt", data: Data("AFTERIMAGE 内容导出\n每个文件夹对应一个瞬间，包含完整文字、时间、主题和照片。\n照片为 App 导入时保存的浏览副本，不是相册原片；第一张是封面。\nmetadata.json 提供记录和关联信息，可用于内容迁移。\n".utf8))]
        for moment in archive.memories.sorted(by: { $0.occurredAt < $1.occurredAt }) {
            let folder = moment.id.uuidString + "/"
            let heading = moment.title ?? MemoryRecord.suggestedTitle(from: moment.text)
            let body = "\(heading)\n\n发生时间：\(moment.occurredAt.ISO8601Format())\n创建时间：\(moment.createdAt.ISO8601Format())\n主题：\(moment.themeKeys.compactMap { names[$0] }.joined(separator: "、"))\n\n\(moment.text)\n"
            files.append(Entry(name: folder + "record.txt", data: Data(body.utf8)))
            for (index, photo) in moment.photos.enumerated() {
                let suffix = photo.starts(with: [0x89, 0x50, 0x4e, 0x47]) ? "png" : photo.starts(with: [0xff, 0xd8]) ? "jpg" : "bin"
                files.append(Entry(name: folder + String(format: "%02d", index + 1) + (index == 0 ? "-cover." : ".") + suffix, data: photo))
            }
        }
        var metadata = archive
        for index in metadata.memories.indices { metadata.memories[index].photos = [] }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        files.append(Entry(name: "metadata.json", data: try encoder.encode(metadata)))
        return files
    }

    static func zip(_ entries: [Entry]) throws -> Data {
        guard entries.count < 65535, entries.reduce(0, { $0 + $1.data.count }) < 256 * 1024 * 1024 else { throw ExportError.tooLarge }
        var output = Data(), directory = Data()
        for entry in entries {
            let name = Data(entry.name.utf8), size = UInt32(entry.data.count), crc = crc32(entry.data)
            guard name.count < 65535 else { throw ExportError.tooLarge }
            let offset = UInt32(output.count)
            output.le32(0x04034b50); output.le16(20); output.le16(0x0800); output.le16(0)
            output.le16(0); output.le16(33); output.le32(crc); output.le32(size); output.le32(size)
            output.le16(UInt16(name.count)); output.le16(0); output.append(name); output.append(entry.data)
            directory.le32(0x02014b50); directory.le16(20); directory.le16(20); directory.le16(0x0800); directory.le16(0)
            directory.le16(0); directory.le16(33); directory.le32(crc); directory.le32(size); directory.le32(size)
            directory.le16(UInt16(name.count)); directory.le16(0); directory.le16(0); directory.le16(0); directory.le16(0)
            directory.le32(0); directory.le32(offset); directory.append(name)
        }
        let start = UInt32(output.count)
        output.append(directory)
        output.le32(0x06054b50); output.le16(0); output.le16(0)
        output.le16(UInt16(entries.count)); output.le16(UInt16(entries.count))
        output.le32(UInt32(directory.count)); output.le32(start); output.le16(0)
        return output
    }
    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0) }
        }
        return ~crc
    }
}

private extension Data {
    mutating func le16(_ value: UInt16) { append(UInt8(truncatingIfNeeded: value)); append(UInt8(truncatingIfNeeded: value >> 8)) }
    mutating func le32(_ value: UInt32) { le16(UInt16(truncatingIfNeeded: value)); le16(UInt16(truncatingIfNeeded: value >> 16)) }
}
