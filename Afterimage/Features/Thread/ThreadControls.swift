import SwiftUI

struct ThreadControls: View {
    let themes: [MemoryTag]
    @Binding var selectedKey: String?
    let count: Int
    let motion: ThreadMotion
    let openTheme: (MemoryTag) -> Void
    let openIndex: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openingPresentation) private var opening
    @State private var showThemes = false
    @AppStorage("thread.didDiscoverLift") private var discoveredLift = false
    @State private var showLiftHint = false

    var body: some View {
        Color.clear.frame(height: 0)
            .overlay(alignment: .topLeading) {
                if showLiftHint && !discoveredLift {
                    Label("向上牵起光结，让相关瞬间跟随", systemImage: "hand.draw")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24)
                        .offset(y: 8).allowsHitTesting(false)
                }
            }
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItemGroup(placement: .bottomBar) {
                        leftControls
                        Spacer()
                        rightControls
                    }.sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItemGroup(placement: .bottomBar) {
                        leftControls
                        Spacer()
                        rightControls
                    }
                }
            }
            .background {
                FullWidthSheet(isPresented: $showThemes, initialHeight: 430) {
                NavigationStack {
                    List {
                        themeChoice(name: "不选择主题", tag: nil)
                        ForEach(themes, id: \.key) { tag in
                            themeChoice(name: tag.name, tag: tag)
                                .accessibilityIdentifier("thread.theme.\(tag.key)")
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden).afterimageSheetSurface()
                    .accessibilityIdentifier("themes.picker")
                    .navigationTitle("选择主题").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showThemes = false } } }
                }
                }.frame(width: 0, height: 0)
            }
            .task(id: selectedKey) {
                guard selectedKey != nil, count >= 2, !discoveredLift else { showLiftHint = false; return }
                showLiftHint = true
                do {
                    try await Task.sleep(for: .seconds(4))
                    showLiftHint = false; discoveredLift = true
                } catch { showLiftHint = false }
            }
            .onChange(of: motion.isDragging) { _, dragging in if dragging { discoveredLift = true; showLiftHint = false } }
    }
    private var themeName: String { themes.first(where: { $0.key == selectedKey })?.name ?? "主题" }
    private var shortThemeName: String { themeName.count > 8 ? String(themeName.prefix(7)) + "…" : themeName }

    private func themeChoice(name: String, tag: MemoryTag?) -> some View {
        Button { choose(tag?.key) } label: {
            HStack(spacing: 12) {
                Circle().fill(tag.map { ThemePalette.ink($0.colorIndex).color } ?? .clear)
                    .frame(width: 8, height: 8).accessibilityHidden(true)
                Text(name).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "checkmark").opacity(selectedKey == tag?.key ? 1 : 0)
                    .accessibilityHidden(true)
            }.frame(minHeight: 36).contentShape(Rectangle())
                .alignmentGuide(.listRowSeparatorLeading) { _ in 20 }
                .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
        }
        .listRowBackground(AfterimageStyle.surface)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .accessibilityValue(selectedKey == tag?.key ? "已选中" : "未选中")
    }

    private var leftControls: some View {
        HStack(spacing: 4) {
            Button { showThemes = true } label: {
                HStack(spacing: 6) {
                    Text(shortThemeName).font(.subheadline.weight(.medium)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                }.padding(.horizontal, 6).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .accessibilityIdentifier("thread.themePicker").accessibilityLabel("选择主题，\(themeName)")
            .disabled(themes.isEmpty)
            if let tag = themes.first(where: { $0.key == selectedKey }) {
                controlDivider
                Button { openTheme(tag) } label: { Image(systemName: "book").frame(width: 44, height: 44).contentShape(Rectangle()) }
                    .accessibilityLabel("查看主题").accessibilityIdentifier("theme.open")
            }
        }.buttonStyle(.plain).font(.system(size: 20)).foregroundStyle(AfterimageStyle.amber).afterimageControlGroup()
            .opacity(opening?.contentOpacity ?? 1)
    }
    private var rightControls: some View {
        HStack(spacing: 4) {
            if selectedKey != nil {
                Button { motion.settle(expanded: motion.target < 0.5, immediately: reduceMotion) } label: {
                    ThreadActionIcon(returning: motion.target > 0.5).frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("thread.toggle")
                .accessibilityLabel(motion.target > 0.5 ? "收回主题" : "抽出主题")
                .accessibilityHint(motion.target > 0.5 ? "让主题丝归回主轴" : "将相关瞬间沿主题丝牵起")
                .disabled(count < 2)
                controlDivider
            }
            Button(action: openIndex) { Image(systemName: "magnifyingglass").frame(width: 44, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel("时间索引与搜索").accessibilityIdentifier("timeline.index")
        }.buttonStyle(.plain).font(.system(size: 20)).foregroundStyle(AfterimageStyle.amber).afterimageControlGroup()
            .opacity(opening?.contentOpacity ?? 1)
    }
    private var controlDivider: some View {
        Rectangle().fill(Color.primary.opacity(0.16)).frame(width: 0.5, height: 18).accessibilityHidden(true)
    }

    private func choose(_ key: String?) {
        motion.settle(expanded: false, immediately: true)
        selectedKey = key
        showThemes = false
    }
}
