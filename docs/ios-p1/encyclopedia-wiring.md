# P1 真实图鉴接线

2026-10-02。App 已从 29 条 P0 样本切换至 schema v2 ContentStore；本轮不改 RocoContent、canonical/schema/素材包、Web 上游或 frozen 转场实现。用户真机负责滚动、快速切宠、interactive pop、缺图和 Dark Mode 验收；未跑完整 UI Test。

## App 与资源

`RocoApp.swift` 的 App-owned `@State AppContent` 持有唯一 loading/ready/failed 状态。第一次 `.task` 调用既有 `ContentStore.loadInBackground(bundleURL:appBuild:)`，MainActor 的 started guard 防止多窗口或 SwiftUI 重进重复加载。成功后共享同一快照和同一 PortraitStore，交给 AlignedNavigation；失败显示真实错误，无 prototype fallback。Feature 没有 JSONDecoder、文件读取或内容初始化。

Xcode 工程新增 RocoContent 本地 package/product，并复制 `build/ios-content/store/ContentResources.bundle`。全部 canonical/素材文件在实际构建的 App Bundle 中按原 manifest 逐文件检查 hash/bytes。原 PrototypeContent 的 build/file reference 已移除，实际 App 内无 PrototypeContent；27张 PNG、29条样本及 PrototypeTools/RocoCore Prototype DTO 仅保留历史材料，不再参与 App 路径。App 的 --swiftui-zoom / --swiftui-cross-fade 分支及纯 SwiftUI PetGrid 已停用/移除，没有新增实验入口。

准备资源后可直接在 Xcode Run，现有个人 bundle identifier `com.batzz.rocom` 与 DEVELOPMENT_TEAM 均保留，未修改签名配置：

```sh
python3 scripts/ios-store/prepare-bundle.py
# 然后打开 ios/RocoNative.xcodeproj，选择 RocoNative / iOS 27 真机
```

此步只复制已验收的 frozen 包，不运行 canonical regeneration。缺少 build 产物的新 checkout 需先恢复/生成经过验收的 canonical 与 assets 包。不要用旧 `PrototypeTools/create-project.py` 重建当前 P1 工程；它属于历史 P0 工具，会恢复旧资源/工程配置。

## Grid、Detail、图片

- Grid 使用 `content.orderedPets`，实际721条，无额外筛选/折叠；canonical ordinal 决定顺序，ForEach 使用 PetID，首条16000004。保留现有 adaptive LazyVGrid、透明图片和卡片构图；没有搜索/筛选器或整体改版。
- Detail 直接使用 canonical Pet、type ID → nameZh、BaseStats 六项、PetDetail.traitId → Trait 的名称/描述；保留已有 form 和真实 handbook/config 编号。没有增加新的数据模型或填造未提供信息。
- Hero 原布局仍是 GeometryReader 内 ScrollView/VStack 第一项；没有 overlay/safeArea 固定 Hero。
- PortraitStore 的初始化不解码图片。只有 LazyVGrid 的 PetGridCell body 请求当前可见/附近图片；没有721个 UIImage 数组或721份持久 @State bitmap。
- 路径为 canonical portraitAssetId → AssetResolver validated Bundle WebP URL → 原有 ImageIO thumbnail decode（最长边512）→ UIImage → 16 MiB NSCache。缓存 key 改为 AssetID，同源不同配置可复用；不批量处理源图、不改 WebP、不增加磁盘 cache。缓存预算不等于 App 内存上限，挂载中的 UIImageView 和 Detail 还会持有 bitmap。
- 解码机制继续在主线程按需执行，与原 P0 一致；此轮没有引入第二套异步图片状态/调度器。快速首次滚动时的解码帧预算需用户真机检查，不能由 focused check 推断流畅度。
- `.missing` 只接受 AssetResolver 已验证的3784/3785，懒创建一个透明512px、scale=1、systemGray photo 符号 UIImage，两个宠物复用。Detail 同时显示“暂无精灵图片”。没有假 WebP。
- unknown asset、decode 失败明确 throw，并在 Grid 显示“图片加载失败”和原因，禁用该 cell 进入；不会转成 known-missing placeholder。启动时包完整性错误仍由 ContentStore 失败页展示。

## 转场边界

AlignedNavigation 只更新输入类型/ContentStore 注入与 PetDetail 构造。点击从已注册 source UIImageView 取其同一个 UIImage，Detail 强持有；不会点击时再次向缓存请求/解码。无可用 source 时不启动缺少图片来源的导航。

`PortraitSurface.swift` 逐字节保持原样，弱 source/Hero 注册方式未改。alignmentRectProvider、preferredTransition source provider、interactive pop、didShow 清理、Reduce Motion、图片84% fit 构图均保持。没有第二份导航状态、新 animator、delay/crossfade 或末段 handoff polish。

## 必要验证

- iOS 27 Simulator generic build 通过。
- generic iOS device unsigned build 通过；未声称真机已安装/性能通过。
- 仅运行2项 host focused check，通过：
  - `testRealContentLazyPortraitsAndKnownMissing`：721/稳定顺序；PortraitStore 初始化 decode=0；重复真实图片同 UIImage/cache 命中；3784/3785 同一 placeholder、没有 WebP decode。
  - `testRealContentSourceAndHeroShareBitmap`：真实首屏 initialDecoded=5，未解码全部目录；source/Detail/Hero 三端 UIImage identity 相同。日志 sameBitmap=true；程序化 pop sameSource=true，center/width/height delta=0。不是 interactive pop 或视觉矩阵验收。
- 实际 App 内 canonical 的17个实体文件，以及素材清单的1467个受管文件均匹配 frozen manifest；两个 manifest 原字节一致，无 PrototypeContent 资源。
- 普通启动已在 iOS 27 Simulator 实际显示真实 Grid；首屏截图为 `build/ios-content/wiring-evidence/real-grid.png`，保持透明头像/卡片构图。
- 首次 focused 编译出现 RocoContent.PetDetail 与 App PetDetail 名称歧义，已在 host tests 显式限定 RocoNative.PetDetail 并重跑通过；没有修改 domain schema。Detail 的 trailing closure warning 已修正。
- 设备 build 保留既有 iPad interface orientation 配置提示；无 AppIntents 依赖的 metadata extraction 提示保留。没有更改 iPad/转屏范围。

命令（日志与 xcresult 位于 ignored `build/ios-content/wiring-evidence/`）：

```sh
DEVELOPER_DIR=/Applications/Xcode_27.app/Contents/Developer xcodebuild \
  -project ios/RocoNative.xcodeproj -scheme RocoNative \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios-content/wiring-device CODE_SIGNING_ALLOWED=NO build

DEVELOPER_DIR=/Applications/Xcode_27.app/Contents/Developer xcodebuild \
  -project ios/RocoNative.xcodeproj -scheme RocoNative \
  -destination 'platform=iOS Simulator,id=25EE507E-F0E7-4FB8-8484-0D7D216800DA' \
  -derivedDataPath build/ios-content/wiring-simulator \
  -only-testing:RocoNativeHostTests/NavigationLifetimeTests/testRealContentLazyPortraitsAndKnownMissing \
  -only-testing:RocoNativeHostTests/NavigationLifetimeTests/testRealContentSourceAndHeroShareBitmap \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test
```

真机重点：首次 loading→首屏；快速上下滚动是否串图/掉帧；不同配置/共用头像连续 zoom/pop；详情滚动后 Hero 可见/离屏时返回；3784/3785 placeholder 的进入/返回；Dark Mode。canonical 顺序不是按 PetID，缺图两个宠物在对应名称位置。末段轻微 handoff 仍留 P3。

## P1 Encyclopedia stabilization：真机阻断（2026-10-02）

真实图鉴接线后用户真机稳定复现：1）仅名字可点，头像/留白不能进入；2）push 开始时 navigation bar blur/hairline 上移至大标题中间，pop 后仍异常，下一次触摸才恢复。第二项是独立的导航栏状态/布局阻断，不能归到 P3 portrait handoff polish。两项关闭前不进入下一功能。

本轮只做小范围修复和快速 build，不运行 UI Test；真机是否关闭仍由复测决定。

### Bug 1：整块 cell hit testing

代码根因：plain Button 的 label 只有实际绘制内容，未给完整 VStack 设置 interaction contentShape；头像是透明 UIViewRepresentable/UIImageView，布局矩形与 SwiftUI 默认命中区域不等价。此前点击文字可进入不能证明头像/留白可点。

修复位于 `PetGrid.swift:PetGridCell`：在 Button **label 内部**展开完整列宽，设置 `.contentShape(.interaction, Rectangle())`；头像 `.allowsHitTesting(false)`，由唯一的外层 Button 接受输入。覆盖头像透明区域、名字、编号和 cell 内留白；不包含两个 cell 之间的网格间隔。没有第二个 tap gesture/导航入口。头像仍通过原 RegisteredPortrait 注册真实 UIImageView；cell 不是 zoom source。

### Bug 2：导航栏跟踪与标题状态

代码诊断确认两个结构性风险：

1. UIKit bridge 用 root `.always` / detail `.never` 管理大/小标题；Detail 又通过 SwiftUI `.navigationTitle` / `.navigationBarTitleDisplayMode(.inline)` 修改相同 navigation item。导航标题存在两套写入来源，push/pop 的 preferences 与 UIKit 生命周期收尾不同步时容易留下旧状态。
2. 两个 plain UIHostingController 没有明确关联 content ScrollView，依赖 UIKit 搜索 SwiftUI 内部视图层级。Grid 带 background，Detail 又有 GeometryReader；不能将视图存在等同于已被 navigation bar 正确跟踪。当前 SDK 的 UIViewController.h 明确说明：contentScrollView 用于观察 bar blur 和自动 inset 调整，nil 时使用子视图搜索 heuristic。

本轮处理：使用仍继承 UIHostingController 的 `NavigationContentHost`，在 `viewDidLayoutSubviews` 中发现真正的 content UIScrollView 时调用公开 `setContentScrollView(_:for: .top)`，每个 scroll 实例只绑定一次；没有外部强制刷新、延时或手动更新滚动位置。删除 Detail 的两个 SwiftUI title modifier，保持已有 UIKit title/largeTitleDisplayMode 为唯一管理来源。UIHostingController、UINavigationController、preferredTransition 和系统 interactive pop 架构仍原样。

没有设置 standardAppearance/scrollEdgeAppearance，没有改变 bar 背景视觉策略；没有写入 contentOffset、contentInset、additionalSafeAreaInsets，没有 safeAreaInset/toolbarBackground 修改。也没有隐藏/重建 navigation bar、DispatchQueue.main.async、async delay、点击强刷或动画掩盖。

**证据边界**：尚未获得真机错误瞬间的旧版 view/frame/scroll trace，因此不能把上述结构风险说成已实测证明的唯一直接根因，也不能宣称真机已关闭。普通触摸会引入后续 scroll interaction/layout/preferences 更新，符合旧状态在下一次更新才纠正的表现；这目前是解释该现象的推断，不是已采样确认的事件链。若修复后仍错，必须用下面日志继续定位，不能改记为 P3 polish 或带到下一功能。

DEBUG category `navigation-bar` / 文本 `nav-bar` 增加只读测量：beforePush、willShow/detail、didShow/detail、willShow/grid、didShow/grid；自然 layout 的测量发生变化时记录 layoutChanged。含：

- contentOffset/contentInset/adjustedContentInset、UIScrollView safeArea/frame/bounds/tracking/dragging。
- 实际 content ScrollView 是否等于 controller.contentScrollView(for: .top)。
- navigation bar frame/bounds、controller safeArea。
- background/effect/hairline 的 frame、转换到 bar 坐标的 rect、hidden/alpha。
- bar 和 navigation item 的 standard/scrollEdge appearance 描述、prefersLargeTitles、controller/top item title mode。

只通过公共 UIView 层级读取框架背景/分界线；内部 class 名仅作为日志标签，不调用私有 selector，不按私有类做修复判断。Debug 日志不修改 layout/scroll/nav state；Release 不包含诊断。

### 本轮 verification / 真机复测

- Xcode 27 / Swift 6.4，generic iOS 无签名快速 build **通过**；日志 `build/ios-content/stabilization-evidence/build-final.log`。仅保留未依赖 AppIntents 的 metadata 提示。未运行任何 UI/host 测试或完整测试矩阵。
- 快速编译中曾因 UIEdgeInsets 没有 description 属性而失败，日志表达改用 String(describing:) 后编译通过。
- alignmentRectProvider 和 zoom source provider 比较保持原样；PortraitSurface/弱 source-Hero 注册文件逐字节未改。ContentStore、schema v2 和两份 manifest 未改。P3 portrait handoff 晃动不在本轮修复。
- 真机：分别点同一 cell 的头像中心、头像透明角落、名字、编号和 cell 内空白，均应进入同一详情；source 仍是图片。检查两个 known missing placeholder 同样可点。
- 从顶部 push/pop 后**先不要再点屏幕**，观察大标题背景/分界线是否已经正常；再从 Grid 中部和滚动过的 Detail 做返回、短距离 interactive pop 取消、连续切宠，确认状态不依赖补一次触摸。
- 若仍错，Xcode Console 过滤 `nav-bar`，保留一次完整 beforePush → willShow/detail → didShow/detail → willShow/grid → didShow/grid，以及“保持错位”和“再触摸后”的 layoutChanged 日志。两项等待这次真机复测；不进入下一功能。
