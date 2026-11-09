import SwiftUI
import SwiftData

struct MemoryLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openingPresentation) private var opening
    @Query(sort: [SortDescriptor(\MemoryRecord.occurredAt, order: .reverse),
                  SortDescriptor(\MemoryRecord.createdAt, order: .reverse)]) private var records: [MemoryRecord]
    let isDemo: Bool
    @State private var createMemory = false
    @State private var selected: MemoryRecord?
    @State private var errorMessage: String?
    @State private var showHelp = false
    @State private var showReview = false
    @State private var showBackup = false
    @State private var showThemes = false
    @State private var showComparison = false
    @State private var showMore = false
    @State private var showSettings = false
    @State private var moreDestination: String?
    @State private var readingPosition = TimelineReadProgress()
    @State private var timelineScrubber = TimelineScrubber()
    @ScaledMetric(relativeTo: .body) private var moreRowHeight: CGFloat = 56

    var body: some View {
        let reveal = opening?.contentOpacity ?? 1
        return NavigationStack {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 28) {
                    if records.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            MemoryVisual(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, photoData: nil)
                                .frame(height: min(190, geometry.size.height * 0.28)).clipShape(RoundedRectangle(cornerRadius: 20))
                            Text("从一个瞬间开始。")
                                .font(.title2.weight(.light))
                            Text("写下一句话，放进几张照片；共同的主题，让瞬间彼此连接。")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button("记录第一个瞬间", systemImage: "plus") { createMemory = true }
                                .afterimageControl(prominent: true)
                        }
                        .padding(.vertical, 12)
                        .opacity(reveal)
                    } else {
                        MemoryTimelineView(records: records, select: { selected = $0 }, browsingProgress: { value, date in
                            readingPosition.value = value
                            readingPosition.date = date
                        }, scrubber: timelineScrubber)
                            .padding(.horizontal, -24)
                            .overlay(alignment: .top) {
                                TimelineScrubDate(progress: readingPosition, activity: timelineScrubber.activity)
                                    .padding(.top, 4)
                            }
                    }
                }
                .padding(.horizontal, 24)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .background {
                    if records.isEmpty {
                        TimelineSilkField(offset: 0, viewport: geometry.size.width,
                                          contentWidth: geometry.size.width, height: geometry.size.height)
                            .opacity(1 - (opening?.contentOpacity ?? 1) * 0.8)
                    }
                }
            }
            .background(AfterimageStyle.background)
            .scrollIndicators(.hidden)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isDemo {
                    if #available(iOS 26.0, *) {
                        ToolbarItem(placement: .topBarLeading) { moreButton.opacity(reveal) }
                            .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .topBarLeading) { moreButton.opacity(reveal) }
                    }
                }
                ToolbarItem(placement: .principal) {
                    TimelineScrubWordmark(progress: readingPosition, scrubber: timelineScrubber,
                                          empty: records.isEmpty, externalWordmark: !isDemo && opening != nil,
                                          enabled: reveal >= 0.99)
                }
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarTrailing) { addButton.opacity(reveal) }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarTrailing) { addButton.opacity(reveal) }
                }
            }
            .sheet(isPresented: $createMemory) { MemoryEditorView() }
            .sheet(item: $selected) { record in
                MemoryDetailView(record: record)
            }
            .sheet(isPresented: $showReview) { MemoryReviewView() }
            .sheet(isPresented: $showBackup) { BackupView() }
            .sheet(isPresented: $showThemes) { ThemeManagementView() }
            .sheet(isPresented: $showComparison) { ThreadComparisonView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .background {
                FullWidthSheet(isPresented: $showMore, initialHeight: moreRowHeight * 6 + 204,
                               fixedHeight: true, onDismiss: openMoreDestination) {
                    NavigationStack {
                        ScrollView {
                            VStack(spacing: 0) {
                                VStack(spacing: 0) {
                                moreRow("时间回顾与长图", symbol: "calendar", destination: "review")
                                moreRow("并行抽丝", symbol: "line.3.horizontal", destination: "compare")
                                moreRow("主题管理", symbol: "tag", destination: "themes")
                                moreRow("iCloud 备份与恢复", symbol: "icloud", destination: "backup", separator: false)
                                }.background(AfterimageStyle.surface, in: RoundedRectangle(cornerRadius: 24))
                                    .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.04), lineWidth: 0.5) }
                                VStack(spacing: 0) {
                                moreRow("如何浏览与抽丝", symbol: "hand.draw", destination: "help")
                                moreRow("设置", symbol: "gearshape", destination: "settings", separator: false)
                                }.background(AfterimageStyle.surface, in: RoundedRectangle(cornerRadius: 24))
                                    .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.04), lineWidth: 0.5) }
                                    .padding(.top, 14)
                                Text("AFTERIMAGE · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") / BUILD \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?")")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 20).padding(.bottom, 8)
                            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 24)
                        }.afterimageSheetSurface().accessibilityIdentifier("more.scroll")
                            .navigationTitle("更多").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showMore = false } } }
                    }
                }.frame(width: 0, height: 0)
            }
            .sheet(isPresented: $showHelp) {
                UsageGuideView()
            }
            .alert("未能完成", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .onAppear { context.autosaveEnabled = false }
        .onChange(of: showMore) { _, shown in if shown { timelineScrubber.stop() } }
        .onChange(of: createMemory) { _, shown in if shown { timelineScrubber.stop() } }
        .onChange(of: selected?.id) { _, _ in timelineScrubber.stop() }
        .overlay {
            if !isDemo, let opening { OpeningWordmark(presentation: opening) }
        }
    }


    private var moreButton: some View {
        Button { showMore = true } label: {
            Image(systemName: "ellipsis").font(.system(size: 22))
                .frame(width: 30, height: 30)
        }
            .afterimageControl(icon: true)
            .accessibilityLabel("更多选项").accessibilityIdentifier("library.more")
    }

    private var addButton: some View {
        Button { createMemory = true } label: {
            Image(systemName: "plus").font(.system(size: 24, weight: .regular))
                .frame(width: 30, height: 30)
        }
            .afterimageControl(icon: true)
            .accessibilityLabel("记录瞬间").accessibilityIdentifier("memory.add")
    }


    private func moreRow(_ title: String, symbol: String, destination: String, separator: Bool = true) -> some View {
        Button { moreDestination = destination; showMore = false } label: {
            HStack(spacing: 16) {
                Image(systemName: symbol).frame(width: 24)
                Text(title).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.body).foregroundStyle(AfterimageStyle.amber)
                .padding(.horizontal, 20).frame(minHeight: moreRowHeight).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .overlay(alignment: .bottom) { if separator { Divider().padding(.leading, 60).padding(.trailing, 20) } }
    }
    private func openMoreDestination() {
        defer { moreDestination = nil }
        switch moreDestination {
        case "review": showReview = true
        case "compare": showComparison = true
        case "themes": showThemes = true
        case "backup": showBackup = true
        case "settings": showSettings = true
        case "help": showHelp = true
        default: break
        }
    }
}
