# 生产 zoom 零高度诊断（2026-10-02）

**历史诊断记录，已停止继续追查。后续一次确认 device build 已通过（`/tmp/rocom-zero-height-confirm-build.log`）；用户真机该次 pop 无零高度/1320x0错误、sameSource=true、completion几何delta=0。当前P0架构已接受并冻结，详细诊断已从生产源码移除，剩余轻微视觉handoff晃动承接到P3 / 最终视觉polish，见[verification](verification.md)。下列旧采集方法与编译失败仅保留为历史，不是当前运行要求或最终编译状态。**

用户真机仍有 pop 末段轻微晃动，且两次报告 `Failed to create 1320x0 image slot (alpha=1 wide=1)`。本轮优先追踪零高度来源，不以 source frame 偏差为已证实根因。不改变共享转场方案，不进入 P1。

## 已确认问题与必要小修

1. **上一轮诊断没有编译进 App。** 生成器和工程都没设置 `SWIFT_ACTIVE_COMPILATION_CONDITIONS`；Debug / `-Onone` 不等于定义 `DEBUG`。上一轮编译命令没有 `-D DEBUG`，因此只有始终编译的 `sameBitmap` 日志。本轮仅给 project Debug 配置增加 `$(inherited) DEBUG`，同步生成器，保留真机签名与 bundle 配置，未重跑生成器覆盖用户工程设置。
2. 旧诊断只在 `willShow` 能取得 transition coordinator 的 `.from` 时建立记录。新诊断从真实 `open()` 建立弱引用记录，`willShow(root)` 按真实 root identity 识别，`didShow(root)` 从该记录直接打印 completion，不依赖 coordinator 在 `willShow` 可用。交互回调还在 hosting 的 willAppear / willDisappear 尝试注册，以覆盖 delegate 时 coordinator 尚不可用的情况。
3. **未指定尺寸被错误地替换为 0。** `RegisteredPortrait.sizeThatFits` 原用 `proposal.replacingUnspecifiedDimensions(by: .zero)`，会把例如 `(finite width, nil height)` 返回成 `(width, 0)`。现只有两维均为有限具体值才返回尺寸，其余返回 nil，让 SwiftUI 使用默认测量。显式 `(0,0)` 最小尺寸提案仍如实处理与记录，未把所有零提案改成虚构正数。[Apple 文档](https://developer.apple.com/documentation/swiftui/proposedviewsize/unspecified)区分 unspecified 与 zero，[UIViewRepresentable 文档](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/sizethatfits(_:uiview:context:))允许返回 nil 使用默认算法。

**这不能证明真机 1320x0 snapshot 正是由 sizeThatFits 造成。** 该系统消息没有提供对象 identity 或调用栈。1320px 的宽度可能属于较大的 hosting / ScrollView 合成区域；需要与同一时间的 `boundsPixels`、window rect 和对应 view identity 比对。

## 生产日志

仍使用 subsystem `top.aoe.rocom.prototype`、category `navigation`，统一前缀 `zoom`，每次进入带 `seq` 与 pet ID。启动应有 `zoom diagnostics enabled DEBUG=1`。

关键事件：`push-before`、`detail-didShow`、`pop-willShow-grid`、`interactive-change`、`pop-didShow-grid`。此外记录 source provider 和 alignment provider 每次读取，在拒绝零尺寸之前也记录候选几何；记录 UIImageView layoutSubviews / updateUIView / window 移动、hosting willLayout / didLayout / safeAreaChanged、SwiftUI Hero GeometryReader 输入和 sizeThatFits 提案。

各事件覆盖 Grid source UIImageView、Hero UIImageView、两端真实 superview 祖先链（包括 UIKit container）、SwiftUI 图片外围区域的透明 background probe、两端 hosting root、实际 UIScrollView。SwiftUI wrapper 可能没有独立 UIView，祖先链记录实际结构，区域 probe 仅观测布局，不成为 transition source。

每个相关 UIView 打印：bounds、frame、windowRect、intrinsicContentSize、hidden、alpha、superview 与 window 类型及地址、UIView/layer transform、safeArea、UIImageView contentMode 与 image.size、displayScale、boundsPixels、layer animation keys。ScrollView 额外打印 contentSize、contentOffset、contentInset、adjustedContentInset。

`bounds.height == 0` 或 `frame.height == 0` 会明确打印 `zoom ZERO_HEIGHT`；其后附当时完整几何链。`makeUIView` 时尚未入 hierarchy/window 的零尺寸是可能的正常预布局，需要看它是否在 alignment/source provider 或 pop 生命周期期间仍存在。UIImageView 没有被替换、source alpha/hidden 没有写入，诊断不生成 snapshot、不强制 layout、不改变转场时间。

## completion 对比

正常生产 `didShow(root)` 必须输出 `zoom ... pop completion`：

- `sourceWindow`：pop willShow 开始测量的 source window rect。
- `alignmentTargetDetail`：最后一次有效 Hero alignment rect，处于详情 VC 坐标；候选零 rect 在 provider 日志中保留，实际返回 nil 时这里为 unavailable。
- `alignmentTargetWindow`：UIKit 最后解析的 source/对齐上下文的 source window rect。
- `gridImageWindow`：完成后的真实 Grid UIImageView window rect。
- `sameSource`：与进入前真实 source 的对象 identity 比较，缺失 source 不报 true。
- `targetDelta`、`startDelta`：分别列出 center x/y、width、height 差值。不同坐标空间的 Hero rect 不直接减 Grid rect。

视图没有 window 时打印 unavailable，不伪造 rect 或把缺失值算成零差值。旧有 `sameBitmap` 日志保留。

## 字号与待定位点

`UICTContentSizeCategoryXXXL` 对应普通 `.extraExtraExtraLarge` / SwiftUI `.xxxLarge`，不属于辅助字号。日志同时记录 UIKit `isAccessibilityCategory` 与 SwiftUI 实际 DynamicTypeSize / `isAccessibilitySize`。正文继续动态字体；没有强制固定字号。

Hero 仍使用现有 `max(0, min(320, width - 48, height * fraction))`，普通字号 fraction=0.44，辅助字号=0.26。输入 height 临时为 0 时 side 数学上会变成 0；本轮只记录其 GeometryReader size、safeArea、side 与字体分类，没有未经实测改变公式或加最小高度。需要确认首次零高度发生在 hosting 更新、safeArea 更新、ScrollView viewport、Hero 区域还是仅 sizing probe，才能继续修真正来源。

## 本轮验证边界

仅一次快速无签名 Debug device build：

```sh
DEVELOPER_DIR=/Applications/Xcode_27.app/Contents/Developer xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/ios27-p0/device-final CODE_SIGNING_ALLOWED=NO build
```

**该次 build 失败（exit 65）**，错误均为 Debug 日志使用旧 `NSStringFromCGRect/CGSize/CGPoint` API；编译器提示使用 `NSCoder.string(for:)`。已全部修正为提示的 Swift API，无旧 API 残留。遵守一次 build 上限，修正后没有再编译，因此最终源码编译状态待验证。该次实际编译命令已确认有 `-D DEBUG` / `-DDEBUG`，说明新 Debug 条件生效。

日志 `/tmp/rocom-zero-height-debug-build.log`；`git diff --check` 通过。未运行 UI Test、host test、accessibility audit、完整回归、真机安装或模拟器往返。没有新增实测零高度对象、三阶段 rect 或已关闭晃动的结论。
