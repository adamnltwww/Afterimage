import SwiftUI
import SwiftData

struct ThreadComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MemoryRecord.occurredAt) private var records: [MemoryRecord]
    @Query(sort: \MemoryTag.name) private var themes: [MemoryTag]
    @Query private var choices: [MemoryLink]
    @State private var selectedKeys = Set<String>()
    @State private var selecting = false
    @State private var selected: MemoryRecord?
    @State private var offset = 0.0
    private var comparisonRecords: [MemoryRecord] { records.filter { record in record.tags.contains { selectedKeys.contains($0.key) } } }
    private var active: [MemoryTag] { themes.filter { selectedKeys.contains($0.key) } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("几股细丝，同一段时间。").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("选择主题") { selecting = true }.font(.subheadline).afterimageControl()
                }.padding(.horizontal, 24)
                if active.isEmpty {
                    ContentUnavailableView("选择两个主题", systemImage: "line.3.horizontal",
                                           description: Text("让不同颜色的记忆，从同一条主轴里展开。"))
                } else {
                    GeometryReader { geometry in
                        let visibleRecords = comparisonRecords
                        let layout = TimelineLayout(dates: visibleRecords.map(\.occurredAt), viewport: geometry.size.width, leadingInset: max(96, geometry.size.width * 0.32))
                        let stageHeight = geometry.size.height
                        ScrollView(.horizontal) {
                            ZStack(alignment: .topLeading) {
                                SilkAxis(origin: offset - geometry.size.width, width: geometry.size.width * 3, height: stageHeight)
                                    .frame(width: 0, height: stageHeight, alignment: .leading)
                                    .opacity(0.75)
                                ForEach(Array(active.enumerated()), id: \.element.key) { lane, theme in
                                    ComparisonStrand(theme: theme, lane: lane, count: active.count, allThemes: active, ownedIDs: Set(visibleRecords.filter { record in active.first(where: { tag in record.tags.contains { $0.key == tag.key } })?.key == theme.key }.map(\.id)), records: visibleRecords,
                                                     choices: choices, positions: layout.positions, width: layout.width,
                                                     stageHeight: stageHeight, canvasHeight: geometry.size.height,
                                                     viewport: geometry.size.width, offset: offset, select: { selected = $0 })
                                }

                            }
                            .frame(width: layout.width, height: geometry.size.height, alignment: .topLeading)
                            .background {
                                if #unavailable(iOS 18.0) { TimelineScrollObserver(offset: $offset).allowsHitTesting(false) }
                            }
                        }.scrollIndicators(.hidden).modifier(TimelineScrollTracking(offset: $offset))
                            .defaultScrollAnchor(.leading)
                            .id(selectedKeys.sorted().joined(separator: "|"))
                            .onAppear { offset = 0 }
                            .accessibilityIdentifier("compare.canvas")
                    }
                }
            }
            .padding(.top, 12).background(AfterimageStyle.background)
            .navigationTitle("并行抽丝").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(isPresented: $selecting) {
                NavigationStack {
                    List {
                        Group {
                            Section {
                                ForEach(themes, id: \.key) { theme in
                                    Button {
                                        if selectedKeys.contains(theme.key) { selectedKeys.remove(theme.key) }
                                        else if selectedKeys.count < 2 { selectedKeys.insert(theme.key) }
                                    } label: {
                                        HStack {
                                            Circle().fill(ThemePalette.ink(theme.colorIndex).color).frame(width: 6, height: 6)
                                            Text(theme.name).foregroundStyle(.primary)
                                            Spacer()
                                            if selectedKeys.contains(theme.key) { Image(systemName: "checkmark") }
                                        }.frame(minHeight: 44)
                                    }.accessibilityIdentifier("compare.theme.\(theme.key)")
                                }
                            } footer: { Text("上下两股主题丝。向外牵起各色光结，或轻点主题旁的抽丝图标。") }
                        }.listRowBackground(AfterimageStyle.surface)
                    }.scrollContentBackground(.hidden).afterimageSheetSurface().background(AfterimageStyle.background)
                        .navigationTitle("选择主题").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { selecting = false } } }
                }.presentationDetents([.medium, .large])
            }
            .sheet(item: $selected) { MemoryDetailView(record: $0) }
            .onAppear {
                if selectedKeys.isEmpty {
                    let connected = themes.filter { $0.memories.count > 1 }
                    selectedKeys = Set((connected.isEmpty ? themes : connected).prefix(2).map(\.key))
                }
            }
        }
    }
}

private struct ComparisonMemoryCard: View {
    let record: MemoryRecord
    let themes: [MemoryTag]
    let height: Double
    let select: () -> Void
    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(themes.filter { theme in record.tags.contains { $0.key == theme.key } }, id: \.key) { theme in
                        Circle().fill(ThemePalette.ink(theme.colorIndex).color).frame(width: 5, height: 5)
                    }
                    Text(record.occurredAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let data = record.photoData {
                    MemoryVisual(id: record.id, photoData: data, preserveAspect: true)
                        .frame(height: min(56, height * 0.4)).clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text(record.displayTitle).font(.caption).foregroundStyle(.primary).lineLimit(2)
            }.frame(width: 154, height: height, alignment: .topLeading).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("瞬间：\(record.displayTitle)")
            .accessibilityIdentifier("compare.memory.\(record.id)")
    }
}

private struct ComparisonStrand: View {
    let theme: MemoryTag
    let lane: Int
    let count: Int
    let allThemes: [MemoryTag]
    let ownedIDs: Set<UUID>
    let records: [MemoryRecord]
    let choices: [MemoryLink]
    let positions: [Double]
    let width: Double
    let stageHeight: Double
    let canvasHeight: Double
    let viewport: Double
    let offset: Double
    let select: (MemoryRecord) -> Void
    @State private var motion = ThreadMotion()
    @Environment(\.afterimageReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    private var members: Set<UUID> { Resonance.threadMembers(tag: theme.key, memories: records, choices: choices) }
    private var memberPositions: [Double] { records.indices.filter { members.contains(records[$0].id) }.map { positions[$0] } }
    private var ink: ThemePalette.Ink { ThemePalette.ink(theme.colorIndex) }
    private var direction: Double { lane.isMultiple(of: 2) ? 1 : -1 }
    private var cardHeight: Double { min(112, canvasHeight * 0.2) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ThreadCanvas(width: width, range: memberPositions.first.flatMap { first in memberPositions.last.map { first...$0 } },
                         progress: motion.progress, positions: memberPositions, displacements: motion.displacements,
                         focus: motion.focusX, visibleRange: (offset - viewport)...(offset + viewport * 2),
                         themeInk: ink, height: stageHeight, liftDirection: direction)
                .allowsHitTesting(false)
            ForEach(records.indices, id: \.self) { index in
                if records[index].tags.contains(where: { $0.key == theme.key }), positions[index] > offset - 200, positions[index] < offset + viewport + 200 {
                    let record = records[index]
                    let x = positions[index]
                    let baseline = TimelineLayout.y(at: x) * stageHeight / 530
                    let y = members.contains(record.id) ? ThreadGeometry.y(at: x, progress: motion.progress, positions: memberPositions, displacements: motion.displacements,
                                             direction: direction) * stageHeight / 530 : baseline
                    if ownedIDs.contains(record.id) {
                        let desired = y - direction * (cardHeight / 2 + 22)
                        ComparisonMemoryCard(record: record, themes: allThemes, height: cardHeight, select: { select(record) })
                            .position(x: x, y: max(64 + cardHeight / 2, min(canvasHeight - cardHeight / 2 - 8, desired)))
                    }
                    Button { select(record) } label: {
                        ZStack {
                            Ellipse().fill(ink.color.opacity(0.25)).frame(width: 22, height: 5).blur(radius: 4)
                            Capsule().fill(ink.color).frame(width: 7, height: 2)
                        }
                        .frame(width: 48, height: 48).contentShape(Rectangle())
                        .overlay {
                            ThreadNodeTouch(enabled: members.contains(record.id), motion: motion, reduceMotion: reduceMotion,
                                            x: x, verticalScale: direction * stageHeight / 530, press: { _ in }) { select(record) }
                        }
                    }.buttonStyle(.plain).position(x: x, y: y)
                        .accessibilityLabel("\(theme.name)：\(record.displayTitle)")
                        .accessibilityAction(named: "抽出主题") { motion.settle(expanded: true, immediately: reduceMotion) }
                        .accessibilityAction(named: "收回主题") { motion.settle(expanded: false, immediately: reduceMotion) }
                }
            }
        }
        .frame(width: width, height: canvasHeight, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            let pillWidth = max(72, (viewport - 48 - Double(count - 1) * 8) / Double(max(1, count)))
            Button { motion.settle(expanded: motion.target < 0.5, immediately: reduceMotion) } label: {
                HStack(spacing: 7) {
                    Circle().fill(ink.color).frame(width: 5, height: 5)
                    Text(theme.name).font(.caption).lineLimit(1)
                    ThreadActionIcon(returning: motion.target > 0.5).frame(width: 24, height: 24)
                }.frame(width: max(44, pillWidth - 30), height: 28)
            }
            .afterimageControl().tint(ink.color).disabled(memberPositions.count < 2)
            .accessibilityLabel(motion.target > 0.5 ? "收回\(theme.name)" : "抽出\(theme.name)")
            .offset(x: offset + 24 + Double(lane) * (pillWidth + 8), y: 4)
        }
        .onChange(of: memberPositions, initial: true) { _, positions in
            motion.configure(positions: positions); motion.settle(expanded: true, immediately: reduceMotion)
        }
        .onDisappear { motion.suspend() }
        .onChange(of: phase) { _, value in if value != .active { motion.suspend() } }
    }
}
