import SwiftUI

enum MemorySearch {
    static func matches(_ record: MemoryRecord, query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty || contains(record.displayTitle, term) || contains(record.text, term)
            || record.tags.contains { contains($0.name, term) }
    }

    private static func contains(_ text: String, _ term: String) -> Bool {
        text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], locale: .current) != nil
    }

    static func excerpt(_ text: String, query: String) -> String? {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, let range = text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], locale: .current) else { return nil }
        let start = text.index(range.lowerBound, offsetBy: -24, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(start, offsetBy: 100, limitedBy: text.endIndex) ?? text.endIndex
        return (start > text.startIndex ? "…" : "")
            + text[start..<end].replacingOccurrences(of: "\n", with: " ")
            + (end < text.endIndex ? "…" : "")
    }
}

struct MemoryIndexView: View {
    let memories: [MemoryRecord]
    let locate: (UUID) -> Void
    let locateEdge: (Bool) -> Void
    @Binding var dateFilter: TimelineDateFilter
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selected: MemoryRecord?
    @State private var showDateFilter = false
    private var results: [MemoryRecord] { memories.filter { dateFilter.contains($0.occurredAt) && MemorySearch.matches($0, query: query) } }

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Button { showDateFilter = true } label: {
                        HStack {
                            Label(dateFilter.label, systemImage: "calendar")
                            Spacer()
                            Image(systemName: "chevron.down").font(.caption)
                        }.frame(minHeight: 44)
                    }.buttonStyle(.plain).foregroundStyle(AfterimageStyle.amber)
                        .listRowSeparator(.hidden)
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Section {
                            HStack {
                                Text("\(results.count) 个瞬间").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button("最早") { jump(results.first?.id) }.buttonStyle(.borderless).disabled(results.isEmpty)
                                Button("最近") { jump(results.last?.id) }.buttonStyle(.borderless).disabled(results.isEmpty)
                            }.frame(minHeight: 36)
                        }.listSectionSeparator(.hidden).listRowSeparator(.hidden)
                    }
                    Section {
                        ForEach(results) { memory in
                            HStack(alignment: .center, spacing: 16) {
                                Button { selected = memory } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(memory.occurredAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption).foregroundStyle(AfterimageStyle.amber)
                                        Text(memory.displayTitle).font(.body).foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        if let excerpt = MemorySearch.excerpt(memory.text, query: query) {
                                            Text(excerpt).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).accessibilityIdentifier("index.memory.\(memory.id)")
                                Button { jump(memory.id) } label: {
                                    Label("定位", systemImage: "location")
                                        .font(.caption).frame(minWidth: 58, minHeight: 44)
                                }
                                .buttonStyle(.borderless).accessibilityLabel("在时间轴定位：\(memory.displayTitle)")
                            }
                            .padding(.vertical, 8)
                            .listRowSeparator(.hidden)
                            .overlay(alignment: .bottom) {
                                if memory.id != results.last?.id { Rectangle().fill(Color.white.opacity(0.10)).frame(height: 0.5) }
                            }
                            .listRowBackground(AfterimageStyle.background)
                        }
                    }.listSectionSeparator(.hidden)
                }.listRowBackground(AfterimageStyle.background)
            }
            .listStyle(.plain).scrollContentBackground(.hidden).afterimageSheetSurface()
            .background(AfterimageStyle.background)
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView("没有符合条件的瞬间", systemImage: "calendar", description: Text("试试其他关键词或时间范围。"))
                        .allowsHitTesting(false).padding(.top, 120)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索标题、正文或主题")
            .navigationTitle("时间索引").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(item: $selected) { MemoryDetailView(record: $0) }
            .sheet(isPresented: $showDateFilter) { TimelineDateFilterView(selection: $dateFilter) }
        }
    }

    private func jump(_ id: UUID?) {
        guard let id else { return }
        locate(id)
        dismiss()
    }
}
