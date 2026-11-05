import SwiftUI
import SwiftData

struct MemoryConnectionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MemoryRecord.occurredAt) private var memories: [MemoryRecord]
    @Query private var choices: [MemoryLink]
    let memory: MemoryRecord
    @State private var search = ""
    @State private var errorMessage: String?
    @State private var editingLink: MemoryRecord?

    private var others: [MemoryRecord] {
        memories.filter { $0.id != memory.id && MemorySearch.matches($0, query: search) }
            .sorted { a, b in
                let ar = Resonance.related(memory, a, choices: choices)
                let br = Resonance.related(memory, b, choices: choices)
                return ar != br ? ar : a.occurredAt < b.occurredAt
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        Text(memory.displayTitle).fixedSize(horizontal: false, vertical: true)
                        Text("共同主题与手动关联各自保留。手动说明在两个瞬间中同步显示。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("其他瞬间") {
                        if others.isEmpty {
                            Text(search.isEmpty ? "再记录一个瞬间，就可以建立联系。" : "没有匹配的瞬间。")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(others) { other in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(other.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(AfterimageStyle.amber)
                                Text(other.displayTitle).fixedSize(horizontal: false, vertical: true)
                                ForEach(Resonance.sharedTags(memory, other), id: \.key) { tag in
                                    Toggle("共同主题 · \(tag.name)", isOn: binding(other, tag: tag.key))
                                        .font(.subheadline)
                                        .tint(ThemePalette.ink(tag.colorIndex).color)
                                }
                                if let manual = Resonance.manual(memory.id, other.id, choices: choices) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("手动关联").font(.caption).foregroundStyle(AfterimageStyle.amber)
                                        if let note = manual.note { Text(note).font(.subheadline) }
                                        HStack {
                                            Button("编辑说明") { editingLink = other }
                                            Spacer()
                                            Button("移除", role: .destructive) { binding(other, tag: nil).wrappedValue = false }
                                        }.font(.subheadline).buttonStyle(.borderless).frame(minHeight: 44)
                                    }
                                } else {
                                    Button("添加手动关联", systemImage: "link.badge.plus") { editingLink = other }
                                        .font(.subheadline).buttonStyle(.borderless).frame(minHeight: 44)
                                }
                                if !Resonance.related(memory, other, choices: choices) {
                                    Text("未连接").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }.listRowBackground(AfterimageStyle.surface)
            }
            .scrollContentBackground(.hidden).afterimageSheetSurface().background(AfterimageStyle.background)
            .searchable(text: $search, prompt: "搜索文字或标签")
            .navigationTitle("关联瞬间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(item: $editingLink) { other in
                ManualLinkEditor(source: memory, target: other,
                                 note: Resonance.manual(memory.id, other.id, choices: choices)?.note ?? "")
            }
            .alert("关联未保存", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func binding(_ other: MemoryRecord, tag: String?) -> Binding<Bool> {
        Binding(get: { Resonance.enabled(memory.id, other.id, tag: tag, choices: choices) }, set: { value in
            do { try Resonance.set(value, a: memory.id, b: other.id, tag: tag, in: context) }
            catch { errorMessage = error.localizedDescription }
        })
    }
}

struct ManualLinkEditor: View {
    let source: MemoryRecord
    let target: MemoryRecord
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    private let initialNote: String
    @State private var errorMessage: String?
    @State private var confirmDiscard = false

    init(source: MemoryRecord, target: MemoryRecord, note: String) {
        self.source = source; self.target = target; initialNote = note
        _note = State(initialValue: note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        Text(source.displayTitle)
                        Label(target.displayTitle, systemImage: "link")
                    }
                    Section {
                        TextField("为什么把这两个瞬间连在一起？", text: $note, axis: .vertical)
                            .lineLimit(3...6).accessibilityIdentifier("link.note")
                    } header: { Text("关联说明 · 可选") }
                    footer: { Text("例如：同一个地方，隔了三个月。双方都会看到这条说明。") }
                }.listRowBackground(AfterimageStyle.surface)
            }
            .scrollContentBackground(.hidden).afterimageSheetSurface().background(AfterimageStyle.background)
            .navigationTitle("手动关联").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { if note != initialNote { confirmDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try Resonance.setManual(a: source.id, b: target.id, note: note, in: context); dismiss() }
                        catch { errorMessage = error.localizedDescription }
                    }.accessibilityIdentifier("link.save")
                }
            }
            .interactiveDismissDisabled(note != initialNote)
            .confirmationDialog("放弃未保存的说明？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("放弃修改", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }
            .alert("关联未保存", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}
