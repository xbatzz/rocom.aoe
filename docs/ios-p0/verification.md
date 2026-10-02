# P0 实施与验证记录

**当前状态（2026-10-02）：P0 architecture accepted / frozen。** 用户接受 shared zoom 技术路线，保留 UIKit bridge，允许在另一个任务开始 P1。本轮只做 P0 收尾。最新冻结范围、真机证据与剩余 known issues 见本文末节；以下旧测试结果和停止点属于历史记录，不代表当前仍禁止进入 P1，也不代表所有历史失败都已修复。

> 仓库卫生整理：Markdown、契约 schema 和 3 张精选视觉证据保留版本管理。批量截图、录屏和自动报告迁移到已忽略的 `build/ios27-p0/docs-evidence/`，下文指向该目录的相对链接仅在保留本机证据的工作区可用，不随 Git 克隆提供。历史命令和既有测试结论保持原样；本次未运行测试。

日期：2026-10-02，Asia/Shanghai。源码基线/实际 HEAD：`a1b39c7ea22ccf5b8d35f5e73bb70f7fe47dc428`。开始时 `git status --short` 只有 `?? docs/ios-native-plan.md`，没有已有原生工程。未修改 Web 业务或基础游戏数据，未执行 sync。初次交付最小原型和冻结契约时，P0 验收尚有缺项并暂停 P1；当前架构接受与例外处理以末节冻结决定为准。

**现行产品基线**：仅支持iOS27。已独立核对正式Xcode27.0/27A266a、Swift6.4、SDK27.0与runtime27.0/24A434；App、UI/host tests、本地Package和生成器deployment统一27.0。iOS18 runtime验收已删除，18–26无兼容范围/availability fallback。27 自动回归与 26.2/18.0 结果保留为历史证据；最新真机结论来自用户复现反馈，见冻结节，不冒充本机重新运行了真机矩阵。

## 历史工具链与工程（26.2）

实测 Xcode 26.2 / 17C52，Swift 6.2.3，iphoneos/iphonesimulator SDK 26.2；deployment target=18.0，Swift language mode=6.0。App 开启 MainActor 默认隔离与 Approachable Concurrency，纯 Domain 不默认隔离；XCTest target 保持非隔离，测试方法显式 MainActor。

`ios/RocoNative.xcodeproj` + 共享 `RocoNative` scheme；一个 App、一个 UI test target、一个 app-hosted integration test target、一个本地 RocoCore Package/RocoDomain target。bundle ID `top.aoe.rocom.prototype` 为内部临时标识，无 DEVELOPMENT_TEAM。旧iOS设备目标无签名编译通过不等于已在设备安装。旧deployment18编译结果保留，旧OS运行要求已撤销；27工具链及Simulator验证已完成，见末节；真机仍待验证。

## 实际文件

- 工程：`ios/RocoNative.xcodeproj/project.pbxproj`、共享 scheme、`ios/README.md`。
- App：`RocoApp.swift`；`PetGrid.swift` 为纯 SwiftUI 对照；`AlignedNavigation.swift` 为采用的最小系统导航桥；`PetDetail.swift` 为最小详情。
- 图片：`PortraitStore.swift` 有限 ImageIO/NSCache；`PortraitSurface.swift` 注册 weak 来源/目标视图、相同比例的 fit 构图。
- Core：`Package.swift`、`IDs.swift`、`PrototypePet.swift`、`ContractTests.swift`。
- UI tests：`NavigationTests.swift`、仅测试 runner 使用的 `TouchDriver.h/.m`；app-hosted tests：`HostTests/NavigationLifetimeTests.swift`。
- 原型准备：`ios/PrototypeTools/{prepare-sample.mjs,create-project.py,freeze-contract.py,freeze-fixtures.mjs}`。不是 P1 exporter。
- 资源：`Resources/PrototypeContent/pets.json` + 27 张真实透明 PNG；29 配置，包括同 species 的多形态与两张缺图。
- 契约和证据：`docs/ios-p0/{content.schema.json,contracts.md,verification.md}`；自动报告和批量 PNG/MP4 已迁移到 `build/ios27-p0/docs-evidence/`；`shared/fixtures/ios/p0.json` 有 42 个匿名样例。
- `.gitignore` 增加原生构建/内容产物、本地 Xcode 状态忽略；交接文档第15节更新。

## 共享转场取舍

1. 首先实现 NavigationStack + 持续 namespace + `matchedTransitionSource(PetID + origin)` + `navigationTransition(.zoom)`，来源仅图片容器。没有移植 Web 动画。
2. 原始构图逐帧存在双影，见 `../../build/ios27-p0/docs-evidence/swiftui-zoom-frames.png`。继续调整方形 source、相同 84% 图片占比、固定 Hero 构图；仍存在 source snapshot 与 destination Hero 的垂直分离，见 `../../build/ios27-p0/docs-evidence/swiftui-adjusted-frames.png`。整个 destination 的缩放不能直接代替图片共享几何。
3. 采用最小 UIKit bridge：系统 UINavigationController + SwiftUI UIHostingController；`preferredTransition = .zoom(options:sourceViewProvider:)`，最终 source provider 返回来源 UIImageView、`alignmentRectProvider` 返回 Hero UIImageView 在 destination view 中的矩形。UIKit 系统执行时序、物理曲线、返回/取消，不实现 animator、手势识别器或自制导航。
4. source/hero 都是同一种 PortraitSurface、相同 aspect-fit 与 8% 比例留白。点击直接从来源 surface 取得其**同一 UIImage 实例**，详情持有它，缓存淘汰也不能换图；缺图亦同。来源按 PetID+入口实例即时解析，弱引用不留住回收 cell。Grid 不重排，原根 hosting controller 留在系统导航栈中；返回仍命中原实例和滚动位置。
5. 当前 Hero 是 ScrollView 内 VStack 的第一项，随正文一起滚动；其真实 UIImageView 仍注册为 destination，alignment rect 来自滚动区域中的真实位置。早期 safeAreaInset 固定 Hero 的方案已修正，见[修正记录](hero-scroll-pop-fix.md)。以后全量详情若改变头图生命周期，必须重新验收。
6. 两条实验路径互斥：默认 aligned bridge；启动参数 `--swiftui-zoom` 用纯 SwiftUI 对照。没有叠加 matchedGeometryEffect/overlay，已有系统对齐方法能解决已观察问题，未再添加自定义动画。
7. Reduce Motion：UIKit 读真实 `UIAccessibility.isReduceMotionEnabled` 时不配置 zoom，进入静态；返回仍是系统导航行为。纯 SwiftUI 对照读 `accessibilityReduceMotion`。同时保留 `--reduce-motion` 测试覆盖开关。

对照 API：[Apple zoom options](https://developer.apple.com/documentation/uikit/uiviewcontroller/transition/zoomoptions)、[Apple zoom provider](https://developer.apple.com/documentation/uikit/uiviewcontroller/transition/zoom(options:sourceviewprovider:))。本地 SDK `UIZoomTransitionOptions.h` 也确认 alignmentRectProvider 自 iOS18 可用。

**视觉结论**：在本次查看的 iOS26.2 模拟器正常往返、短距离取消和真实头像场景，精灵图片从来源连续移动/放大接到 Hero，返回缩回来源，没有观察到原 SwiftUI 方案的分离双影。`../../build/ios27-p0/docs-evidence/final-aligned-frames.png` 为最终构图逐帧证据；不能由这些场景推断所有设备/全部矩阵通过。

原始录屏保留在 `build/ios-p0/evidence/{aligned-inspection.mov,final-light.mov,real-image-repeat.mov}`。simctl MOV 在长静帧后出现 ffmpeg PTS 重排，诊断 contact sheet 使用解码帧序号选取。`../../build/ios27-p0/docs-evidence/aligned-zoom.mp4` 是按连续帧重新排到60fps的**诊断片段**，用于判断图像位置，不作为真实时长/帧率指标。原始 MOV 与 xcresult 为本机可重查证据；无 Instruments FPS 结论。

## 已实际执行的命令和结果

```sh
xcode-select -p
xcodebuild -version
swift --version
xcodebuild -showsdks
xcrun simctl list devices available
node ios/PrototypeTools/prepare-sample.mjs
python3 ios/PrototypeTools/create-project.py
python3 ios/PrototypeTools/freeze-contract.py
node ios/PrototypeTools/freeze-fixtures.mjs
node ios/PrototypeTools/freeze-fixtures.mjs --check
swift test --package-path ios/Packages/RocoCore
xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios-p0 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -destination 'generic/platform=iOS' -derivedDataPath build/ios-p0/device CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -destination 'platform=iOS Simulator,id=D9E807F9-D102-47BB-9586-77BB93F5DCE0' -derivedDataPath build/ios-p0 -resultBundlePath build/ios-p0/final-ui2.xcresult test
```

Simulator generic build 与 device build 均通过；最终设备构建日志 `/tmp/rocom-p0-device-final.log`。无签名，不代表发布准备完成。编译只出现无 AppIntents 依赖的 metadata extraction 提示。Swift Testing 4 项通过（ID 编解码/非法ID、同 species 与实例来源、真实样本/占位、fixture provenance）；42 样例固定输出检查通过。没有实现 Swift PVP 公式/备份迁移器，因此没有宣称这些引擎已通过 Swift 等价测试。

UI 结果分批：

| xcresult（`build/ios-p0/`） | 实际结果 |
|---|---|
| `swiftui-test3.xcresult` | 原始 SwiftUI 顶/中/底+30往返，1测试通过；视觉双影仍失败，测试可点通不等于动画达标 |
| `aligned-inspection.xcresult` | 早期 bridge 进入/返回、短取消，2测试通过 |
| `final-ui2.xcresult` | 最终固定头图布局6项测试通过，214.19秒 |
| `dark-ui.xcresult` | 深色进入/返回、短取消，2项通过 |
| `system-motion.xcresult` | 真实系统 Reduce Motion=YES 的进入/返回，1项通过 |
| `real-image-repeat.xcresult` | 顶部3001、中部3015、底部3785及真实图片3585的30次往返，1项通过，168.92秒 |
| `missing-final.xcresult` | 两个真实缺图3784/3785与短取消，2项通过；占位已固定512px |
| `pinned-bitmap-final.xcresult` | 最后同 bitmap 持有调整后的进入/返回与短取消，2项回归 |

实际后续分批测试使用同一个 xcodebuild 命令，加 `-only-testing:RocoNativeUITests/NavigationTests/<方法>`；方法名与结果在工程测试源/xcresult 中。Dark 使用 `xcrun simctl ui <UUID> appearance dark`，随后恢复 light。系统 Reduce Motion 验证通过 `simctl spawn <UUID> defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES` 设置，测试无强制 launch 参数；运行日志实测 `systemReduceMotion=true`，结束恢复 NO。系统导航 delegate 的运行日志实测 `interactive cancelled=true`，排除了“手势没启动所以详情还在”的假通过。

```sh
yarn type-check
yarn build
node scripts/test-pet-data-quality.mjs
node scripts/test-skill-acquisition-index.mjs
node scripts/test-shiny-collection.mjs
node scripts/test-handbook-progress.mjs
node scripts/test-badge-trial-data.mjs
```

前六条通过；Web build 保留既有 OpenCV externalization 和 chunk 体积警告。徽章测试仍因 3784/3785 和 species:467 头像缺失失败，与基线一致；未隐藏失败、未修造上游数据。开发中发现过工程生成器空列表语法、XCTest actor 默认隔离与原型初始路由图片状态问题，已修复后重新构建/运行；失败日志仍在 `/tmp/rocom-p0-*.log`，不能将最初失败当成最后结果。

## 包体、解码与 fixtures

样本27张 PNG=4,106,199字节（3.92MiB），真实图片理论 RGBA=28,311,552字节（27MiB），加两个512px占位约2MiB。缓存 costLimit=16MiB，视图和正在导航的 bitmap 另有持有，**costLimit 不等于 App 内存上限**。占位明确设置 renderer scale=1/standard，避免默认3倍屏幕倍率产生1536px位图。

公开已实装唯一头像源 WebP=41,416,106字节（39.50MiB）；不是全量发布 PNG 大小。初始 Debug simulator App 目录 `du -sk` 4860KiB；不是签名 IPA、压缩传输、设备安装规模。图片样本都保留 alpha、最大512px且不放大。完整8项内容≤60MiB预算尚待P1资源闭包测量，P0没有 SQLite/全量包。

`../../build/ios27-p0/docs-evidence/runtime-report.json` 记录模拟器 ImageIO 解码初测，样本中位约2ms、p95约6.2ms；混合多次启动/滚动及原型迭代，仅用于初步判断，不是最终性能基准。尝试 vmmap 未能读取 task DYLD 信息，**驻留/峰值内存未得到可靠结果**，不报告虚假的内存通过。

42 fixtures 以当前实际 TS 可导出模块为主，固定 clock；D1–D4、旧足迹映射和原生 unresolved 保留策略标明人工规格。真实32位/全角搜索、全部伤害矩阵和原生事务迁移执行均留给相应阶段，P0不批量实现业务。

## 验证范围与未关闭门槛

| 场景 | 状态 |
|---|---|
| 顶部/中部/底部、点入再返回、返回位置 | iPhone17Pro/iOS26.2模拟器通过，cell位置偏差≤2pt |
| 真实图片连续30次进入退出 | 3585月亮砣通过，另有缺图30次早期回归 |
| 首次 App launch 的图片解码、随后缓存图 | 已运行，导航持有来源同 bitmap；不是磁盘冷缓存性能基准 |
| 3784/3785缺图占位 | 进入/返回通过；无假造图片 |
| 20%左右短距离交互返回取消 | 已运行，系统日志确认实际取消；画面/下一次进入恢复 |
| 50%/80%拖拽后反向取消 | **模拟器已关闭**：连续单触点推进、停留、反向再抬起，真实 UIKit cancelled=true；来源/Hero恢复，正常返回、同宠/另一宠重入通过。见续验记录 |
| 详情资料滚动后返回 | 固定Hero原型通过 |
| Dark Mode、系统 Reduce Motion | 已验证；Reduce Motion系统实际开关与强制测试两条路径均运行 |
| iOS27 SDK/Simulator/目标iPhone运行 | SDK/Simulator迁移与实际回归见末节；目标真机未连接、未验证。iOS18要求已删除 |
| 默认/最大辅助字体、44pt、可访问性审计 | 两种真实系统字号已运行；默认全套审计通过。深色+最大字号滚动审计失败，**accessibility仍部分未关闭**；见续验记录 |
| VoiceOver 遍历及焦点回到来源 | **未关闭**：本机 Simulator Settings 没有 VoiceOver 入口，SDK26.2 XCTest没有可用 VoiceOver 控制服务；审计不能替代实际 VoiceOver 测试 |
| 动画期间立即触控返回 | **未关闭**：raw 0.15s 手势、0.08/0.15/0.30s Back 触控不能完成返回；程序化同步 pop 通过，不能替代该触控路径 |
| 旋转/iPad、后台/内存压力 | 未完整验证；不得以单一模拟器推断通过 |
| 搜索键盘、单条筛选、切Tab、数据更新排队、技能/配队来源、深链接 | P0未实现这些业务，不把不存在的交互算通过；未来相应阶段复用转场矩阵 |
| 真机60Hz/ProMotion、Instruments帧预算/峰值内存、真实触控手感与清晰度 | 全部未验证；尚未配置签名并在设备安装 |

开始P1前仍需：关闭立即真实触控返回与最大辅助字体滚动审计；实际VoiceOver遍历/焦点仍需可用环境/真机验证。本轮正式27工具链/runtime、deployment迁移与Simulator重测已执行，不再是等待升级项。缺图使用明确占位并继续追踪；个人真机签名/安装、60Hz/ProMotion、Instruments/峰值内存、全量内容包预算继续待验收。PVP修正规格已冻结，业务引擎/全量导出仍属于后续阶段。

本次停止于 P0。没有开始 P1，没有全量 exporter、SQLite、四Tab架构、用户持久化或八项功能批量实现。

## P0 续验：极端路径与稳定性（2026-10-02）

本节更新同日首轮记录。HEAD 仍为上述基线；既有 P0 文件仍未提交，继续在同一 checkout 工作。未修改 Web 功能/上游数据，未重新生成内容或 fixtures。最终测试状态不代表 P0 全部关闭。

### 实际修正与工程边界

- 大幅返回拖动暴露旧 wrapper source 的重复头像：移动中的 Hero 和 Grid 中来源图片同时可见。根因修正是 `sourceViewProvider` 返回 `PortraitSurface.transitionImageView`，`alignmentRectProvider` 返回 Hero 内 UIImageView 的对应矩形。系统现在识别图片并管理拖动中的来源可见性；取消后原图自动恢复。没有手工隐藏/延迟恢复，没有 overlay、第二套 animator、禁用手势或交互屏蔽。
- 根页完成显示时，以 UIKit **实际 stack=1 且 top===didShow 参数**为条件清掉弱 Hero 注册，防止上一次已离开页面的 surface 被后续路线解析。取消仍显示 detail，不清 Hero。没有保存另一份 path/selectedPet 导航状态。
- Grid 的 SwiftUI 内容从 bridge 移到 `PetGrid.swift`；bridge 只配置系统 UINavigationController、hosting controller、zoom 和局部 weak 来源注册。UIKit 生命周期/UIImage 未进入 RocoDomain。Coordinator 由根页 action 局部持有，反向 nav 为 weak；图片表是 NSMapTable weak values，Hero 为 weak，无 singleton。
- app-hosted 测试实际触发 PortraitStore 隐式 isolated deinit 的 task-local malloc 崩溃，与 [Swift #87316](https://github.com/swiftlang/swift/issues/87316) 的工具链问题吻合；纯缓存/weak registry 增加空 `nonisolated deinit`，没有跨线程访问 UI 的 teardown。修正后释放与重复中断测试通过；不把这个结果写成 Instruments 无泄漏结论。
- 修复默认文字对比度，Grid 名字允许换行；辅助字体时 Hero 按可用高度减小。固定 Hero 改用 ScrollView 顶部 `safeAreaInset`，默认字号滚动审计的间歇失败在最终整套回归未复现，但深色+最大字号仍有失败（见下）。默认图像比例、系统导航和已有共享视觉保留。

### 连续触控与立即返回的真实范围

公开 XCUICoordinate 不能表达同一触点的反向轨迹。本次添加仅在 UITest target 编译的 `TouchDriver.h/.m`，运行时探测 XCTest 内部 event record，接口用法参照 [WebDriverAgent 原始实现](https://github.com/appium/WebDriverAgent/blob/master/WebDriverAgentLib/Utilities/FBXCTestDaemonsProxy.m)。未安装 Appium、未链接私有 framework 到 App；App 仍只调用公开 UIKit。工具链升级需复核；接口不可用明确 skip，不算验收通过。回调从 XCTest XPC queue hop 到 MainActor，修复过测试 runner 的 isolation 崩溃；这不是 App 导航延迟。

50%/80% 测试为触点从 x=0.03W 推进到 0.53W/0.83W，停留后沿同一轨迹反向到 0.08W 再抬起；表示约50%/80%屏宽的**拖距**，不是声明 UIKit percentComplete 精确达到0.50/0.80。系统日志实际 `interactive cancelled=true`。随后正常返回、同宠再次进入、另一宠进入、来源位置≤2pt、hit testing 可用都验证。逐帧检查只有一张该精灵图片，来源槽在交互过程中由系统暂时隐藏图片，取消或完成后恢复，没有观察到双影、闪白或错 cell：

- [80% 反向取消逐帧](../../build/ios27-p0/docs-evidence/followup-80-cancel.png)：原始 MOV 解码帧304–396，每4帧取样。
- [50% 反向取消逐帧](../../build/ios27-p0/docs-evidence/followup-50-cancel.png)：原始 MOV 解码帧1112–1204，每4帧取样。
- [UIImageView 来源的进入逐帧](../../build/ios27-p0/docs-evidence/followup-imageview-open.png)：原始 MOV 解码帧156–212，每4帧取样，图片连续放大接到固定 Hero。
- 原始录屏 `build/ios-p0/evidence/p0-imageview-cancels.mov`；`p0-imageview-cancels.xcresult` 三项通过39.42秒。图片仅证明查看过的几何与恢复，不作帧率/峰值内存指标。

**立即触控返回未关闭。** 使用同一 event record 注入首次点击与返回，无 XCTest idle 等待夹在输入之间：系统 Back 完成页位置在0.08/0.15/0.30秒的 raw tap，以及0.15秒抓取尚在展开图片的 raw drag，均不能完成 pop。等待真实条件最多4秒仍留在详情，正常 Back 随后可返回、继续进入另一宠，未观察到永久 hit testing/导航栈损坏。完成页按钮位置可能与动画中可触位置不同；这些结果不足以归因为 App race 或 UIKit 缺陷，仍需人工按可见按钮/连续手势复核。没有凭“指令已经发出”宣布验收成功。

保留两项严格 `XCTExpectFailure` 的已知失败诊断，仅匹配对应立即触控失败描述，其他断言仍正常失败；意外修复会触发 unexpected pass，需重新验收后移除标记。`p0-immediate-settling.xcresult` 原始两项失败保留。程序化在同一 MainActor turn push 后立即 pop、10轮交替同宠/另一宠的真实 UIKit 测试通过，但**不能替代真实触控关闭该门槛**。6轮无显式 sleep 的顺序 XCUITest 也通过，但 XCTest 会等待 idle，不声称覆盖动画重叠。

### 可访问性与最低系统

默认 `large` 与 `accessibility-extra-extra-extra-large` 使用真实 Simulator 系统字体设置。Grid、详情顶部、滚动后与底部执行全部 `performAccessibilityAudit`，无 issue 过滤；Grid cell/原生 Back ≥44pt，关键文字层级与 stats 合并语义。装饰 Hero 不重复朗读，关键操作仍可在 AX tree 查到并点击。最大辅助字体截图实际查看没有横向截断，资料可继续滚动；不宣称所有 iPad/旋转布局通过。

最终深色+最大字号补充回归 `p0-final-dark-max-type.xcresult`：Grid/详情顶部审计通过，但滚动后和底部两项 Contrast failed。节点为“物攻”，报告frame=(24,730.09,100.33,63.33)，实际截图显示该行已滚出屏幕，当前可见为魔防/速度/特性。浅色+最大字号 `p0-final-light-max-type.xcresult` 也复现生命/物攻/魔攻/数值节点的同类失败。可能为AX frame与可视区域不一致，**尚不能归因为审计误报或声明已修复**；不忽略/过滤issue。两项立即触控诊断仍为expected failure，恢复断言通过。见[深色统计](../../build/ios27-p0/docs-evidence/followup-dark-max-test-summary.json)、[浅色统计](../../build/ios27-p0/docs-evidence/followup-light-max-test-summary.json)、[Grid](../../build/ios27-p0/docs-evidence/followup-dark-max-grid.png)、[顶部详情](../../build/ios27-p0/docs-evidence/followup-dark-max-detail.png)、[滚动失败截图](../../build/ios27-p0/docs-evidence/followup-dark-max-scrolled.png)。

还做了仅用于诊断的全 primary 色试验 `p0-max-primary-probe.xcresult`，两项仍失败、5个contrast issues，颜色强化没有解决，已撤回该试验。既有最高对比数值节点也报告失败；没有添加延迟/强制AX刷新或隐藏offscreen节点来压掉审计。后续需对照审计自动滚动过程与实际AX frame，定位safeAreaInset/系统zoom后的可见范围，避免未经证实归咎系统。

**accessibility 仅部分关闭**：上述最大字号滚动审计失败仍需定位；真实 VoiceOver 朗读遍历、返回后的焦点与手势陷阱仍未验证。Simulator Settings 的 Accessibility 列表没有 VoiceOver 入口；已核对 SDK26.2 `XCUIDevice.h` 无可调用 VoiceOver 服务，运行日志为 voiceOver=false。审计与 AX tree 可操作不是实际 VoiceOver 会话，不代替该验收。后续需可用 VoiceOver 环境/真机确认。

历史续验时只有iOS26.2(23C54) runtime，工程各target deployment18.0，已检查旧SDK API availability。**用户现已撤销iOS18 runtime验收和18–26兼容范围**；不再要求安装或补测旧runtime。工程原配置保留到正式27工具链到位后再改，27实际运行目前未验证，见末节。

### 最终回归

最终结果如下；命令可复现，原始 xcresult/日志留在本机。所有正式修正后重新运行，颜色诊断试验已撤回，未执行 `yarn sync:pet-data`。

```sh
swift test --package-path ios/Packages/RocoCore
node ios/PrototypeTools/freeze-fixtures.mjs --check
xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -destination 'generic/platform=iOS' -derivedDataPath build/ios-p0/device-final CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios-p0/simulator-final2 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -destination 'platform=iOS Simulator,id=D9E807F9-D102-47BB-9586-77BB93F5DCE0' -derivedDataPath build/ios-p0 -resultBundlePath build/ios-p0/p0-followup-final.xcresult test
yarn type-check
yarn build
node scripts/test-pet-data-quality.mjs
node scripts/test-skill-acquisition-index.mjs
node scripts/test-shiny-collection.mjs
node scripts/test-handbook-progress.mjs
node scripts/test-badge-trial-data.mjs
```

Core 4项通过、42 fixtures freeze check通过；无签名 device build通过。Web type-check通过5.53秒，build通过14.46秒（Vite11.51秒），仍有既有警告。四项数据测试通过；徽章测试仍因3784/3785、species467头像缺失失败，未改变上游数据或忽略检查。日志 `/tmp/rocom-p0-regression-{core,fixtures,web-types,web-build}.log` 和 `/tmp/rocom-p0-followup-device-final.log`。

| 最终 xcresult / 命令 | 实际结果及限制 |
|---|---|
| `p0-followup-final.xcresult`，默认浅色large完整scheme | **19项：17 passed、2 expected failures、0 unexpected/skip**。[xcresult原始统计](../../build/ios27-p0/docs-evidence/followup-test-summary.json)。16 UI + 3 host，UI390.38秒、host30.67秒；expected两项就是未关闭立即触控路径，不能算验收成功 |
| `p0-final-dark-default.xcresult` | 深色large的Grid/详情审计、底部审计、50%/80%取消，4项通过58.10秒；[原始统计](../../build/ios27-p0/docs-evidence/followup-dark-test-summary.json) |
| `p0-final-dark-max-type.xcresult` | **2 failed + 2 expected failures**；顶部可操作/审计通过，滚动与底部contrast失败；两项立即触控expected matcher已收窄，只匹配既有描述，恢复检查通过 |
| `p0-final-light-max-type.xcresult` | **2 failed，5个contrast issues**；最大字号浅色也复现滚动范围问题，不能仅归因为Dark Mode |
| `p0-max-primary-probe.xcresult` | 诊断改色仍2 failed/5 issues，试验撤回；不把颜色试验保留为虚假修复 |
| `p0-final-system-motion.xcresult` | 真实系统ReduceMotionEnabled=YES、无强制launch参数，进入/返回1项通过5.92秒，日志实测systemReduceMotion=true；完成后恢复NO |
| generic Simulator / iOS device build | 两者通过，iOS18 deployment；设备构建无签名，没有安装真机 |

分批命令复用上面的 Simulator `xcodebuild test`，更换 `-resultBundlePath` 并使用 `-only-testing:RocoNativeUITests/NavigationTests/<方法>`。字号/外观实际命令为 `xcrun simctl ui <UUID> content_size large` / `accessibility-extra-extra-extra-large`、`appearance light` / `dark`。恢复检查等待的是真实exists条件/系统transition completion，不是App固定sleep、延迟或禁用交互。

Reduce Motion 实际设置命令为 `xcrun simctl spawn <UUID> defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES`，随后测试 `testSystemReduceMotionNavigation`；结束恢复NO、large、light。Simulator 最后重新启动停留在图鉴，可继续人工复核。`/tmp/rocom-p0-final-{dark-default,dark-max-type,light-max-type,system-motion}.log` 保留补测成功/失败，`/tmp/rocom-p0-max-primary-probe.log` 保留撤回试验。

本轮实际新增/修改：`AlignedNavigation.swift`、`PetGrid.swift`、`PetDetail.swift`、`PortraitSurface.swift`、`PortraitStore.swift`；新增 `HostTests/NavigationLifetimeTests.swift` 和UITest `TouchDriver.h/.m`，扩展 `NavigationTests.swift`；更新 `create-project.py`、生成工程/scheme与 `ios/README.md`；更新本记录、交接文档实施节，增加 followup PNG/xcresult统计JSON。没有修改RocoDomain模型、42 fixtures、契约或真实资源数据。

继续保留60Hz真机、ProMotion真机、Instruments、真实峰值内存、正式签名、全量内容包预算、3784/3785资源补齐。上述事项未被模拟器测试关闭。停止于P0，不进入P1。

## 历史产品基线调整：仅iOS27，当时等待环境升级（已解除）

2026-10-02用户正式确定最低iOS27，目标iPhone已经运行27（用户确认，本轮未读取设备版本）。**删除iOS18 runtime验收项，不支持18–26，不为其编写availability fallback**。Reduce Motion的可访问性降级继续保留；旧26.2结果仅为历史证据。

本轮实际执行只读检查：

```sh
sw_vers
xcode-select -p
xcodebuild -version
xcodebuild -showsdks
xcrun simctl list runtimes
ls -d /Applications/*Xcode*.app
git status --short
git rev-parse HEAD
```

| 项目 | 实测 |
|---|---|
| macOS | 27.0，26A428 |
| selected Developer目录 | `/Applications/Xcode.app/Contents/Developer` |
| Xcode | 26.2，17C52 |
| SDK | iOS/Simulator26.2；macOS/tvOS/visionOS/watchOS26.2；DriverKit25.2；无27 SDK |
| runtime | 仅iOS26.2，23C54；无27 runtime |
| `/Applications`中的Xcode | 仅Xcode.app |
| HEAD/status | HEAD仍`a1b39c7ea22ccf5b8d35f5e73bb70f7fe47dc428`；既有`.gitignore`修改和未跟踪P0目录/文档保留 |

结论：**当前不具备正式27 SDK，按用户指示停止继续实现。**本轮仅更新规划、本验证和README说明，未修改工程/Package/生成器/Swift或测试源，deployment尚为旧18.0，待升级后统一27.0。未安装/下载/切换工具链，未运行新的build/test，也未启动P1。没有将旧target继续保留解释为仍支持旧系统。

所需升级：安装正式Xcode27或带正式27 SDK的稳定后续版本；选择其Developer目录并完成首次组件/许可；安装iOS27 Simulator runtime并启动目标iPhone模拟器；连接个人iOS27 iPhone，核对信任、Developer Mode、Xcode识别与个人开发签名，随后实际安装运行。[Apple系统要求](https://developer.apple.com/xcode/system-requirements)列正式Xcode27包含iOS27 SDK、要求macOS26.6或更高；本机27.0满足所列版本门槛，无需本轮另升macOS。SDK和runtime必须分别确认，不能只更新Command Line Tools。

升级后仍仅续P0：确认正式SDK/runtime实际版本，再改App/测试/Package和工程生成源deployment27.0，保留现有SwiftUI结构与最小UIKit系统zoom bridge，重新build/Core/fixture/UI tests和27目标真机验证。先复核旧立即返回和大字号审计失败在27上的实际表现，不预设已修复。27正式公开API简化评估本轮未执行；必须证明图片连续性及取消/快速操作/可访问性至少等价，才能改bridge。不为纯SwiftUI重构。


## Xcode27迁移与P0回归（2026-10-02，历史结论）

本节覆盖前述历史暂停点。HEAD仍为`a1b39c7ea22ccf5b8d35f5e73bb70f7fe47dc428`，同一checkout；`.gitignore`修改和未跟踪的P0目录仍在，没有提交、开始P1或修改Web/上游基础数据。环境由用户准备，本轮未下载大型组件。真机未连接不阻塞本轮。

### 独立核对的实际环境与迁移

[实际环境命令输出](../../build/ios27-p0/docs-evidence/ios27-environment.json)保存本轮重新读取结果。

| 检查 | 实测 |
|---|---|
| `sw_vers` | macOS27.0，26A428 |
| `xcode-select -p` | `/Applications/Xcode_27.app/Contents/Developer` |
| `xcodebuild -version` | Xcode27.0，27A266a |
| `xcrun swift --version` | Swift6.4，swiftlang-6.4.0.34.1，clang2100.3.34.1 |
| `xcodebuild -showsdks` | iPhoneOS/Simulator27.0；macOS/tvOS/visionOS/watchOS/DriverKit均27.0 |
| `xcrun simctl list runtimes` | iOS27.0(24A434)已安装；26.2仍在但不用于当前验收 |
| 实际运行目标 | iPhone18Pro，iOS27.0/24A434，UUID`25EE507E-F0E7-4FB8-8484-0D7D216800DA` |
| `xcrun devicectl list devices` | 只有simulated设备，无可连接的用户真机 |
| 编译产物Info.plist | device和Simulator的`MinimumOSVersion`均实读为27.0 |

生成器和pbxproj的project/App/UI/host各Debug/Release共8份deployment统一27.0；scheme/LastUpgradeCheck更新2700。RocoCore tools-version6.4、platform `.iOS(.v27)`，Swift语言模式仍6。Package的macOS15声明用于独立Core测试，不是旧iOS支持。原型Swift源没有旧OS availability分支，因此没有要删的18–26条件分支；Reduce Motion保留。现存空`nonisolated deinit`是缓存/弱注册的销毁隔离约束及既有编译器问题修正，不是旧OS导航fallback，本轮未顺手删除。

**保留现有生产bridge。**SwiftUI仍负责App结构、Grid和详情；UIKit仅提供标准导航及系统图片对齐zoom。没有第二份生产path、业务Domain生命周期、全局singleton、手工animator/gesture或强引用环。PetID+origin identity、弱来源注册和同UIImage/placeholder持有策略保持原样。

两个必要修正：

- Swift6.4提示4个weak局部量未变更，改`weak let`。首次27回归的立即程序化pop测试还出现2个栈断言失败：旧helper仅等待当前push的transition completion，遗漏UIKit排队pop的`didShow(root)`；一次main-queue让步也未解决。改为**仅测试target**的delegate observer，转发真正Coordinator回调，等待实际目标controller的`didShow`返回后继续。同步push+pop仍在同一MainActor turn，检查pop确实被接受、source图片/alpha/交互恢复，同宠/另一宠重用；不延迟生产输入、不加sleep/第二套路由。独立3项生命周期测试通过，10轮immediate pop全部accepted=true。
- 两个SwiftUI隔离原型在预布局记录`Invalid frame dimension (negative or non-finite)`。原因是GeometryReader暂时width=0，`width-48`让Hero边长为负。`PetDetail`增加`max(0, min(...))`，正常正尺寸构图不变；最后整套回归无该警告，xcresult runtimeWarnings为空。没有借此重构已验证bridge。

### 实际命令与结果

最终命令使用公开`-collect-test-diagnostics never`。早期完整回归20个用例全部结束（18 passed+2 expected），但Xcode收尾超过3分钟不结束，SIGINT未退出，SIGTERM后exit143且xcresult缺Info.plist，**该命令不是成功**。[控制台统计](../../build/ios27-p0/docs-evidence/ios27-regression-console-summary.json)明确标记非xcresult结果；原日志为`build/ios27-p0/regression-console.log`。对初轮卡住的xcodebuild做1秒进程采样，`build/ios27-p0/xcodebuild-stall.txt`显示`XCTHRunDestinationAllocator.collectSimulatorDiagnostics`阻塞在semaphore，不是App内存采样。取消若干中间UI重跑以修正尺寸和排查收尾，均不计为最终通过。

`-collect-test-diagnostics never`只跳过额外verbose/sysdiagnose采集；断言、expected failure、xcresult和截图仍保留，无审计过滤。不能由此宣称诊断采集故障已修复，默认配置收尾仍待Xcode工具问题跟踪。未禁用App交互。

```sh
swift test --package-path ios/Packages/RocoCore
node ios/PrototypeTools/freeze-fixtures.mjs --check
xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios27-p0/simulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -destination 'generic/platform=iOS' -derivedDataPath build/ios27-p0/device-final CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -destination 'platform=iOS Simulator,id=25EE507E-F0E7-4FB8-8484-0D7D216800DA' -derivedDataPath build/ios27-p0 -resultBundlePath build/ios27-p0/regression-final.xcresult -parallel-testing-enabled NO -collect-test-diagnostics never test
yarn type-check
yarn build
node scripts/test-pet-data-quality.mjs
node scripts/test-skill-acquisition-index.mjs
node scripts/test-shiny-collection.mjs
node scripts/test-handbook-progress.mjs
node scripts/test-badge-trial-data.mjs
```

Core4项、freeze42项通过；Simulator及无签名device build通过，后者在最终尺寸修正后再build通过。Web type-check5.52秒、build20.89秒通过，既有构建警告保留。四项数据测试通过（pet1147/631、skill613、shiny81slots、handbook merge）；徽章检查仍因3784/3785和species467缺头像失败，未改造上游数据或执行sync。日志`/tmp/rocom-p0-ios27-{core,simulator-build,device-final,web-types,web-build}.log`。

| 当前27 xcresult（`build/ios27-p0/`） | 实际结果 |
|---|---|
| `regression-final.xcresult` | **20项：18 passed、2 expected failures、0 unexpected/skip，命令exit0 / TEST SUCCEEDED**；451.289秒含测试启动/结束；[原始统计](../../build/ios27-p0/docs-evidence/ios27-final-test-summary.json)、[逐项结果](../../build/ios27-p0/docs-evidence/ios27-final-tests.json)。17 UI+3 host，runtimeWarnings为空；2 expected不算P0验收通过 |
| `lifecycle-observed.xcresult` | 3 passed、无expected/skip；39.255秒；[原始统计](../../build/ios27-p0/docs-evidence/ios27-lifecycle-test-summary.json) |
| `dark-final.xcresult` | 最终代码深色large的Grid/详情审计、底部、50%/80%取消、Hero往返5 passed，命令exit0；[原始统计](../../build/ios27-p0/docs-evidence/ios27-dark-final-test-summary.json) |
| `light-max-final.xcresult` | 最终代码最大辅助字体浅色2 failed、2个Contrast issues，命令exit65；[统计](../../build/ios27-p0/docs-evidence/ios27-light-max-final-test-summary.json)。早期`light-max.xcresult`也失败并经历诊断采集卡住，保留原始结果 |
| `dark-max-final.xcresult` | 最终代码最大辅助字体深色2 failed、2个Contrast issues，命令exit65；[原始统计](../../build/ios27-p0/docs-evidence/ios27-dark-max-final-test-summary.json) |
| `system-motion-final.xcresult` | 最终代码实际系统Reduce Motion开启、无强制launch参数，1 passed，命令exit0；[原始统计](../../build/ios27-p0/docs-evidence/ios27-system-motion-final-test-summary.json) |
| `baseline.xcresult` / `lifecycle-probe.xcresult` | 保留迁移初轮/错误等待修正试验的host失败；不能算最终修复通过 |

分批复用Simulator test命令，加`-only-testing:RocoNativeUITests/NavigationTests/<方法>`及不同resultBundlePath。Dark/字号分别实际使用`simctl ui <UUID> appearance dark`与`content_size accessibility-extra-extra-extra-large`；默认为large。Reduce Motion用`simctl spawn <UUID> defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES`，实际运行日志`build/ios27-p0/runtime-final-appearance.log`包含18:50:05的`systemReduceMotion=true`；随后恢复NO。真实字体日志含`UICTContentSizeCategoryAccessibilityXXXL`，最终浅/深色截图已覆盖更新；审计未过滤。[最终外观批次命令退出码](../../build/ios27-p0/docs-evidence/ios27-final-appearance-commands.json)明确保留max两次65和motion0。当前Simulator已实读恢复light/large/ReduceMotion=0并启动默认图鉴。

[27运行解码初测](../../build/ios27-p0/docs-evidence/ios27-runtime-report.json)从最终回归时间窗的真实统一日志读取394条、29宠（混合多次launch/测试，含placeholder）：中位1.74ms、nearest-rank p95 12.67ms、最大24.78ms。Simulator测试App目录5152KiB（含host测试插件），无签名device目录5000KiB；不是签名IPA或完整发布内容包规模。不是受控冷缓存基准、峰值内存或FPS结论。全量包预算仍待后续闭包测量。

### 当前27共享视觉与验收矩阵

查看27原始MOV的解码帧，采用的UIImageView对齐bridge在这些正常往返/大幅反向取消片段中只有一张移动图片，缩回正确source槽，取消后source/Hero/交互恢复。**局部图片共享元素目标达到；完整P0尚未通过。**不从单台Simulator推断真机触感/刷新率或所有路径。

- [80%反向取消](ios27-native-80-cancel.png)：`baseline.mov`解码帧470–626，每4帧；相关xcresult activity记录17:57:57.827开始、17:58:12.314取消截图。
- [50%反向取消](../../build/ios27-p0/docs-evidence/ios27-native-50-cancel.png)：帧1110–1230，每5帧；activity记录17:58:20.358开始、17:58:29.217取消截图。
- [原生进入/后续交互片段](../../build/ios27-p0/docs-evidence/ios27-native-open.png)：帧410–486，每4帧；观察图片到Hero构图连续，无额外自定义动画。
- [深色观察缩略图](../../build/ios27-p0/docs-evidence/ios27-dark-overview.png)保留了实际深色图片/取消画面，原始录屏如下。27原始录屏：`build/ios27-p0/evidence/{baseline,prototype-comparison,dark,regression-final}.mov`。contact sheet按解码帧采样，**不是实际FPS/帧耗时指标**，不把视频元数据60fps当作性能通过。

| 要求 | 当前状态 |
|---|---|
| Grid→Hero、返回正确cell | 顶3001/中3015/底3785及真实3585均实际往返；返回位置≤2pt；观察片段满足图片共享几何 |
| 50%/80%取消 | **27 Simulator已关闭**：连续单触点0.03W→0.53W/0.83W→0.08W，系统日志cancelled=true；是屏宽拖距，不伪称percentComplete精确0.5/0.8 |
| 取消后正常返回/重入同宠/另一宠 | 真实50%/80%及短取消恢复测试通过，无永久图片消失、残留Hero、错cell/hit testing损坏 |
| 连续往返/快速顺序输入 | 真实图片30轮及6轮无显式sleep顺序进入返回通过；XCTest idle机制不代表输入与动画重叠 |
| 动画期间立即尝试触控返回 | **未关闭**：raw Back 0.08/0.15/0.30秒及0.15秒抓图drag仍不能pop，2 expected-failure诊断如实复现；稍后正常返回/重入可用。完成页按钮坐标未必等于动画时实际可触位置，仍不能确定App race或系统限制 |
| UIImage/context/导航生命周期 | 真实UIKit3项host通过；10轮同main-turn立即程序化pop接受且恢复，详情/协调器释放、bitmap一致；程序化成功不关闭立即触控门槛，也不是Instruments无泄漏证明 |
| 冷图/缓存图/缺图 | 首次App解码与后续缓存图、3784/3785占位实际进入返回，持有同UIImage；未清OS磁盘缓存或测真实冷启动p95 |
| Dark Mode/Reduce Motion | 深色共享路径和审计通过；实际系统Reduce Motion静态进入与系统返回可完成任务 |
| 默认字体/44pt/audit | Grid和原生Back ≥44pt，默认字体Grid/顶部/滚动/底部审计通过，AX关键操作可查可点击 |
| 最大辅助字体/audit | 实际AX5可滚动、查看截图无横向文字截断；Grid/顶部审计通过，浅/深色滚动/底部Contrast仍失败，**accessibility部分未关闭** |
| VoiceOver | **未验证**：SDK27 XCTest无公开VoiceOver控制服务，日志voiceOver=false；AX audit不替代朗读遍历、返回焦点和手势陷阱。留待用户真机/可用VO环境 |
| 目标真机 | 无设备连接和签名，未安装/运行；触控手感、60Hz/ProMotion、实际VoiceOver、Instruments/真实峰值内存继续待验收 |

最大字号失败仍是“物攻”节点frame=(24,730.09,100.33,63.33)，审计认为hittable；但截图已滚到魔防/速度/特性。见[浅色失败截图](../../build/ios27-p0/docs-evidence/ios27-light-max-scrolled.png)、[深色失败截图](../../build/ios27-p0/docs-evidence/ios27-dark-max-scrolled.png)。可见范围/AX frame为何不一致尚未定位，不能当作确定误报，也未通过隐藏offscreen节点、延迟刷新或过滤issue压掉。

### iOS27正式公开API的隔离比较

实际检查27 SDK `SwiftUI.swiftinterface` 与UIKit `UIZoomTransitionOptions.h`/`UIViewControllerTransition.h`，并核对Apple正式[SwiftUI zoom](https://developer.apple.com/documentation/swiftui/navigationtransition/zoom(sourceid:in:))、[source configuration](https://developer.apple.com/documentation/swiftui/matchedtransitionsourceconfiguration)、[crossFade](https://developer.apple.com/documentation/swiftui/navigationtransition/crossfade)。本地正式接口中`.zoom(sourceID:in:)`仍没有目标Hero alignment rect参数；source configuration提供背景/圆角/阴影。27新增`.crossFade`及`AnyNavigationTransition`，后者是类型擦除，不能据其存在推断共享图片几何解决。

隔离启动参数互斥，默认生产路径始终是已有bridge：

| 原型 | 本次真实比较与决定 |
|---|---|
| `--swiftui-zoom` | NavigationStack与原有source/header构图在27实际进入/返回可点通，但[逐帧](ios27-swiftui-zoom-open.png)再次可见两张不同位置/尺寸的头像叠加、返回分离；不达到图片连续性，拒绝替换 |
| `--swiftui-cross-fade` | 单独使用27公开`.navigationTransition(.crossFade)`。进入/返回功能通过；当前NavigationStack实测[页面水平滑动](../../build/ios27-p0/docs-evidence/ios27-crossfade-prototype.png)，source与Hero分别出现，没有共享图片移动轨迹；该正式API文档以sheet为例，不能据此声称本NavigationStack具备共享元素能力 |
| 当前UIKit bridge | 正式公开zoom+alignmentRectProvider直接对齐两端UIImageView，维持既有几何与取消；约90行局部桥接，没有维护第二套生产导航状态 |

两个原型已在第一项图片连续性标准失败，未进一步把其50%/80%、快速取消和生命周期全部宣称等价。没有替换bridge、叠加多套动画或新增自制导航框架。原型的独立path仅用于launch-flag对照，不和默认UIKit路径同时创建。

### 文件变化、门槛与停止点

本轮修改：`PrototypeTools/create-project.py`与生成pbxproj/scheme、`RocoCore/Package.swift`、`.gitignore`；`HostTests/NavigationLifetimeTests.swift`测试同步/weak常量；`RocoApp.swift`、`PetGrid.swift`隔离crossFade入口、`NavigationTests.swift`对照测试和诊断文案；`PetDetail.swift`零尺寸约束。默认`AlignedNavigation.swift`、图片注册/缓存/资源、RocoDomain模型、冻结契约与42 fixtures未改。更新本记录、规划15.5、`ios/README.md`，增加27证据PNG和JSON。

**剩余P0 blocker**：立即真实触控返回路径未关闭；最大辅助字体滚动audit失败未定位。实际VoiceOver遍历/返回焦点仍未验证，按用户本轮约束保留真机待验收，不阻塞Simulator工作。Xcode额外诊断采集卡住需跟踪，最终命令使用公开关闭额外采集的选项。正式签名/个人真机安装、60Hz/ProMotion、Instruments/峰值内存、全量内容包预算、3784/3785等资源补齐继续待验证；它们没有被本轮模拟器关闭。

**不建议进入P1。**产品/工具链迁移完成不等于P0所有验收通过；不开始P1或批量实现八项功能。停在P0并保留上述未关闭项。

## P0 architecture accepted / frozen（2026-10-02）

用户明确接受 shared zoom 技术路线，冻结 P0 架构，后续可另开 P1 任务。本节覆盖上面的历史停止决定；这是带已知问题的架构接受，不把历史测试失败或未验证项改写成通过。本轮不实施 P1，不继续追查 pop 末段 handoff。

### 冻结实现与依据

- 保留 `UINavigationController` + SwiftUI `UIHostingController` 和系统 `preferredTransition = .zoom` / `alignmentRectProvider`。系统负责转场、返回和交互取消，不重做纯 SwiftUI zoom，不添加自定义 animator / 手势 / 第二套路由。
- Grid 保持透明背景；source 与 Hero 使用相同 UIImage、aspectFit 和每边 8% 内缩；registry 按稳定入口身份弱引用真实 UIImageView。外层布局不重复写入子 UIImageView frame。
- Hero 已进入 ScrollView 内容，可随内容滚动，不是固定 overlay / safeAreaInset。
- 保留 sizeThatFits 的必要修正：未指定维度不替换成 0；Debug 工程条件仍定义 `DEBUG`，个人真机签名配置未改。
- 用户最新生产真机日志确认 `sameSource=true`、`targetDelta center=(0,0) width=0 height=0`，alignmentTargetWindow 与最终 gridImageWindow 完全一致；该次 pop 没有 ZERO_HEIGHT，未再出现 `Failed to create 1320x0 image slot`。这些是用户提供的复现结论，本轮没有另行采集原始真机日志或完整矩阵。

### 剩余 known issues 与承接阶段

| 项目 | 当前状态 / 证据边界 | 后续承接 |
| --- | --- | --- |
| 真机 pop 最末段轻微视觉 handoff 晃动 | 可见；外部 completion 几何一致，具体渲染原因与发生在 completion 前/后尚未确定。接受为视觉 polish 问题，不阻塞 P0 架构冻结 / P1 内容工作 | P3 / 最终视觉打磨；禁止用 delay、crossfade、提前隐藏/再显示、补偿动画或其他 hack 掩盖 |
| 动画期间立即真实触控返回 | 历史 27 回归仍有两项 expected failure；没有新证据关闭。正常返回/再次进入和程序化生命周期已有历史证据 | P3 导航完整矩阵复核，发布前处理 |
| 最大辅助字体滚动 contrast audit | 历史失败保留；发生于早期固定 Hero 布局。当前滚动 Hero 修正后未重跑，不能宣称已修复 | P3 详情与可访问性收尾 / 发布前复核 |
| VoiceOver 朗读、返回焦点、手势陷阱 | 仍未完成真实 VoiceOver 验证；普通真机视觉反馈不替代它 | 可访问性收尾，进入 P7 前补齐 |
| 60Hz/ProMotion、Instruments 帧预算与真实峰值内存 | 未完整测量；此前录屏和解码时间不是 FPS/峰值内存结论 | 最终性能验收 / P7 前补齐 |
| 3784/3785、species 467 徽章头像与完整内容包预算 | 已知缺图/徽章检查失败保留，P0 明确占位；全量资源闭包和发布包预算未完成 | P1 缺图报告、资源裁剪与包体测量，不伪造资源、不隐藏既有失败 |
| Xcode 额外 Simulator 诊断采集卡住 | 历史工具问题保留；公开关闭额外采集不等于问题已修复 | 后续需要完整自动矩阵时跟踪 |

这些事项随架构冻结移入明确的后续清单，不继续作为“shared zoom 技术路线未成立”的结论；历史失败仍然失败，未验证仍然未验证。

### 临时诊断清理

移除 ZoomDiagnostics 全树输出、custom diagnostic hosting subclass、layoutSubviews / window / safeArea / proposal 监听、SwiftUI Hero 输入日志、透明 region probe 及其 registry。冻结实现不含 display-link、snapshot 扫描或 border overlay。

仅在 `#if DEBUG` 保留三类日志：`zoom shown detail`（身份与 sameBitmap）、`zoom interactive`（系统交互取消）、`zoom pop completion`（sameSource、最后系统 source target / 最终 Grid window rect、center/width/height delta）。provider 只更新标量测量，不逐次输出、不写布局/alpha/hidden；Release 不输出这些诊断。

### 本轮验证与 P1 交接

收尾完成后仅运行一次快速无签名 Debug device build：**BUILD SUCCEEDED，exit 0**。未运行 UI Test、host test、accessibility audit、Web 检查、完整回归或数据同步。此结果确认清理后的代码可编译，不是重新执行真机或完整矩阵。

```sh
DEVELOPER_DIR=/Applications/Xcode_27.app/Contents/Developer xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/ios27-p0/device-final CODE_SIGNING_ALLOWED=NO build
```

日志 `/tmp/rocom-p0-freeze-build.log`；只有未依赖 AppIntents 的 metadata extraction 提示。`git diff --check` 通过。未修改项目个人签名配置、Web/upstream 数据、Core 契约或 fixture，未新增 Git commit / tag；frozen 是本文记录的架构决策。

P1 第一件事：基于 [content.schema.json](content.schema.json) 和 [contracts.md](contracts.md)，实现只读现有源数据的确定性规范 JSON + manifest 导出，先核对稳定 ID、nullable、FK、来源 hash 和同输入可重复性；输出与 Web/upstream 数据隔离。29 项 PrototypeCatalog 是技术样本，不能直接扩充冒充发布 schema。此任务没有创建 exporter、SQLite 或新的业务页面。
