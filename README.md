# AFTERIMAGE

![AFTERIMAGE — 那些留下来的瞬间](docs/afterimage-banner.svg)

**那些留下来的瞬间。**

一句话，几张照片。让零散的记忆沿着时间铺开，也让共同的主题，把它们重新牵到一起。

AFTERIMAGE 是一款使用 SwiftUI 与 SwiftData 构建的原生 iPhone 记忆应用。文字、照片和主题落在流动的细丝上：左右滑动回看时间，向上牵起一条主题，读见原本分散的瞬间之间的联系。

[![iOS build](https://github.com/adamnltwww/Afterimage/actions/workflows/ios-build.yml/badge.svg)](https://github.com/adamnltwww/Afterimage/actions/workflows/ios-build.yml)

## 让记忆慢慢展开

### 沿时间浏览

流动的金色主轴承载瞬间，文字与照片围绕丝线排布。左右滑动浏览，打开时间索引，搜索标题、正文或主题，也可以直接回到最早或最近的一条记录。

### 把主题牵起来

同一个主题会串起不同时间的瞬间。选择主题后，可以用按钮抽出整条丝，也可以亲手向上牵起节点，让相邻瞬间依次跟随。继续上拉有弹性反馈，向下拖动则将细丝归还主轴。

主题拥有独立阅读页，可以重命名、调整颜色、合并或删除；也可以并行查看多个主题，比较同一段时间里的不同线索。

### 留下文字，也留下光

每个瞬间支持独立标题、正文和多张照片。照片可连续展开，也可进入全屏查看、缩放与平移。添加瞬间时，应用会通过本地关键词规则建议主题，仍可自行增删和调整。

主题产生的自动联系与用户创建的手动联系会明确区分。手动关联可添加说明，并能从关联两端查看。

### 回顾与分享

按时间筛选瞬间，预览并导出一张沿纵向细丝排布的长图。当前一次可选择最多 **12 个瞬间**；正文较长时显示摘要，分享前可核对实际预览。

## 数据与备份

- 记录与照片默认保存在本机，由 SwiftData 管理。
- 主题建议在本地完成，当前没有配置云端 AI 服务。
- 可将记录、照片、主题和关联导出为备份文件，保存到 iCloud Drive 或本机，再从文件恢复。
- **iCloud Drive 备份需要手动创建，并非实时同步。**恢复前会显示文件中的记录数量，同一瞬间不会重复导入，也不会覆盖本机已修改的版本。
- 独立演示空间使用单独的数据容器，不与正式记忆混用。

这个公开仓库包含源码、测试及生成式演示素材，不包含用户的记忆数据库、个人照片、备份文件或签名凭据。

## 界面与动效

深色背景、暖金字标与细丝构成界面的基本语言。iOS 26 及以上使用系统玻璃材质，较早的系统采用兼容样式；同时提供减少动态效果、减少透明度等适配。

开屏先浮现略微放大、带柔和金光的 AFTERIMAGE 字标，随后散丝出现并聚拢为主轴。字标上移时逐渐恢复正常大小，按钮与瞬间内容再一起淡入。开屏与阅读页面使用同一套主轴画布，跳过也保留柔和的收束过程。

## 获取安装包

1. 打开仓库的 [Actions](https://github.com/adamnltwww/Afterimage/actions) 页面。
2. 进入最近一次成功的 **iOS unsigned device build**。
3. 在 **Artifacts** 中下载 `Afterimage-版本-build-构建号`，解压得到 IPA。
4. 使用自己的签名方式安装到 iPhone；本项目开发时使用 iloader。

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
