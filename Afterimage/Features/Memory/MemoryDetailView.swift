import SwiftUI
import SwiftData

struct MemoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let record: MemoryRecord
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    @State private var showConnections = false
    @State private var readingTheme: MemoryTag?
    @State private var relatedSelection: MemoryRecord?
    @State private var editingLink: MemoryRecord?
    @State private var managingLink: MemoryRecord?
    @Query(sort: \MemoryRecord.occurredAt) private var allMemories: [MemoryRecord]
    @Query private var linkChoices: [MemoryLink]

    private var related: [MemoryRecord] {
        allMemories.filter { $0.id != record.id && Resonance.related(record, $0, choices: linkChoices) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(Array(record.photos.enumerated()), id: \.offset) { index, data in
                        VStack(alignment: .leading, spacing: 8) {
                            PhotoViewerEntry(data: data)
                            if record.photos.count > 1 {
                                Text("\(index + 1) / \(record.photos.count)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Text(record.occurredAt.formatted(date: .long, time: .shortened))
                            .font(.caption).foregroundStyle(AfterimageStyle.amber)
                        Text(record.displayTitle).font(.title2.weight(.medium)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        if !record.text.isEmpty && record.text != record.displayTitle {
                            Text(record.text).font(.body).lineSpacing(7).textSelection(.enabled)
                                .accessibilityIdentifier("memory.body")
                        }
                    }
                    if !record.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(record.tags.sorted { $0.name < $1.name }, id: \.key) { tag in
                                HStack {
                                    Button { readingTheme = tag } label: {
                                        HStack(spacing: 8) {
                                            Circle().fill(ThemePalette.ink(tag.colorIndex).color).frame(width: 6, height: 6)
                                            Text(tag.name)
                                            Image(systemName: "arrow.up.right").font(.caption2)
                                        }.frame(minHeight: 44)
                                    }
                                    .foregroundStyle(ThemePalette.ink(tag.colorIndex).color)
                                    .accessibilityIdentifier("memory.theme.\(tag.key)")
                                    Spacer()
                                    ThemeColorMenu(tag: tag)
                                    Menu {
                                        Button("从这个瞬间移除主题", role: .destructive) {
                                            do { try MemoryStore.remove(tag, from: record, in: context) }
                                            catch { errorMessage = error.localizedDescription }
                                        }
                                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                                    .accessibilityLabel("\(tag.name)的选项")
                                }
                            }
                        }.font(.subheadline)
                    }
                    connectionSection
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(24).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden).afterimageSheetSurface()
            .navigationTitle("瞬间").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { editing = true } label: { Image(systemName: "pencil") }
                        .accessibilityLabel("编辑瞬间").accessibilityIdentifier("memory.edit")
                    Button { confirmDelete = true } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                        .accessibilityLabel("删除瞬间").accessibilityIdentifier("memory.delete")
                }
            }
            .sheet(isPresented: $editing) { MemoryEditorView(record: record) }
            .sheet(isPresented: $showConnections) { MemoryConnectionsView(memory: record) }
            .sheet(item: $readingTheme) { ThemeReadingView(tag: $0) }
            .sheet(item: $relatedSelection) { MemoryDetailView(record: $0) }
            .sheet(item: $editingLink) { other in
                ManualLinkEditor(source: record, target: other, note: Resonance.manual(record.id, other.id, choices: linkChoices)?.note ?? "")
            }
            .confirmationDialog("删除这个瞬间？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除记录及其照片", role: .destructive) {
                    do { try MemoryStore.delete(record, in: context); dismiss() }
                    catch { errorMessage = "删除失败，记录未删除。\n\(error.localizedDescription)" }
                }
                .accessibilityIdentifier("memory.confirmDelete")
                Button("取消", role: .cancel) {}
            } message: { Text("此操作无法撤销，不会删除系统相册中的原照片。") }
            .alert("未能完成", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { showConnections = true } label: {
                HStack {
                    Text("关联瞬间 · \(related.count)")
                    Spacer()
                    Image(systemName: "plus").font(.subheadline)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }
            .accessibilityIdentifier("memory.connections")
            ForEach(related) { other in
                VStack(alignment: .leading, spacing: 10) {
                    Button { relatedSelection = other } label: {
                        HStack(alignment: .top) {
                            Text(other.displayTitle).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 16)
                            Image(systemName: "arrow.up.right").font(.caption)
                        }.foregroundStyle(.primary).frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("related.\(other.id)")
                    let tags = Resonance.sharedTags(record, other).filter {
                        Resonance.enabled(record.id, other.id, tag: $0.key, choices: linkChoices)
                    }
                    if !tags.isEmpty {
                        Text("共同主题 · " + tags.map(\.name).joined(separator: "、"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let manual = Resonance.manual(record.id, other.id, choices: linkChoices) {
                        Text("手动关联").font(.caption).foregroundStyle(AfterimageStyle.amber)
                        if let note = manual.note {
                            Text(note).font(.subheadline).lineSpacing(5).accessibilityIdentifier("link.savedNote")
                        }
                        Button { managingLink = other } label: {
                            Label("管理手动关联", systemImage: "ellipsis").font(.caption).frame(minHeight: 44)
                        }
                        .accessibilityLabel("管理手动关联")
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .confirmationDialog("手动关联", isPresented: Binding(get: { managingLink != nil }, set: { if !$0 { managingLink = nil } }), titleVisibility: .visible) {
            if let other = managingLink {
                Button("编辑说明") { editingLink = other }
                Button("移除手动关联", role: .destructive) {
                    do { try Resonance.set(false, a: record.id, b: other.id, tag: nil, in: context) }
                    catch { errorMessage = error.localizedDescription }
                }
            }
        }
    }
}
