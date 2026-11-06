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
    @State private var demoSession: DemoSession?
    @State private var showBuildCheck = false
    @State private var showHelp = false
    @State private var showReview = false
    @State private var showBackup = false
    @State private var showThemes = false
    @State private var showComparison = false
    @State private var showMore = false
    @State private var moreDestination: String?
    @State private var readingPosition = TimelineReadProgress()

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
                        MemoryTimelineView(records: records, select: { selected = $0 }, browsingProgress: { readingPosition.value = $0 })
                            .padding(.horizontal, -24)
                    }
                    if !isDemo && records.isEmpty {
                        Button("进入独立演示空间", systemImage: "sparkle.magnifyingglass", action: openDemo)
                            .accessibilityIdentifier("demo.open")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .opacity(reveal)
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
                    ReadingPositionWordmark(progress: readingPosition, empty: records.isEmpty,
                                            externalWordmark: !isDemo && opening != nil)
                        .frame(width: 190, height: 32)
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
            .sheet(isPresented: $showBuildCheck) { BuildCheckView() }
            .sheet(isPresented: $showReview) { MemoryReviewView() }
            .sheet(isPresented: $showBackup) { BackupView() }
            .sheet(isPresented: $showThemes) { ThemeManagementView() }
            .sheet(isPresented: $showComparison) { ThreadComparisonView() }
            .background {
                FullWidthSheet(isPresented: $showMore, onDismiss: openMoreDestination) {
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
                                // These stay mounted below the initial viewport and are revealed by resizing.
                                VStack(spacing: 0) {
                                    moreRow("演示空间", symbol: "sparkle.magnifyingglass", destination: "demo")
                                    moreRow("如何浏览与抽丝", symbol: "hand.draw", destination: "help")
                                    moreRow("构建链路测试", symbol: "checkmark.seal", destination: "build")
                                    Text("AFTERIMAGE · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") / BUILD \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?")")
                                        .font(.caption).foregroundStyle(.secondary).padding(24)
                                }.background(AfterimageStyle.surface, in: RoundedRectangle(cornerRadius: 24))
                                    .padding(.top, 108)
                            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 24)
                        }.afterimageSheetSurface().accessibilityIdentifier("more.scroll")
                            .navigationTitle("更多").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showMore = false } } }
                    }
                }.frame(width: 0, height: 0)
            }
            .sheet(isPresented: $showHelp) {
                NavigationStack {
                    ScrollView {
                        Text("左右滑动，沿时间浏览记忆。顶部 AFTERIMAGE 的金色光晕表示当前位置。\n\n时间轴显示标题，点击瞬间可查看完整正文。不同颜色的细丝表示不同主题；选择主题后，点箭头进入主题阅读页，可修改名称与颜色。\n\n一个瞬间也能进入主题页。至少两个瞬间保留有效关联时，可以抽丝。向上牵起节点，相邻瞬间会依次跟随；再上拉可抽出整条丝，向下拖动归还。\n\n点放大镜打开索引，搜索标题、正文或主题，也可以跳到最早或最近的瞬间。时间间距经过压缩，完整时间见详情。")
                            .font(.body).lineSpacing(8).padding(28)
                    }.afterimageSheetSurface()
                    .navigationTitle("沿光浏览")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showHelp = false } } }
                }.presentationDetents([.medium, .large])
            }
            .fullScreenCover(item: $demoSession) { session in
                DemoSpaceView(session: session) { demoSession = nil }
            }
            .alert("未能完成", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .onAppear { context.autosaveEnabled = false }
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

    private func openDemo() {
        do {
            demoSession = try DemoSession()
        } catch { errorMessage = "演示空间未能打开：\(error.localizedDescription)" }
    }

    private func moreRow(_ title: String, symbol: String, destination: String, separator: Bool = true) -> some View {
        Button { moreDestination = destination; showMore = false } label: {
            HStack(spacing: 16) {
                Image(systemName: symbol).frame(width: 24)
                Text(title).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.body).foregroundStyle(AfterimageStyle.amber)
                .padding(.horizontal, 20).frame(minHeight: 56).contentShape(Rectangle())
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
        case "demo": openDemo()
        case "help": showHelp = true
        case "build": showBuildCheck = true
        default: break
        }
    }
}
