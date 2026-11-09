import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw MemoryArchive.ArchiveError.invalid }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var document: ArchiveDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var pending: MemoryArchive?
    @State private var message: String?
    @State private var busy = false
    @State private var confirmRestore = false
    @State private var showContentExport = false
    @AppStorage("backup.lastExport") private var lastExport = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        Label("留一份，给以后的自己。", systemImage: "icloud").font(.title3.weight(.light)).padding(.vertical, 12)
                        Text("将记录、照片、主题与关联一起保存到 iCloud Drive。换设备后，从同一份文件恢复。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Section {
                        Button("保存备份到 iCloud Drive", systemImage: "icloud.and.arrow.up") { export() }
                            .accessibilityIdentifier("backup.export")
                        Button("从 iCloud Drive 恢复", systemImage: "icloud.and.arrow.down") { importing = true }
                            .accessibilityIdentifier("backup.import")
                        if busy { ProgressView("正在准备…") }
                        if lastExport > 0 {
                            Text("上次导出：\(Date(timeIntervalSince1970: lastExport).formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("在系统“文件”窗口中选择 iCloud Drive；也可保存到本机。备份需要手动创建，不是实时同步。文件包含完整内容，请保存在你信任的位置。")
                    }
                    Section {
                        Button("导出文字与照片", systemImage: "doc.zipper") { showContentExport = true }
                    } header: { Text("独立阅读与迁移") } footer: {
                        Text("导出可直接阅读的文字与 App 中的照片副本，不需要通过 AFTERIMAGE 恢复。")
                    }
                    Section {
                        Text("恢复会补回缺失的记录，同一瞬间不会重复导入，也不会覆盖手机上已修改的版本。恢复前先核对文件中的记录数量。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.listRowBackground(AfterimageStyle.surface)
            }
            .disabled(busy).scrollContentBackground(.hidden).afterimageSheetSurface().background(AfterimageStyle.background)
            .navigationTitle("备份与恢复").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .sheet(isPresented: $showContentExport) { ContentExportView() }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                          defaultFilename: "AFTERIMAGE-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in
                switch result {
                case .success: lastExport = Date().timeIntervalSince1970; message = "备份已导出。选择 iCloud Drive 时，由系统继续完成上传。"
                case .failure(let error): message = "备份未导出：\(error.localizedDescription)"
                }
                document = nil
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url): load(url)
                case .failure(let error): message = error.localizedDescription
                }
            }
            .confirmationDialog("恢复这份备份？", isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("补回缺失的瞬间") {
                    guard let pending else { return }
                    do { let count = try pending.restore(into: context.container); message = "已补回 \(count) 个瞬间。现有记录已保留。" }
                    catch { message = "恢复失败：\(error.localizedDescription)" }
                    self.pending = nil
                }
                Button("取消", role: .cancel) { pending = nil }
            } message: {
                if let pending { Text("\(pending.createdAt.formatted(date: .abbreviated, time: .shortened))\n\(pending.memories.count) 个瞬间 · \(pending.themes.count) 个主题 · \(pending.memories.reduce(0) { $0 + $1.photos.count }) 张照片") }
            }
            .alert("备份与恢复", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("好") { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    private func export() {
        do { document = ArchiveDocument(data: try MemoryArchive.snapshot(in: context).encoded()); exporting = true }
        catch { message = error.localizedDescription }
    }
    private func load(_ url: URL) {
        busy = true
        Task {
            do {
                let archive = try await Task.detached(priority: .userInitiated) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let coordinator = NSFileCoordinator(filePresenter: nil)
                    var coordinationError: NSError?
                    var output: Result<MemoryArchive, Error>?
                    coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                        output = Result {
                            let size = try readable.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                            guard size <= 256 * 1024 * 1024 else { throw MemoryArchive.ArchiveError.invalid }
                            return try MemoryArchive.decode(Data(contentsOf: readable))
                        }
                    }
                    if let coordinationError { throw coordinationError }
                    guard let output else { throw MemoryArchive.ArchiveError.invalid }
                    return try output.get()
                }.value
                pending = archive; confirmRestore = true
            } catch { message = "无法读取备份：\(error.localizedDescription)" }
            busy = false
        }
    }
}
