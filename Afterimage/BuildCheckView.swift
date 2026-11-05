import SwiftUI

struct BuildCheckView: View {
    @AppStorage("phase0.tapCount") private var tapCount = 0

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.043, blue: 0.055).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 28) {
                Text("AFTERIMAGE")
                    .font(.caption).tracking(3)
                    .foregroundStyle(.secondary)
                Spacer()
                Rectangle()
                    .fill(Color.orange.opacity(0.7))
                    .frame(height: 1)
                    .accessibilityHidden(true)
                Text("从一个瞬间开始。")
                    .font(.largeTitle.weight(.light))
                Text("Phase 0 · 真机链路测试\n此页面只验证启动、交互和本地保存。")
                    .font(.body).foregroundStyle(.secondary)
                Button {
                    tapCount += 1
                } label: {
                    Text("留下一个测试印记 · \(tapCount)")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.72, green: 0.46, blue: 0.25))
                Text("已更新至覆盖安装测试版。确认原来的数字仍然保留。")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Text("BUILD \(build) · 不含正式记忆数据")
                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
            }
            .padding(28)
        }
    }
}
