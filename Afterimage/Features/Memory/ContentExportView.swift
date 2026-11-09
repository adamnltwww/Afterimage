import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentZipDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct ContentExportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var records: [MemoryRecord]
    @State private var filter = TimelineDateFilter()
    @State private var showFilter = false
    @State private var busy = false
    @State private var document: ContentZipDocument?
    @State private var exporting = false
    @State private var message: String?
    private var count: Int { records.filter { filter.contains($0.occurredAt) }.count }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showFilter = true } label: { Label(filter.label, systemImage: "calendar") }
                    Text("\(count) 个瞬间").foregroundStyle(.secondary)
                } header: { Text("导出范围") }
                Section {
                    Text("完整文字、时间、主题和照片整理为 ZIP，每个瞬间单独存放，解压后即可阅读。")
                    Text("照片为 App 保存的浏览副本，无法还原相册原片。导出不会修改或删除现有记录。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("导出文字与照片", systemImage: "square.and.arrow.up", action: export)
                        .disabled(count == 0 || busy)
                    if busy { ProgressView("正在整理内容…") }
                }
            }.afterimageSheetSurface().disabled(busy)
                .navigationTitle("内容导出").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.disabled(busy) } }
                .interactiveDismissDisabled(busy)
                .sheet(isPresented: $showFilter) { TimelineDateFilterView(selection: $filter) }
                .fileExporter(isPresented: $exporting, document: document, contentType: .zip, defaultFilename: "AFTERIMAGE-内容") { result in
                    if case .failure(let error) = result { message = error.localizedDescription }
                    document = nil
                }
                .alert("内容导出", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                    Button("好") { message = nil }
                } message: { Text(message ?? "") }
        }
    }
    private func export() {
        busy = true
        do {
            var archive = try MemoryArchive.snapshot(in: context)
            archive.memories = archive.memories.filter { filter.contains($0.occurredAt) }
            let ids = Set(archive.memories.map(\.id))
            let themeKeys = Set(archive.memories.flatMap(\.themeKeys))
            archive.themes = archive.themes.filter { themeKeys.contains($0.key) }
            archive.links = archive.links.filter { ids.contains($0.source) && ids.contains($0.target) }
            let snapshot = archive
            Task {
                defer { busy = false }
                do {
                    let data = try await Task.detached(priority: .userInitiated) {
                        try ContentExport.zip(ContentExport.entries(archive: snapshot))
                    }.value
                    document = ContentZipDocument(data: data); exporting = true
                } catch { message = error.localizedDescription }
            }
        } catch { busy = false; message = error.localizedDescription }
    }
}
