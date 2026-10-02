# rocom 原生 iOS App

**当前 App 已接 P1 真实图鉴 ContentStore（721 条配置）。** 架构沿用已冻结的 UIKit shared zoom；接线、lazy 图片和本轮 focused check 见 [真实图鉴接线](../docs/ios-p1/encyclopedia-wiring.md)。先运行 `python3 scripts/ios-store/prepare-bundle.py`，再打开 `ios/RocoNative.xcodeproj` Run。App 不再加载 PrototypeContent 或接受纯 SwiftUI transition 实验参数。

保留现有个人真机签名设置。下文 P0 命令/样本仅作历史记录，**不要运行旧 create-project.py 覆盖当前 P1 工程**。

---

# P0 历史原型

**P0 architecture accepted / frozen（2026-10-02）。** shared zoom 路线已被用户接受，保留 UIKit bridge；透明 Grid 和可滚动 Hero 为冻结实现。用户真机确认 pop completion `sameSource=true`、center/width/height delta=0。末段轻微视觉 handoff 晃动列为 P3 / 最终视觉 polish，不用 delay、crossfade 或 hack 掩盖。最新状态和其余 known issues 见[P0 verification 冻结节](../docs/ios-p0/verification.md#p0-architecture-accepted--frozen2026-10-02)。本次仅收尾，P1另开任务。

**当前产品只支持iOS27**。已实际核对并迁移到Xcode27.0(27A266a)、Swift6.4、SDK27.0；Developer目录为 `/Applications/Xcode_27.app/Contents/Developer`。App/测试与RocoCore Package最低iOS统一27.0，Swift语言模式6，Package工具版本6.4。不支持18–26，不要求旧runtime或availability fallback；Reduce Motion仍是可访问性要求。

本机27 runtime为24A434；验证用iPhone18Pro Simulator UUID `25EE507E-F0E7-4FB8-8484-0D7D216800DA`。本地App工程使用个人真机配置 `com.batzz.rocom`，本轮保留该配置；生成器的默认内部原型标识仍为 `top.aoe.rocom.prototype`，重新生成工程前须保留个人签名设置。26.2及先前27自动测试是历史证据，当前架构接受和用户真机结论见验证文档冻结节。

打开 `RocoNative.xcodeproj`，选择共享 scheme `RocoNative`，运行27 iPhone模拟器。工程与本地Package不依赖第三方Swift库。默认是SwiftUI内容+最小系统UIKit导航桥；`--swiftui-zoom` 为隔离NavigationStack对照，`--swiftui-cross-fade` 为27正式公开API实验，均不替代默认实现。功能可点击通过不等于共享图片视觉达标。

```sh
node ios/PrototypeTools/prepare-sample.mjs
python3 ios/PrototypeTools/create-project.py
swift test --package-path ios/Packages/RocoCore
node ios/PrototypeTools/freeze-fixtures.mjs --check
xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios27-p0/simulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/RocoNative.xcodeproj -scheme RocoNative -destination 'platform=iOS Simulator,id=25EE507E-F0E7-4FB8-8484-0D7D216800DA' -derivedDataPath build/ios27-p0 -resultBundlePath build/ios27-p0/regression-final.xcresult -parallel-testing-enabled NO -collect-test-diagnostics never test
```

`PrototypeTools` 仅生成固定小样本、测量和 P0 契约，不是 P1 全量 exporter。样本 DTO 与冻结 release schema 分开。`prepare-sample` 会读取当前 Web 生成数据，不会同步/修改它。数据更新后必须重新审查报告和 fixture，不应静默改基线。测试 fixture 时注入匿名固定时钟；D1–D4 只有人工审查样例，Swift 业务引擎在后续阶段实现。

[P0验证记录](../docs/ios-p0/verification.md)记录历史27命令、逐帧对照、失败及最新冻结决定。P0 未添加用户持久库、搜索/过滤或另外七项业务。P1第一步是按冻结schema导出确定性规范JSON和manifest，校验ID/FK/nullable与来源hash；本轮未实施。

Debug只保留 `zoom shown detail`、`zoom interactive`、`zoom pop completion` 摘要，后者包含sameSource及目标/最终Grid window rect和center/width/height delta。已移除layout、safeArea、proposal、view树和region probe临时诊断；Release不输出这些导航诊断。个人配置中的Debug条件保留 `DEBUG`。

`RocoNativeHostTests`检验系统导航栈、同UIImage、详情/协调器释放与同步push/pop。连续反向轨迹使用仅测试target的 `TouchDriver`：运行时探测XCTest内部触点记录接口，27已实际运行；App不链接/调用私有API，不引入Appium依赖。未来工具链仍需复核；接口不可用明确skip，不算通过。

两项 `testImmediate…` 保留已复现的未关闭触控路径，用严格 `XCTExpectFailure` 标记，仅匹配该路径的失败描述；其他断言仍应失败。测试套件成功不代表这两项验收完成，也不能用程序化中断替代。


历史27迁移的host立即pop测试等待系统实际`didShow`（包含排队pop），不靠固定时间；Hero尺寸约束为非负以适应转场零尺寸预布局。bridge没有重写。该轮Simulator整套20项为18 passed+2 expected failures、0 unexpected/skip，命令exit0；两项立即真实触控known failure与最大辅助字体浅/深色滚动audit失败均保留，当前布局修正后未重跑。Core4项、freeze42项、Web类型/构建和四项数据测试当时通过；徽章头像缺失测试仍失败。最新冻结决定接受这些未关闭事项进入后续清单，没有把它们改成通过。

本机Xcode额外Simulator诊断采集曾卡在`collectSimulatorDiagnostics`；上面公开`-collect-test-diagnostics never`只跳过额外sysdiagnose，保留assertions/xcresult/截图/失败，不算诊断采集故障已修复。用户已在个人真机复现并报告视觉/几何结论；VoiceOver、60Hz/ProMotion性能、Instruments/峰值内存、全量内容包与缺图仍按known issues清单承接。架构冻结不等于完整发布验收完成。
