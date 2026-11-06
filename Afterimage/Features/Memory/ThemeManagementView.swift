import SwiftUI
import SwiftData

struct ThemeManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \MemoryTag.name) private var themes: [MemoryTag]
    @State private var selection = Set<String>()
    @State private var destination = ""
    @State private var confirmingDelete = false
    @State private var confirmingMerge = false
    @State private var choosingMerge = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reading: MemoryTag?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("整理你的主题").font(.title3.weight(.medium))
                            Text("选中主题后，可合并或删除。瞬间与照片始终保留。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }.padding(.vertical, 12)
                            .listRowBackground(AfterimageStyle.background)
                            .listRowSeparator(.hidden)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("themes.introduction")
                    }
                    Section {
                        ForEach(themes, id: \.key) { theme in
                            HStack {
                                Button {
                                    if selection.contains(theme.key) { selection.remove(theme.key) } else { selection.insert(theme.key) }
                                } label: {
                                    Image(systemName: selection.contains(theme.key) ? "checkmark.circle.fill" : "circle").frame(width: 44, height: 44)
                                }.buttonStyle(.borderless).accessibilityLabel("选择主题：\(theme.name)")
                                Button { reading = theme } label: {
                                    HStack(spacing: 10) {
                                        Circle().fill(ThemePalette.ink(theme.colorIndex).color).frame(width: 6, height: 6)
                                        Text(theme.name).foregroundStyle(.primary)
                                        Spacer()
                                        Text("\(theme.memories.count)").font(.caption).foregroundStyle(.secondary)
                                    }.frame(minHeight: 44).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }
                    } header: { Text("\(themes.count) 个主题 · 已选 \(selection.count) 个") }
                    if themes.isEmpty { ContentUnavailableView("还没有主题", systemImage: "tag", description: Text("记录瞬间时添加主题，它们会在这里出现。")) }
                }.listRowBackground(AfterimageStyle.surface)
            }
            .scrollContentBackground(.hidden).afterimageSheetSurface().background(AfterimageStyle.background)
            .navigationTitle("主题管理").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !selection.isEmpty {
                    HStack(spacing: 12) {
                        HStack(spacing: 0) {
                            Text("已选 \(selection.count) 项").font(.caption.weight(.medium))
                                .foregroundStyle(.secondary).padding(.leading, 4).lineLimit(1)
                            Button { selection = [] } label: {
                                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                            }.foregroundStyle(.secondary).accessibilityLabel("清除选择")
                        }.buttonStyle(.plain).afterimageControlGroup()
                        Spacer(minLength: 0)
                        HStack(spacing: 0) {
                            Button {
                                destination = themes.first(where: { selection.contains($0.key) })?.key ?? ""
                                choosingMerge = true
                            } label: { Text("合并").frame(width: 64, height: 44).contentShape(Rectangle()) }
                                .foregroundStyle(AfterimageStyle.amber).disabled(selection.count < 2)
                                .opacity(selection.count < 2 ? 0.35 : 1)
                                .accessibilityIdentifier("themes.merge")
                            Rectangle().fill(Color.primary.opacity(0.16)).frame(width: 0.5, height: 18).accessibilityHidden(true)
                            Button(role: .destructive) { confirmingDelete = true } label: {
                                Text("删除").frame(width: 64, height: 44).contentShape(Rectangle())
                            }
                                .foregroundStyle(.red).accessibilityIdentifier("themes.delete")
                        }.font(.subheadline.weight(.medium)).buttonStyle(.plain).afterimageControlGroup()
                    }.padding(.horizontal, 20).padding(.vertical, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9), value: selection.isEmpty)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(item: $reading) { ThemeReadingView(tag: $0) }
            .sheet(isPresented: $choosingMerge) { mergeDestination }
            .alert("删除 \(selection.count) 个主题？", isPresented: $confirmingDelete) {
                Button("删除主题，保留瞬间", role: .destructive) { perform { try ThemeManagement.delete(keys: selection, in: context) } }
                Button("取消", role: .cancel) {}
            } message: { Text("所有瞬间上的这些主题标签和对应主题关联将移除。手动关联与说明保留。") }
            .alert("主题未更新", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
    private var mergeDestination: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(themes, id: \.key) { theme in
                        Button { destination = theme.key } label: {
                            HStack {
                                Circle().fill(ThemePalette.ink(theme.colorIndex).color).frame(width: 8, height: 8)
                                Text(theme.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "checkmark").opacity(destination == theme.key ? 1 : 0)
                            }.frame(minHeight: 36)
                        }
                    }
                } footer: { Text("选中的主题将归入这里，保留这个主题的名称与颜色。") }
                    .listRowBackground(AfterimageStyle.surface)
            }.scrollContentBackground(.hidden).afterimageSheetSurface()
                .navigationTitle("保留哪个主题").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { choosingMerge = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("合并") { confirmingMerge = true }
                            .disabled(destination.isEmpty || selection.subtracting([destination]).isEmpty)
                    }
                }
                .alert("合并这些主题？", isPresented: $confirmingMerge) {
                    Button("确认合并") {
                        guard let target = themes.first(where: { $0.key == destination }) else { return }
                        perform { try ThemeManagement.merge(keys: selection, into: target, in: context) }
                        if errorMessage == nil { choosingMerge = false }
                    }
                    Button("取消", role: .cancel) {}
                } message: { Text("归入目标主题并保留其名称和颜色。原主题会移除，已取消的主题关联仍保持取消。") }
        }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); selection = []; destination = "" }
        catch { errorMessage = error.localizedDescription }
    }
}
