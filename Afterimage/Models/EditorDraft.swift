import Foundation
import CryptoKit

struct EditorDraft: Codable, Equatable {
    var title: String
    var text: String
    var date: Date
    var tags: String
    var photos: [Data]
    var choices: [String: Bool]
}

actor EditorDraftStore {
    static let shared = EditorDraftStore()
    private func url(scope: String, recordID: UUID?) throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("EditorDrafts", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let hash = SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(hash + "-" + (recordID?.uuidString ?? "new") + ".json")
    }
    func load(scope: String, recordID: UUID?) throws -> EditorDraft? {
        let path = try url(scope: scope, recordID: recordID)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        return try JSONDecoder().decode(EditorDraft.self, from: Data(contentsOf: path))
    }
    func save(_ draft: EditorDraft, scope: String, recordID: UUID?) throws {
        try Task.checkCancellation()
        try JSONEncoder().encode(draft).write(to: url(scope: scope, recordID: recordID), options: [.atomic, .completeFileProtectionUnlessOpen])
    }
    func remove(scope: String, recordID: UUID?) throws {
        let path = try url(scope: scope, recordID: recordID)
        if FileManager.default.fileExists(atPath: path.path) { try FileManager.default.removeItem(at: path) }
    }
}
