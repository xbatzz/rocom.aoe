# 冷启动加载优化

2026-10-03：启动时的「正在加载内容…」等待 `AppContent` 建立完整应用快照，并非只在渲染首页。

原流程读取并校验 17 份 canonical JSON（含 35,573 条精灵技能关联），建立关系索引，读取并校验 1,465 张 WebP 的字节数、SHA-256 和文件头，随后在主线程建立技能/收藏查询索引并打开 SwiftData 用户数据库。图片实际解码已由可见内容按需执行，没有预先解码全图，也没有网络请求。

本次调整：

- App 使用 `AssetValidationMode.onDemand`：启动仍检查 canonical 文件哈希、版本、数量、所有关系、资源 manifest、资源引用和审计文件。WebP 字节读取与哈希延后到 `AssetResolver.resolve` 请求该图片时执行，成功后才返回 URL。
- 资源路径在启动时检查相对路径格式；使用前解析符号链接并检查目录边界。缺图、坏图和越界链接仍明确报错，只有既有的两个 known-missing 资源返回缺图状态。
- 技能和收藏查询索引随 immutable snapshot 在 `@concurrent` 方法内构建。数据库打开与后台快照构建通过 `async let` 协调，不再在快照返回后串行建立 UI 线程上的索引。
- 默认 `ContentStore.load` / `loadInBackground` 保持 `.eager`，完整资源验证工具与既有调用不改变语义。`content-probe` 新增 `--on-demand-assets`，便于比较相同目录的两种策略。
- 增加 `com.batzz.rocom` / `startup` 的 info 日志，记录 `AppContent.load` 开始到 `.ready` 的时间，可用 Console 或 `log stream --level info` 观察。

## 验证

`swift test --package-path ios/Packages/RocoContent`：35 项通过（内容 24，用户数据 11）。新增覆盖两种策略的全部资源返回结果一致、按需拒绝缺图/坏图/越界符号链接、canonical JSON 损坏仍阻止初始化。

本轮按更新前的仓库规则执行过 `yarn type-check` 和 `yarn build`，均通过。用户随后更新验证策略：后续 iOS-only 迭代只运行相关 Swift 测试和一次快速 iOS build，不再默认执行 Web 构建或完整 Web 回归。

iOS 27 模拟器 Debug 和 Release 的 `xcodebuild build` 均通过。`NavigationTests.testHomeStartupAndFeatureNavigation` 通过：两次启动独立进程，使用隔离的内存用户数据库打开正常首页，再进入技能查询和异色收集。未修改个人数据。

Release 在已启动的 iPhone 18 Pro / iOS 27 模拟器上正常显示首页，使用普通持久化数据库的这次日志为 `Home content ready after 0.459038084 seconds`。[截图](../../build/ios-content/startup-evidence/rocom-startup-home-release.png)及[日志](../../build/ios-content/startup-evidence/rocom-startup-runtime.log)保留在 ignored 构建目录。

同一 Release `content-probe`、同一内容包，各读取 5 次的本机比较：

| 策略 | 首次读取 | 5 次中位数 |
| --- | ---: | ---: |
| 全量图片校验 `.eager` | 715.5 ms | 506.1 ms |
| 按需图片校验 `.onDemand` | 399.7 ms | 390.4 ms |

中位耗时降低约 23%。[完整校验报告](../../build/ios-content/startup-evidence/startup-eager-comparison.json)、[按需报告](../../build/ios-content/startup-evidence/startup-demand-comparison.json)。这组数据只统计 macOS 上的 `ContentStore.load`，不包含技能/收藏查询索引、数据库和 UI 绘制；测量时 Web 构建仍在运行，不能视为独占机器的性能基准。未清 OS 文件缓存，也未测真机点按图标到可交互的冷启动 p95。上述模拟器 `.ready` 日志也不等于首页绘制完成时间。

目前仍一次性读取完整 canonical 数据和建立搜索索引。首页使用跨表关系和收藏统计，本次保留这个完整快照边界；本轮主要移除了启动阶段不需要的全量图片读取。
