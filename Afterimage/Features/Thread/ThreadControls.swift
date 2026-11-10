import SwiftUI

struct ThreadControls: View {
    let themes: [MemoryTag]
    @Binding var selectedKey: String?
    let count: Int
    let motion: ThreadMotion
    let openTheme: (MemoryTag) -> Void
    let openIndex: () -> Void
    @Environment(\.afterimageReduceMotion) private var reduceMotion
    @Environment(\.openingPresentation) private var opening
    @Environment(\.decorativeMotion) private var decorativeMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var showThemes = false
    @AppStorage("thread.didDiscoverLift") private var discoveredLift = false
    @State private var showLiftHint = false

    var body: some View {
        let reveal = opening?.contentOpacity ?? 1
        let returning = motion.target > 0.5
        return Color.clear.frame(height: 0)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    if selectedKey != nil {
                        Text("\(themeName) · \(count) 个瞬间")
                            .font(.caption).foregroundStyle(AfterimageStyle.amber)
                            .lineLimit(2).accessibilityIdentifier("thread.context")
                    }
                    if showLiftHint && !discoveredLift {
                        Label("向上牵起光结，让相关瞬间跟随", systemImage: "hand.draw")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24).offset(y: 48).opacity(reveal).allowsHitTesting(false)
            }
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItemGroup(placement: .bottomBar) {
                        leftControls.opacity(reveal)
                        Spacer()
                        rightControls(returning: returning).opacity(reveal)
                    }.sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItemGroup(placement: .bottomBar) {
                        leftControls.opacity(reveal)
                        Spacer()
                        rightControls(returning: returning).opacity(reveal)
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
            .onChange(of: showThemes) { _, shown in
                decorativeMotion?.setVisible(!shown && scenePhase == .active && !reduceMotion)
                if shown { motion.suspend() }
            }
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
    }
    private func rightControls(returning: Bool) -> some View {
        HStack(spacing: 4) {
            if selectedKey != nil {
                Button { motion.settle(expanded: motion.target < 0.5, immediately: reduceMotion) } label: {
                    ThreadActionIcon(returning: returning).frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("thread.toggle")
                .accessibilityLabel(returning ? "收回主题" : "抽出主题")
                .accessibilityHint(returning ? "让主题丝归回主轴" : "将相关瞬间沿主题丝牵起")
                .disabled(count < 2)
                controlDivider
            }
            Button(action: openIndex) { Image(systemName: "magnifyingglass").frame(width: 44, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel("时间索引与搜索").accessibilityIdentifier("timeline.index")
        }.buttonStyle(.plain).font(.system(size: 20)).foregroundStyle(AfterimageStyle.amber).afterimageControlGroup()
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
