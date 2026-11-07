import SwiftUI

enum AppPreferences {
    static let openingAnimationKey = "appearance.openingAnimationEnabled"
    static let reduceMotionKey = "appearance.reduceMotion"
    static let hapticsKey = "interaction.haptics"
    static let suggestionsKey = "editor.themeSuggestions"
    static let autoSelectKey = "editor.autoSelectSuggestions"
    static let photoDateKey = "editor.usePhotoDate"
    static let summariesKey = "timeline.showSummaries"
    static var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true
    }
    static var openingAnimationEnabled: Bool {
        UserDefaults.standard.object(forKey: openingAnimationKey) as? Bool ?? true
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.openingAnimationKey) private var openingAnimationEnabled = true
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceMotion = false
    @AppStorage(AppPreferences.hapticsKey) private var haptics = true
    @AppStorage(AppPreferences.suggestionsKey) private var suggestions = true
    @AppStorage(AppPreferences.autoSelectKey) private var autoSelect = true
    @AppStorage(AppPreferences.photoDateKey) private var photoDate = true
    @AppStorage(AppPreferences.summariesKey) private var summaries = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("开屏动画", isOn: $openingAnimationEnabled)
                        .accessibilityIdentifier("settings.openingAnimation")
                } header: {
                    Text("启动与显示")
                } footer: {
                    Text("开启时，字标上移后进入主页。关闭后，下次启动直接渐显进入主页。")
                }
                Section {
                    Toggle("减少动态效果", isOn: $reduceMotion)
                    Toggle("触感反馈", isOn: $haptics)
                } header: { Text("动效与触感") } footer: {
                    Text("减少动态效果会简化过渡并暂停丝线持续流动，同时始终尊重系统的减少动态效果设置。触感反馈用于抽丝与保存结果。")
                }
                Section {
                    Toggle("本地主题推荐", isOn: $suggestions)
                    Toggle("自动选中推荐主题", isOn: $autoSelect)
                        .disabled(!suggestions)
                } header: { Text("记录与主题") } footer: {
                    Text("根据标题和正文在本机推荐主题。自动选中仅用于新记录；关闭后仍可手动勾选推荐项。已有主题不会被移除。")
                }
                Section {
                    Toggle("采用照片拍摄时间", isOn: $photoDate)
                } header: { Text("照片导入") } footer: {
                    Text("首次添加照片时，用首张照片的拍摄时间填写发生时间；关闭后保留当前选择的时间。")
                }
                Section {
                    Toggle("显示正文摘要", isOn: $summaries)
                } header: { Text("时间线") } footer: {
                    Text("在无照片记录的标题下显示一行正文摘要。关闭后仍可点开阅读完整内容。")
                }
            }
            .afterimageSheetSurface()
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .tint(AfterimageStyle.amber)
    }
}

struct AppMotionPreference: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceMotion = false
    func body(content: Content) -> some View {
        content.environment(\.accessibilityReduceMotion, systemReduceMotion || reduceMotion)
    }
}
