# Hero 滚动与 pop 末段几何修正（2026-10-02）

**历史修正记录。当前 P0 architecture accepted / frozen，见[verification](verification.md)。本页描述的详细临时诊断已清理，只保留最小 Debug 导航/完成摘要；末段轻微 handoff 晃动已移交 P3 / 最终视觉 polish。**

**下面是上一轮记录；本轮零高度诊断与编译状态见[后续记录](zero-height-zoom-diagnostics.md)。上一轮 Debug build 通过时实际没有定义 DEBUG，诊断代码未编译，不能用该 build 证明这些日志能运行。**

本轮仅修改 `PetDetail.swift`、`PortraitSurface.swift`、`AlignedNavigation.swift`。保留透明 Grid 和系统 UIKit zoom bridge，不进入 P1。

## 已确认的滚动根因

Hero 在 `ScrollView.safeAreaInset(edge: .top)` 中，属于固定 inset，而非正文滚动内容。现移到 ScrollView 内 VStack 的第一项。真实 UIImageView 仍通过弱引用 registry 注册 destination，其坐标来自此滚动区域，alignment provider 实时转换到详情 VC 坐标。

## pop 几何修正与证据边界

原来注册的是 UIView 内的子 UIImageView；每次父级 `layoutSubviews` 都用 `bitmap.frame = bounds.insetBy(...)` 重写它的几何。此路径没有区分正常布局与转场布局，也没有显式屏蔽 UIImageView intrinsic size 对 SwiftUI 提案的影响。本轮移除这层布局写入：PortraitSurface 本身就是屏幕显示、registry 注册和系统 source provider 返回的同一 UIImageView。原有每边 8% 内缩改由 SwiftUI 在图片视图外表达，图片区域尺寸明确采用布局提案，不采用位图 intrinsic size。

Grid 的 adaptive minimum 150、列间距 20、行间距 28、外边距 24、Cell 内文字间距 8 均未修改。两端仍为 scaleAspectFit、相同 UIImage 和完整 PNG 区域（包括资源自带透明像素）；未裁切 alpha bbox。恢复 source 不写 SwiftUI state，不增加 implicit animation、spring、延迟、crossfade、隐藏或回位动画。App 不创建或移除系统临时转场图片。

**第二项尚不能宣称唯一真机根因已证实，也不能宣称末段跳动已经通过验收。** 本轮消除了重复布局路径，但未采集这次真机回归的运行 rect。删除背景前后的生产源码没有受 Git 跟踪的历史可用于严格对比，不把“去掉灰色本身改变了 Cell frame”写成已证实事实。

## 真机 Debug 诊断

Console / Xcode 控制台筛选 subsystem `top.aoe.rocom.prototype`、category `navigation`：

- `pop start`：系统 `willShow(root)` 回调时的 source window rect、center、width、height、位图大小、contentMode、layer animation keys。
- `pop source-provider`：系统 resolve source / alignment 时读取的实际 source window rect。
- `zoom alignment`：返回的详情 VC alignment rect、Hero window rect，以及 context.sourceView 的 window rect。
- `pop completion`：`didShow(root)` 后真实 Grid UIImageView 的 window rect，以及相对最后目标的 `targetDelta`、相对开始的 `startDelta`，分别列出 center / width / height 差值；同时记录 `sameSource` 和残留 layer animation keys。取消返回详情则记录 cancelled=true，不当作完成 pop。

alignmentRectProvider 返回的是**详情坐标中的 Hero 区域**，其大小不应直接与 Grid rect 判等。UIKit 将它对齐到 source provider 返回的 source；应比较后者的 window rect 与完成后的真实 source window rect。目标为 `targetDelta center=(0,0) width=0 height=0`、`sameSource=true`。视图未在 window 时记为 unavailable，不伪造测量。

日志仅在 Debug 编译，读取几何，不驱动布局或动画。本轮没有实际运行这些日志，因此没有可填入的实测三阶段数值。

## 验证

仅一次无签名 Debug iOS device build，结果 `BUILD SUCCEEDED`：

```sh
DEVELOPER_DIR=/Applications/Xcode_27.app/Contents/Developer xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/ios27-p0/device-final CODE_SIGNING_ALLOWED=NO build
```

日志：`/tmp/rocom-hero-regression-build.log`。提示包含未依赖 AppIntents 的 metadata extraction 和 interface orientations，不影响编译成功。未运行 XCUITest、host tests、accessibility audit、Web build 或完整回归；未安装运行真机。
