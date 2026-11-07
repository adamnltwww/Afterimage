import SwiftUI

struct UsageGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("把瞬间留下，再沿着时间与主题慢慢回看。")
                        .font(.title3).foregroundStyle(AfterimageStyle.amber)
                    tip("记录一个瞬间", "轻点主页的＋，填写标题、正文和发生时间，也可以加入多张照片。主题用逗号或顿号分隔。同一个瞬间可以属于多个主题，保存后仍能编辑。")
                    tip("沿时间浏览", "左右滑动金色主轴，回看不同日期的记录。轻点标题、照片或节点可阅读全文；顶部 AFTERIMAGE 的金色进度提示当前位置。时间间隔经过压缩，准确时间请在详情中查看。")
                    tip("快速找到一条记录", "轻点放大镜打开时间索引，搜索标题、正文或主题，也可以直接跳到最早或最近的瞬间。")
                    tip("把主题牵出来", "先选择一个主题，再向上拖动它的节点，相邻记录会逐步跟随；继续上拉可展开整条主题线，向下拖动收回。也可以使用抽出按钮。至少两个瞬间保留有效关联时才能抽丝；只有一个瞬间时，仍能进入主题阅读页。")
                    tip("阅读与整理主题", "选择主题后，轻点箭头进入主题阅读页，按时间阅读相关瞬间。在更多中的主题管理里，可以重命名、改色、合并或删除主题。删除主题不会删除记录正文与照片。并行抽丝可对照多个主题。")
                    tip("照片与发生时间", "轻点详情中的照片进入全屏，双指缩放后可拖动查看。首次导入照片时，默认使用首张照片的拍摄时间填写发生时间；可在设置里关闭，或在保存前手动修改。")
                    tip("推荐主题与手动关联", "主题推荐依据标题与正文在本机完成，勾选后才会随记录保存。设置里可以关闭推荐或关闭自动选中。详情中还可以为两个瞬间手动写下联系，保留只有你知道的关联。")
                    tip("回顾与分享", "在更多中的时间回顾与长图里，按日期范围和主题筛选，选择最多12个瞬间，预览后分享长图。较长正文会显示摘要，导出前可检查内容与顺序。")
                    tip("备份与恢复", "记录默认保存在本机。通过更多中的 iCloud 备份与恢复，可把备份文件保存到 iCloud Drive 或本机，再从文件恢复。备份需要手动创建，不是实时同步；更换设备或安装环境前，建议先备份。")
                    tip("按自己的习惯设置", "在更多中的设置里调整开屏、动态效果、触感、主题推荐、照片时间和正文摘要。关闭开屏动画后，下次启动直接渐显主页；减少动态效果会简化动画，并尊重系统的辅助功能设置。")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
            .afterimageSheetSurface()
            .navigationTitle("如何浏览与抽丝")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }

    private func tip(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Text(text).font(.body).foregroundStyle(.secondary).lineSpacing(5)
        }
    }
}
