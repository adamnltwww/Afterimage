import SwiftUI
import SwiftData

struct MemoryTimelineView: View {
    @Environment(\.afterimageReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openingPresentation) private var opening
    let records: [MemoryRecord]
    let select: (MemoryRecord) -> Void
    var browsingProgress: (Double, Date?) -> Void = { _, _ in }
    var scrubber: TimelineScrubber? = nil
    @Binding var dateFilter: TimelineDateFilter
    @State private var knownIDs = Set<UUID>()
    @State private var appeared = false
    @State private var showIndex = false
    @State private var readingTheme: MemoryTag?
    @Query private var linkChoices: [MemoryLink]
    @State private var selectedTheme: String?
    @State private var focusedID: UUID?
    @State private var threadMotion = ThreadMotion()
    @State private var contentOffset = 0.0

    private var themes: [MemoryTag] {
        var tags: [String: MemoryTag] = [:]
        for memory in records {
            for tag in memory.tags { tags[tag.key] = tag }
        }
        return tags.values.sorted { $0.name < $1.name }
    }

    private var ordered: [MemoryRecord] {
        records.filter { dateFilter.contains($0.occurredAt) }.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func weaveSpans(memories: [MemoryRecord], positions: [Double]) -> [ThemeWeave.Span] {
        var spans: [ThemeWeave.Span] = []
        let focusedTags = Set(memories.first(where: { $0.id == focusedID })?.tags.map(\.key) ?? [])
        for tag in themes {
            let indices = memories.indices.filter { memories[$0].tags.contains { $0.key == tag.key } }
            for (a, b) in zip(indices, indices.dropFirst()) {
                guard Resonance.enabled(memories[a].id, memories[b].id, tag: tag.key, choices: linkChoices) else { continue }
                spans.append(.init(start: positions[a], end: positions[b], key: tag.key,
                                   ink: ThemePalette.ink(tag.colorIndex), emphasized: focusedTags.contains(tag.key)))
            }
        }
        let index = Dictionary(uniqueKeysWithValues: memories.indices.map { (memories[$0].id, $0) })
        for choice in linkChoices where choice.tagKey == nil && choice.isEnabled {
            guard let a = index[choice.sourceID], let b = index[choice.targetID], a != b else { continue }
            spans.append(.init(start: min(positions[a], positions[b]), end: max(positions[a], positions[b]),
                               key: "manual", ink: ThemePalette.ink(5),
                               emphasized: focusedID == choice.sourceID || focusedID == choice.targetID))
        }
        return spans
    }

    var body: some View {
        let reveal = opening?.contentOpacity ?? 1
        return GeometryReader { geometry in
            let canvasHeight = max(1, geometry.size.height - 12)
            let memories = ordered
            let layout = TimelineLayout(dates: memories.map(\.occurredAt), viewport: geometry.size.width)
            let drawStart = floor(contentOffset / max(1, geometry.size.width)) * max(1, geometry.size.width) - geometry.size.width
            let drawEnd = drawStart + geometry.size.width * 3
            let linkedIDs = Resonance.linkedIDs(in: memories, choices: linkChoices)
            let spans = weaveSpans(memories: memories, positions: layout.positions)
            let selectedInk = ThemePalette.ink(themes.first(where: { $0.key == selectedTheme })?.colorIndex)
            let members = selectedTheme.map { Resonance.threadMembers(tag: $0, memories: memories, choices: linkChoices) } ?? []
            let memberPositions = memories.enumerated().filter { members.contains($0.element.id) }.map { layout.positions[$0.offset] }
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 12) {
                    ThreadControls(themes: themes, selectedKey: $selectedTheme, count: members.count, motion: threadMotion, openTheme: { readingTheme = $0 }, openIndex: { showIndex = true })
                        .sheet(item: $readingTheme) { ThemeReadingView(tag: $0) }
                    if dateFilter.mode != .all {
                        Button { dateFilter.mode = .all } label: {
                            Label(dateFilter.label + " · 清除筛选", systemImage: "xmark.circle")
                                .font(.caption).lineLimit(1).frame(minHeight: 44)
                        }.padding(.horizontal, 24).foregroundStyle(AfterimageStyle.amber)
                    }

                    ScrollView(.horizontal) {
                        ZStack(alignment: .topLeading) {
                            HStack(spacing: 0) {
                                Color.clear.frame(width: TimelineLayout.edgePadding).accessibilityHidden(true).id("timeline.leading")
                                ForEach(memories.indices, id: \.self) { index in
                                    let memory = memories[index]
                                    let width = index + 1 < memories.count ? layout.positions[index + 1] - layout.positions[index] : 260
                                    Group {
                                        if layout.positions[index] >= drawStart - 260 && layout.positions[index] <= drawEnd + 260 {
                                            TimelineMemoryColumn(memory: memory, x: layout.positions[index], above: index.isMultiple(of: 2), linked: linkedIDs.contains(memory.id), select: { record in
                                                focusedID = record.id
                                                select(record)
                                            }, threadMember: members.contains(memory.id), threadSelected: selectedTheme != nil, threadProgress: threadMotion.progress, memberPositions: memberPositions, threadBounds: memberPositions.first.flatMap { start in memberPositions.last.map { (start - ThreadGeometry.joinLength)...($0 + ThreadGeometry.joinLength) } }, motion: threadMotion, themeColor: selectedInk.color, canvasHeight: canvasHeight)
                                        } else {
                                            Color.clear.accessibilityHidden(true)
                                        }
                                    }
                                        .frame(width: width, height: canvasHeight)
                                        .id(memory.id)
                                        .transition(.scale(scale: 0.88).combined(with: .opacity))
                                }
                                Color.clear.frame(width: TimelineLayout.edgePadding).accessibilityHidden(true).id("timeline.trailing")
                            }
                            .opacity(reveal)
                        }
                        .frame(width: layout.width, height: canvasHeight, alignment: .topLeading)
                        .background(alignment: .topLeading) {
                            TimelineSilkField(offset: contentOffset, viewport: geometry.size.width,
                                              contentWidth: layout.width, height: canvasHeight,
                                              spans: spans, selectedKey: selectedTheme, progress: threadMotion.progress,
                                              memberPositions: memberPositions, displacements: threadMotion.displacements,
                                              focus: threadMotion.focusX, hasFocus: focusedID != nil, ink: selectedInk)
                        }
                        .coordinateSpace(name: "timeline.canvas")
                        .background {
                            TimelineScrollObserver(offset: $contentOffset, granularity: SilkTiling.width / 2, onOffset: { value in reportPosition(value, layout: layout, viewport: geometry.size.width, memories: memories) }, scrubber: scrubber).allowsHitTesting(false)
                        }
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: memories.map(\.id))
                    }
                    .scrollIndicators(.hidden)
                    .defaultScrollAnchor(.trailing)
                    .coordinateSpace(name: "timeline.viewport")
                    .modifier(TimelineScrollTracking(offset: $contentOffset, granularity: SilkTiling.width / 2, onOffset: { value in
                        reportPosition(value, layout: layout, viewport: geometry.size.width, memories: memories)
                    }))
                    .accessibilityIdentifier("timeline.scroll")
                    .overlay {
                        if memories.isEmpty {
                            ContentUnavailableView("这段时间还没有记录", systemImage: "calendar", description: Text("清除筛选可回到全部时间。"))
                        }
                    }
                    .sheet(isPresented: $showIndex) {
                        MemoryIndexView(memories: records.sorted { $0.occurredAt < $1.occurredAt }, locate: { id in
                            move(to: id, proxy: proxy)
                        }, locateEdge: { latest in
                            scrubber?.stop()
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
                                proxy.scrollTo(latest ? "timeline.trailing" : "timeline.leading", anchor: latest ? .trailing : .leading)
                            }
                        }, dateFilter: $dateFilter)
                    }
                    .onAppear {
                        threadMotion.configure(positions: memberPositions)
                        knownIDs = Set(memories.map(\.id))
                        appeared = true
                        reportPosition(contentOffset, layout: layout, viewport: geometry.size.width, memories: memories)
                    }
                    .onChange(of: selectedTheme) { _, _ in
                        focusedID = nil
                        move(to: memories.last(where: { members.contains($0.id) })?.id, proxy: proxy)
                    }
                    .onChange(of: themes.map(\.key)) { _, keys in
                        if let selectedTheme, !keys.contains(selectedTheme) {
                            self.selectedTheme = nil
                            threadMotion.settle(expanded: false, immediately: true)
                        }
                    }
                    .onDisappear { threadMotion.suspend(); scrubber?.stop() }
                    .onChange(of: showIndex) { _, shown in if shown { scrubber?.stop() } }
                    .onChange(of: scenePhase) { _, phase in
                        if phase != .active { threadMotion.suspend(); scrubber?.stop() }
                    }
                    .onChange(of: memberPositions) { old, new in
                        if old != new { threadMotion.configure(positions: new) }
                    }
                    .onChange(of: memories.map(\.id)) { _, ids in
                        scrubber?.stop()
                        let inserted = Set(ids).subtracting(knownIDs)
                        knownIDs = Set(ids)
                        if appeared, let memory = memories.last(where: { inserted.contains($0.id) }) {
                            move(to: memory.id, proxy: proxy)
                        }
                    }


                }
            }
        }
    }

    private func move(to id: UUID?, proxy: ScrollViewProxy) {
        guard let id else { return }
        scrubber?.stop()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) { proxy.scrollTo(id, anchor: .center) }
    }

    private func reportPosition(_ offset: Double, layout: TimelineLayout, viewport: Double, memories: [MemoryRecord]) {
        let date = layout.nearestIndex(at: offset, viewport: viewport).map { memories[$0].occurredAt }
        browsingProgress(layout.browsingProgress(at: offset, viewport: viewport), date)
    }
}

