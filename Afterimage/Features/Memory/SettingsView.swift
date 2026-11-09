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
                    Text("启动")
                } footer: {
                    Text("关闭后，下次启动直接渐显进入主页。")
                }
                Section {
                    Toggle("减少动态效果", isOn: $reduceMotion)
                    Toggle("触感反馈", isOn: $haptics)
                    Toggle("显示正文摘要", isOn: $summaries)
                } header: { Text("浏览体验") } footer: {
                    Text("减少动态效果会简化过渡、暂停丝线流动与快速浏览惯性。正文摘要显示在无照片记录的标题下。")
                }
                Section {
                    Toggle("本地主题推荐", isOn: $suggestions)
                    Toggle("自动选中推荐主题", isOn: $autoSelect)
                        .disabled(!suggestions)
                } header: { Text("记录与主题") } footer: {
                    Text("根据标题和正文在本机推荐。自动选中仅用于新记录，已有主题不受影响。")
                }
                Section {
                    Toggle("采用照片拍摄时间", isOn: $photoDate)
                } header: { Text("照片导入") } footer: {
                    Text("首次添加照片时，用首张照片的拍摄时间填写记录时间。")
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

private struct AppReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var afterimageReduceMotion: Bool {
        get { self[AppReduceMotionKey.self] }
        set { self[AppReduceMotionKey.self] = newValue }
    }
}

struct AppMotionPreference: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceMotion = false
    func body(content: Content) -> some View {
        content.environment(\.afterimageReduceMotion, systemReduceMotion || reduceMotion)
    }
}
