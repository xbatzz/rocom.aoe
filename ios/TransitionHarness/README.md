# P0 独立 zoom transition harness

最低 iOS 27。独立 bundle、Xcode 工程、UITest target；不链接 RocoNative 或 RocoCore。唯一复用资源是只读引用 `JL_miaomiao.png`。SwiftUI 负责内容，B 使用与生产相同的系统 UINavigationController zoom API 和图片布局。没有自定义 animator、固定 delay、手动隐藏图片、末帧 crossfade，也没有业务代码入口。

打开 `TransitionHarness.xcodeproj`，运行 `TransitionHarness`。默认 B-parity；右下角 Variant 菜单切换变体。也可以设置 launch arguments `--variant A-image` 等。每次导航使用同一个解码后的 UIImage 实例。固定深色，灰 Cell 为 white=0.18、160pt，图片内缩8%；Hero为320pt，图片268.8pt。A-equal 的 Hero 为160pt。图片两端都为方形、aspect fit、相同比例 padding；只有角色位置与整体导航布局随场景变化。

| 变体 | 唯一实验变量 |
|---|---|
| A-image | matchedTransitionSource 直接挂无背景 Image；destination 为页面 zoom |
| A-equal | A 的 Hero 图片边长与 source 相同 |
| A-clear-source | A 的 source configuration 显式 `.background(.clear)` |
| B-parity | UIImageView source；图片 alignment rect；Hero、页面黑色；保留生产 opacity 默认值 |
| B-clear-hero | 只清除 Hero 容器背景 |
| B-explicit-transparent | 清除 Hero 背景；容器/图片显式 isOpaque=false；图片 backgroundColor=clear |
| B-hero-magenta | 只给 Hero 容器加紫色诊断背景 |
| B-page-green | Hero透明；给详情 SwiftUI 背景及 hosting root 加绿色诊断色 |
| B-no-alignment | 只移除 alignmentRectProvider |
| C-black-container | 故意注册整 Cell 容器，对齐包含黑背景的整 Hero 容器 |
| C-black-source-config | 故意把 SwiftUI matched source configuration 背景设黑色 |

```sh
python3 ios/TransitionHarness/create-project.py
python3 ios/TransitionHarness/run-evidence.py --name my-run
python3 ios/TransitionHarness/analyze-evidence.py build/ios27-p0/transition-harness/my-run
# 单独补录：
python3 ios/TransitionHarness/run-evidence.py --name my-swiftui-run --only testAImage testAEqual testAClear testCBlackConfiguration
```

`--device` 可替换 simulator UUID；name 必须未存在，以免覆盖证据。run-evidence 调用 build-for-testing、test-without-building 和 simctl recordVideo。只用 XCTest 原生点击；等待元素条件及系统 idle，无 sleep/动画固定延时。每个变体3次往返。导航断言通过不等于视觉通过。

Trace 的 CADisplayLink 只读取公开 UIView/CALayer 属性，记录运行时类名是观察而非调用私有 API。A 连续采样，B按实际 coordinator 活动采样。日志在 Documents/<variant>/trace.json；Export probes 可手动导出当前日志。系统自己改变 source presentation opacity，harness不干预它。PNG探针仅在 didShow 后执行，透明 UIGraphicsImageRenderer 分别渲染 UIImageView、Hero、详情 root，不用于动画。不能把这些探针声称为系统内部 snapshot 的直接导出。

analysis 用 cv2 解码原录屏帧，保留 PTS，不插帧，不改动画速度。原始 simulator 录像为可变帧率，不能用 `frameIndex/60` 当时间。导出的画面缩到402×874方便以pt坐标检查；H.264颜色有压缩误差。触控、布局事件到录像的绝对同步使用 recorder acknowledgement，有小量误差；相邻视频帧的先后和间隔直接取原PTS。不要把 display-link 一帧与编码录像一帧视为一一对应。

[本次证据与结论](../../docs/ios-p0/transition-harness/report.md)。依赖本机 Python 的 numpy / Pillow / opencv 和 ffmpeg；本次已存在，无新增依赖安装。只涉及 P0 隔离实验。
