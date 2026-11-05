import SwiftUI
import SwiftData

struct ThemeReadingView: View {
    let tag: MemoryTag
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MemoryRecord.occurredAt), SortDescriptor(\MemoryRecord.createdAt)]) private var records: [MemoryRecord]
    @State private var selected: MemoryRecord?
    @State private var renaming = false
    @State private var name = ""
    @State private var errorMessage: String?

    private var members: [MemoryRecord] { records.filter { $0.tags.contains { $0.key == tag.key } } }
    private var ink: Color { ThemePalette.ink(tag.colorIndex).color }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("主题 / \(members.count) 个瞬间").font(.caption).foregroundStyle(ink)
                        Text(tag.name).font(.largeTitle.weight(.light)).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("theme.heading")
                        if let first = members.first, let last = members.last {
                            Text(first.occurredAt.formatted(date: .abbreviated, time: .omitted)
                                 + (members.count > 1 ? " — " + last.occurredAt.formatted(date: .abbreviated, time: .omitted) : ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 16)
                    if members.isEmpty {
                        ContentUnavailableView("这个主题暂时没有瞬间", systemImage: "tag", description: Text("为瞬间添加这个主题后，会在这里出现。"))
                    }
                    LazyVStack(alignment: .leading, spacing: 36) {
                        ForEach(members) { record in
                            Button { selected = record } label: {
                                VStack(alignment: .leading, spacing: 14) {
                                    if let data = record.photoData {
                                        ReadingPhoto(data: data)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    if record.photos.count > 1 {
                                        Label("\(record.photos.count) 张照片", systemImage: "photo.on.rectangle").font(.caption).foregroundStyle(ink)
                                    }
                                    Text(record.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(ink)
                                    Text(record.displayTitle).font(.title3.weight(.medium)).foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if !record.text.isEmpty && record.text != record.displayTitle {
                                        Text(record.text).font(.subheadline).lineSpacing(5).lineLimit(3).foregroundStyle(.secondary)
                                    }
                                    HStack(spacing: 6) {
                                        Text("阅读瞬间")
                                        Image(systemName: "arrow.up.right")
                                    }.font(.caption).foregroundStyle(ink)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).multilineTextAlignment(.leading)
                            .accessibilityIdentifier("theme.memory.\(record.id)")
                        }
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, 24).padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .afterimageSheetSurface()
            .navigationTitle("主题").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("返回") { dismiss() }.accessibilityIdentifier("theme.close") }
                ToolbarItemGroup(placement: .primaryAction) {
                    ThemeColorMenu(tag: tag)
                    Button { name = tag.name; renaming = true } label: { Image(systemName: "pencil") }
                        .accessibilityLabel("重命名主题").accessibilityIdentifier("theme.rename")
                }
            }
            .sheet(item: $selected) { MemoryDetailView(record: $0) }
            .alert("重命名主题", isPresented: $renaming) {
                TextField("主题名称", text: $name)
                Button("取消", role: .cancel) {}
                Button("保存") {
                    do { try MemoryStore.rename(tag, to: name, in: context) }
                    catch { errorMessage = error.localizedDescription }
                }
            } message: { Text("所有使用这个主题的瞬间会同步更新名称。") }
            .alert("名称未保存", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}

/// Full-ratio reading image, shared by theme cards and the detail photo entry.
struct ReadingPhoto: View {
    let data: Data
    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit()
                .frame(maxWidth: .infinity).accessibilityHidden(true)
        }
    }
}
