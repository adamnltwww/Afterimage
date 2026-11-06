# AFTERIMAGE

<p align="center"><img src="Afterimage/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="AFTERIMAGE 图标：暖金四角星与交叠光带" /></p>

**1.0.0 · BUILD 97**　[下载 IPA](https://github.com/adamnltwww/Afterimage/releases/download/v1.0.0/AFTERIMAGE-1.0.0-build97.ipa) · [版本说明](https://github.com/adamnltwww/Afterimage/releases/tag/v1.0.0)

![AFTERIMAGE — 那些留下来的瞬间](docs/afterimage-banner.svg)

**那些留下来的瞬间。**

一句话，几张照片。让零散的记忆沿着时间铺开，也让共同的主题，把它们重新牵到一起。

AFTERIMAGE 是一款使用 SwiftUI 与 SwiftData 构建的原生 iPhone 记忆应用。文字、照片和主题落在流动的细丝上：左右滑动回看时间，向上牵起一条主题，读见原本分散的瞬间之间的联系。

[![iOS build](https://github.com/adamnltwww/Afterimage/actions/workflows/ios-build.yml/badge.svg)](https://github.com/adamnltwww/Afterimage/actions/workflows/ios-build.yml)

## 让记忆慢慢展开

### 记录一个瞬间

从右上角的「＋」开始，写下独立标题与正文，选择发生时间，再加入几张照片。可以记一段完整的故事，也可以只留下当时的一句话。

- **文字与照片放在一起**：一个瞬间支持多张照片，打开详情后可连贯阅读文字与影像。
- **为记忆添加主题**：手动输入主题，用逗号或顿号分隔；一个瞬间可以属于多个主题。
- **本地自动匹配**：根据标题和正文推荐主题，新建时默认选中匹配项，轻点即可取消。已有瞬间编辑时，也可以选择补充新的推荐主题。
- **随时整理**：保存后仍可编辑内容、照片与主题，记录不必一次写完。

主题匹配使用本机关键词规则，无需把正文交给外部 AI。推荐只是整理的起点，最终保留哪些主题由你决定。

### 沿着主轴回看时间

金色细丝是一条可以左右滑动的时间主轴。日期、标题、正文摘要与照片围绕丝线排布，轻点瞬间即可进入完整阅读。

- **自由浏览**：沿水平方向回看不同时间的记录，在丝线与内容之间保持连续的空间关系。
- **快速定位**：打开时间索引，按日期查找记录，或直接跳到最早、最近的瞬间。
- **轻量搜索**：在索引中搜索标题、正文或主题，找到后跳回对应的主轴位置。

### 把一个主题牵起来

<p align="center">
  <img src="docs/screenshots/timeline.png" width="250" alt="主轴：沿金色丝线排列的照片、日期与文字" />
  <img src="docs/screenshots/parallel-threads.png" width="250" alt="并行抽丝：在同一时间轴上对照不同颜色的主题" />
</p>
<p align="center"><sub>主轴浏览 · 并行抽丝。真实界面截图，使用演示记录与示意图片。</sub></p>

「散步」「湖边」「喜欢」……分散在不同日子的记录，可以因为同一个主题再次相遇。主题拥有自己的颜色，也拥有一条从主轴中牵出的细丝。

- **按钮抽丝与手动牵引**：选中主题后，可以用抽出按钮展开，也可以向上拖动节点，让相邻瞬间逐步跟随。继续上拉有弹性反馈，向下拖动可以收回。
- **独立阅读空间**：进入主题页，按时间查看这个主题下的所有瞬间；轻点任意一条继续阅读详情。
- **并行对照**：同时选择多个主题，让彩色细丝在主轴上下展开，对照同一段时间里的不同线索。进入时定位到所选主题的首个瞬间。
- **统一整理**：重命名主题、调整颜色，或在主题管理中选择多个主题合并。选中后，合并与删除操作会出现在固定操作区。

合并时保留目标主题的颜色；删除主题只移除标签及其主题关联，瞬间正文与照片仍会保留。

<p align="center">
  <img src="docs/screenshots/theme-management.png" width="250" alt="主题管理：选中主题后，合并与删除按钮固定显示在底部" />
</p>

### 让照片完整展开

主轴上的照片是进入记忆的入口。打开瞬间后，多张照片沿阅读方向连续展开，文字与照片一起构成完整的记录。

轻点照片进入全屏，可以双指缩放、放大后平移查看细节，再回到原来的阅读位置。无需把一组照片拆成多个瞬间。

### 为两个瞬间写下联系

有些联系来自共同主题，有些只有自己知道。AFTERIMAGE 将这两种来源分开显示：

- **共同主题**：两个瞬间拥有相同主题时产生的自动联系，可以按主题调整是否连接。
- **手动关联**：自己选择另一个瞬间，写下「为什么把它们放在一起」。说明会在关联两端同步显示，也可以编辑或移除。

查找关联对象时可以搜索文字或标签。手动说明独立保留，不会被共同主题的联系代替。

### 把一段时间收成长图

在「时间回顾与长图」中，按全部、本月、今年或自选日期范围回顾记录，也可以进一步筛选主题。

选中想保留的瞬间，先查看完整长图预览，再通过系统分享菜单导出。纵向金色细丝贯穿画面，日期、照片与文字分列两侧，把一段时间连成一张图。

当前一次最多选择 **12 个瞬间**；正文较长时显示摘要。预览与导出的内容一致，分享前可以检查顺序和文字。

<p align="center">
  <img src="docs/screenshots/long-image.png" width="360" alt="完整长图示例：纵向金色细丝串起两侧的日期、照片与文字" />
</p>
<p align="center"><sub>长图导出示例，使用演示文字与示意图片。</sub></p>

## 数据与备份

- 记录与照片默认保存在本机，由 SwiftData 管理。
- 主题建议在本地完成，当前没有配置云端 AI 服务。
- 可将记录、照片、主题和关联导出为备份文件，保存到 iCloud Drive 或本机，再从文件恢复。
- **iCloud Drive 备份需要手动创建，并非实时同步。**恢复前会显示文件中的记录数量，同一瞬间不会重复导入，也不会覆盖本机已修改的版本。
- 独立演示空间使用单独的数据容器，不与正式记忆混用。

这个公开仓库包含源码、测试及生成式演示素材，不包含用户的记忆数据库、个人照片、备份文件或签名凭据。

## 界面与动效

深色背景、暖金字标与细丝构成界面的基本语言。iOS 26 及以上使用系统玻璃材质，较早的系统采用兼容样式；同时提供减少动态效果、减少透明度等适配。

开屏只保留 AFTERIMAGE 字标：文字淡入，平滑上移到顶栏并恢复正常大小；到位后，主轴、按钮与瞬间内容一起渐显。字标直接留在主页，开屏期间不再展开或收束丝线。

App 图标采用墨黑与暖金，以四角星为中心，光带与半透明弧面相对展开。

## 获取安装包

1. 打开 [1.0.0 发布页](https://github.com/adamnltwww/Afterimage/releases/tag/v1.0.0)，下载 `AFTERIMAGE-1.0.0-build97.ipa`。
2. 使用自己的签名方式安装到 iPhone；本项目开发时使用 iloader。

后续开发构建可在 [Actions](https://github.com/adamnltwww/Afterimage/actions) 中查看；Release 页面保留正式版本安装包。

构建产物是 **未签名的 arm64 IPA**，需要自行签名，不是 App Store 安装包。覆盖安装并保留现有数据时，请保持相同的 Bundle Identifier：`com.adamnltwww.afterimage`。备份重要记录后再更换安装环境。

## 本地开发

运行目标为 **iOS 17.0 及以上**。当前云端构建使用标准 `xcode-27` macOS 环境；本地需要支持当前源码所用 SDK 的 Xcode，以及 XcodeGen。

```sh
brew install xcodegen
xcodegen generate
open Afterimage.xcodeproj
```

在 Xcode 中选择自己的签名团队与设备后构建。项目配置维护在 `project.yml`，生成的 `.xcodeproj` 不提交到仓库。

```sh
# 先查看本机可用的模拟器，替换下面的设备名称
xcrun simctl list devices available
xcodebuild -project Afterimage.xcodeproj -scheme Afterimage \
  -destination 'platform=iOS Simulator,name=YOUR_SIMULATOR_NAME' \
  CODE_SIGNING_ALLOWED=NO test
```

## 源码结构

```text
Afterimage/
  Features/
    Memory/       瞬间编辑、阅读、照片、备份与开屏
    Timeline/     时间布局、主轴与滚动
    Thread/       主题细丝、抽丝手势与物理反馈
    Resonance/    自动和手动关联
  Models/         数据模型、归档与本地主题建议
Tests/            单元、持久化、几何与像素检查
UITests/          界面与交互回归
project.yml       XcodeGen 配置
```

## 当前边界

项目仍在持续打磨。地图、云端 AI、ECHO 与 DARKROOM 尚未纳入当前版本。新功能与界面变化以源码、构建结果和实际预览为准。
