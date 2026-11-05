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
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selected: MemoryRecord?
    private var results: [MemoryRecord] { memories.filter { MemorySearch.matches($0, query: query) } }

    var body: some View {
        NavigationStack {
            List {
                Group {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Section {
                            HStack {
                                Text("\(memories.count) 个瞬间").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button("最早") { locateEdge(false); dismiss() }.buttonStyle(.borderless)
                                Button("最近") { locateEdge(true); dismiss() }.buttonStyle(.borderless)
                            }.frame(minHeight: 36)
                        }
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
                                    Image(systemName: "location").frame(width: 44, height: 44)
                                }
                                .buttonStyle(.borderless).accessibilityLabel("在时间轴定位：\(memory.displayTitle)")
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(AfterimageStyle.background)
                        }
                    }
                }.listRowBackground(AfterimageStyle.background)
            }
            .listStyle(.plain).scrollContentBackground(.hidden).afterimageSheetSurface()
            .background(AfterimageStyle.background)
            .overlay {
                if results.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索标题、正文或主题")
            .navigationTitle("时间索引").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(item: $selected) { MemoryDetailView(record: $0) }
        }
    }

    private func jump(_ id: UUID?) {
        guard let id else { return }
        locate(id)
        dismiss()
    }
}
