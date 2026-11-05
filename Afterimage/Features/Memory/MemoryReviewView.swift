import SwiftUI
import SwiftData

enum ReviewPeriod: String, CaseIterable, Identifiable {
    case all = "全部", month = "本月", year = "今年", custom = "自选"
    var id: String { rawValue }
}

enum MemoryReview {
    static func contains(_ date: Date, from start: Date, through end: Date, calendar: Calendar = .current) -> Bool {
        let lower = calendar.startOfDay(for: min(start, end))
        let upper = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(start, end)))!
        return date >= lower && date < upper
    }
}

struct MemoryReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MemoryRecord.occurredAt) private var records: [MemoryRecord]
    @State private var period = ReviewPeriod.all
    @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var through = Date()
    @State private var themeKey = ""
    @State private var selected = Set<UUID>()
    @State private var reading: MemoryRecord?
    @State private var share: ShareImages?
    @State private var errorMessage: String?
    @State private var rendering = false

    private var themes: [MemoryTag] {
        var unique: [String: MemoryTag] = [:]
        for tag in records.flatMap(\.tags) { unique[tag.key] = tag }
        return unique.values.sorted { $0.name < $1.name }
    }
    private var results: [MemoryRecord] {
        records.filter { record in
            let dateMatch: Bool
            switch period {
            case .all: dateMatch = true
            case .month: dateMatch = Calendar.current.isDate(record.occurredAt, equalTo: Date(), toGranularity: .month)
            case .year: dateMatch = Calendar.current.isDate(record.occurredAt, equalTo: Date(), toGranularity: .year)
            case .custom: dateMatch = MemoryReview.contains(record.occurredAt, from: from, through: through)
            }
            return dateMatch && (themeKey.isEmpty || record.tags.contains { $0.key == themeKey })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        Text("拾起一段时间。 ").font(.title2.weight(.light)).padding(.vertical, 8)
                        Picker("时间", selection: $period) { ForEach(ReviewPeriod.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                        if period == .custom {
                            DatePicker("从", selection: $from, displayedComponents: .date)
                            DatePicker("到", selection: $through, displayedComponents: .date)
                        }
                        Picker("主题", selection: $themeKey) {
                            Text("所有主题").tag("")
                            ForEach(themes, id: \.key) { Text($0.name).tag($0.key) }
                        }
                        Text("\(results.count) 个瞬间 · \(results.reduce(0) { $0 + $1.photos.count }) 张照片")
                            .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("review.count")
                    }
                    Section {
                        HStack {
                            Button("选取前 12 个") { selected = Set(results.prefix(12).map(\.id)) }
                            Spacer()
                            Button("清空选择") { selected = [] }
                        }.font(.caption).buttonStyle(.borderless)
                        ForEach(results) { record in
                            HStack(alignment: .top, spacing: 14) {
                                Button {
                                    if selected.contains(record.id) { selected.remove(record.id) }
                                    else if selected.count < 12 { selected.insert(record.id) }
                                } label: {
                                    Image(systemName: selected.contains(record.id) ? "checkmark.circle.fill" : "circle").frame(width: 44, height: 44)
                                }.buttonStyle(.borderless).accessibilityLabel("选择分享：\(record.displayTitle)")
                                    .accessibilityValue(selected.contains(record.id) ? "已选中" : "未选中")
                                Button { reading = record } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        if let data = record.photoData { ReadingPhoto(data: data).frame(maxHeight: 180).clipShape(RoundedRectangle(cornerRadius: 6)) }
                                        Text(record.occurredAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(AfterimageStyle.amber)
                                        Text(record.displayTitle).font(.headline).foregroundStyle(.primary)
                                        if record.text != record.displayTitle { Text(record.text).font(.subheadline).foregroundStyle(.secondary).lineLimit(3) }
                                    }.padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain).accessibilityIdentifier("review.memory")
                            }
                        }
                        if results.isEmpty { ContentUnavailableView("这段时间还没有瞬间", systemImage: "calendar", description: Text("试试其他时间或主题。")) }
                    } header: { Text("沿时间阅读") }
                    footer: { Text("每次可选 12 个瞬间，合成一张完整长图。长图显示封面与正文摘要，分享前可预览。") }
                }.listRowBackground(AfterimageStyle.surface)
            }
            .listStyle(.insetGrouped).scrollContentBackground(.hidden).afterimageSheetSurface()
            .navigationTitle("时间回顾").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { render() } label: { if rendering { ProgressView() } else { Label("制作长图", systemImage: "square.and.arrow.up") } }
                        .disabled(selected.isEmpty || rendering).accessibilityIdentifier("review.export")
                }
            }
            .onChange(of: results.map(\.id), initial: true) { _, ids in selected = Set(ids.prefix(12)) }
            .sheet(item: $reading) { MemoryDetailView(record: $0) }
            .sheet(item: $share) { SharePreview(images: $0.images) }
            .alert("无法制作长图", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
    private func render() {
        rendering = true
        Task { @MainActor in
            await Task.yield()
            let chosen = results.filter { selected.contains($0.id) }
            let renderer = ImageRenderer(content: MemorySharePage(records: chosen, page: 1, total: 1).environment(\.colorScheme, .dark))
            renderer.scale = chosen.count > 8 ? 1.5 : 2
            guard let image = renderer.uiImage else { errorMessage = "请减少选择的记录后再试。"; rendering = false; return }
            share = ShareImages(images: [image]); rendering = false
        }
    }
}

struct ShareImages: Identifiable { let id = UUID(); let images: [UIImage] }

struct MemorySharePage: View {
    let records: [MemoryRecord]
    let page: Int
    let total: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            VStack(alignment: .leading, spacing: 12) {
                Text("A F T E R I M A G E").font(.caption.weight(.medium)).foregroundStyle(AfterimageStyle.amber)
                Text("留下来的瞬间").font(.largeTitle.weight(.light))
                if let first = records.first, let last = records.last {
                    Text(first.occurredAt.formatted(date: .abbreviated, time: .omitted) + " — " + last.occurredAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 32) {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    let left = index.isMultiple(of: 2)
                    HStack(alignment: .top, spacing: 48) {
                        if !left { Color.clear.frame(width: 143, height: 1) }
                        ShareMomentCard(record: record)
                            .overlay(alignment: left ? .topTrailing : .topLeading) {
                                ShareThreadBridge(left: left).frame(width: 24, height: 16)
                                    .offset(x: left ? 24 : -24)
                            }
                        if left { Color.clear.frame(width: 143, height: 1) }
                    }
                }
            }
            .padding(.vertical, 24)
            .background { VerticalShareThread() }
            Text("AFTERIMAGE / \(records.count) 个瞬间").font(.caption2).foregroundStyle(AfterimageStyle.amber.opacity(0.7))
        }.padding(28).frame(width: 390, alignment: .leading).background(AfterimageStyle.background).foregroundStyle(.white)
    }
}

private struct ShareMomentCard: View {
    let record: MemoryRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(record.occurredAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2).foregroundStyle(AfterimageStyle.amber)
            if let data = record.photoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Text(record.displayTitle).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            if record.text != record.displayTitle {
                Text(record.text).font(.caption).lineSpacing(4).lineLimit(5).foregroundStyle(.secondary)
            }
            if record.photos.count > 1 { Text("\(record.photos.count) 张照片 · 封面").font(.caption2).foregroundStyle(.secondary) }
        }.frame(width: 143, alignment: .leading)
    }
}

private struct ShareThreadBridge: View {
    let left: Bool
    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 8))
                path.addCurve(to: CGPoint(x: 24, y: 8), control1: CGPoint(x: 8, y: 6), control2: CGPoint(x: 16, y: 10))
            }.stroke(AfterimageStyle.amber.opacity(0.65), lineWidth: 0.6)
            Circle().fill(AfterimageStyle.amber).frame(width: 3, height: 3)
                .shadow(color: AfterimageStyle.amber.opacity(0.6), radius: 3)
                .position(x: left ? 24 : 0, y: 8)
        }
    }
}

private struct VerticalShareThread: View {
    var body: some View {
        Canvas { context, size in
            // Rotate the real main-axis renderer, keeping the same crossings and light hierarchy.
            let distance = size.height
            let time = 18.0
            context.translateBy(x: size.width / 2, y: 0)
            context.rotate(by: .degrees(90))
            context.translateBy(x: 0, y: -260)
            context.clip(to: Path(CGRect(x: 0, y: 180, width: distance, height: 160)))
            SilkRenderer.draw(in: context, origin: 0, width: distance, time: time,
                              tension: 0, positions: [], displacements: [], focus: nil, crossSectionScale: 0.55)
        }.mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.035), .init(color: .white, location: 0.965), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct SharePreview: View {
    let images: [UIImage]
    @Environment(\.dismiss) private var dismiss
    @State private var sharing = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("确认长图中的内容后再分享。正文较长时显示摘要。")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(images.indices, id: \.self) { index in
                        Image(uiImage: images[index]).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }.padding(20)
            }.afterimageSheetSurface().navigationTitle("长图预览").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("返回") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("分享", systemImage: "square.and.arrow.up") { sharing = true } }
                }
                .sheet(isPresented: $sharing) { ImageShareSheet(images: images) }
        }
    }
}
struct ImageShareSheet: UIViewControllerRepresentable {
    let images: [UIImage]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: images, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
