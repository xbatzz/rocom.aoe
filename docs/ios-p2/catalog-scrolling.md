# 图鉴与技能连续滚动

2026-10-03；常规（standard）界面，保留现有排版、系统导航与冻结的头像 shared zoom。

## 真机采样

设备：iPhone 16 Pro Max，iOS 27.0 (24A5380h)。工具：Xcode/Instruments 27.0 (27A266a)。使用个人开发签名的带符号 Release 构建，Animation Hitches 模板附加 Time Profiler。按名称/PID 附加无法枚举已运行的进程，改用 all-processes；分析只统计 RocoNative，排除 system hitch 重复行。

基线保留原有每页 24 项：用户快速上下滑动，并切页覆盖新图片/技能。优化后在连续列表快速上下滑动并反向滚动。图鉴各 45 秒，技能基线 35 秒、连续滚动复测 15 秒；人工操作不保证同距离、同速度、同冷/热缓存，不能将 CPU 样本差异当作精确加速比，也不据此宣称稳定 60/120 fps。

基线图鉴：主线程 Running 样本合计 10,851 ms，`PortraitStore.image(for:)` inclusive 4,823 ms（44.4%），`AssetResolver.resolve` inclusive 393 ms，`PetListQuery.results` inclusive 68 ms。29 次 App hitch，累计 487.54 ms，最长 37.50 ms。确认头像同步校验、ImageIO 解码是首要热点。

基线技能：主线程 Running 样本合计 10,934 ms；`SkillAcquisitionQuery.results` inclusive 163 ms，搜索 inclusive 1 ms。26 次 App hitch，累计 354.20 ms，最长 16.67 ms。行内重复构造家族获得关系有实测成本，搜索不是本次最大热点；仍从 body 中移出以避免滚动时重算。

图鉴连续滚动复测：ImageIO 主线程 inclusive 样本从 4,426 ms 降为 0，后台 25,118 ms；最长 hitch 从 37.50 ms 降为 12.50 ms。App hitch 68 次、累计 845.91 ms，高于分页基线的 29 次/487.54 ms；连续列表覆盖更多首次加载内容，不能称为无 hitch 或将次数作为相同负载下的回归。用户体感已明显顺滑。

技能第一轮完整连续滚动复测（15 秒）仍有 213 次 hitch，累计 8,196.57 ms、最长 100.01 ms。主线程 Running 12,528 ms，其中 SwiftUICore inclusive 11,569 ms；ImageIO 主线程 0、后台 427 ms。解码优化有效，但列表构建/更新仍有严重开销，未通过性能验收。随后将 ForEach 的条件查找与多个根子视图改为预先解析的 Skill 数组和单一 SkillCatalogRow；最终技能目录复测（实际 17.473872 秒）：45 次 App hitch，累计 629.22 ms，最长 25.00 ms；主线程 Running 5,448 ms，其中 SwiftUICore inclusive 4,433 ms，ImageIO 主线程 0、后台 108 ms。符号和调用栈显示残余成本以 stack layout 的 sizeThatFits/placeChildren 为主。相较上一轮，长停顿已显著缩短，但分页技能基线的最长 hitch 为 16.67 ms，因此不宣称相对分页基线每项指标均提升。用户确认最终技能列表“已顺滑，没有明显停顿”。

Trace、构建、测试和截图位于本地 `build/ios-scroll-profile/`，通过本地 Git exclude 排除，不提交大文件。技能断连和保存时空间不足的采样均不用于对比；仅统计完整保存的 trace。早期优化 trace 的应用符号因 Release 二进制被后续构建覆盖而不完整，ImageIO/SwiftUICore 系统模块和 hitch 数据仍可分析；最终技能行版本已额外保留匹配的 dSYM。GPU counter profile 警告不能作为 GPU 优化证据。

## 实现

- `PortraitStore.image` 改为 async，复用 `CanonicalThumbnailStore` actor。文件验证、ImageIO downsample/decode 与缓存读写全部在后台 actor 上串行执行；不再存在图鉴独立的同步解码缓存。
- 缓存按 asset ID + 请求像素大小区分，16 MiB cost limit、256 项 count limit。相同资源/尺寸共享 UIImage；不同展示尺寸有意保留不同 downsample 结果。成功资源解析只验证一次；缺图和错误维持原有语义。
- 图鉴 UIImage 由挂载的 `PortraitSurface` 持有，不放入每个访问过的 cell 的 `@State`。卸载时取消请求并释放 bitmap。注册的来源视图与详情仍使用同一 UIImage，保留 8% inset 和既有 UIKit 导航桥。
- 普通技能/收集缩略图离屏时清空 bitmap state；离屏图片只由有上限的应用缓存保留。任务取消后不发布过期图片或错误。
- 每 4 项设置一个最多前方 4 张的预取窗口，使用同一串行解码和缓存，逐张 yield、检查取消；没有整库预加载，也没有用户可见的 chunk/page。
- ContentStore 初始化时准备图鉴资格集合、总数、属性选项、普通属性、ID 排序技能、技能速览及进化来源集合。保留已有 icon/type/family 字典；增加 pet+source、skill+source 和同名技能家族数量索引。技能行读取家族数量是 O(1)。
- 主图鉴、技能目录和高级筛选的搜索/排序在条件变化时更新缓存结果；耗时全表查询移到 `@concurrent`。技能获得方式也仅在条件变化时后台计算；精灵详情技能只筛选当前精灵、当前来源的索引结果。
- 技能目录搜索结果先解析成 Skill 数组，ForEach 每个 ID 返回单一 SkillCatalogRow；精灵详情技能及获得方式也每项返回单一容器，避免条件/多根子视图迫使懒列表计算全库子项结构。
- 图鉴使用完整 `LazyVGrid`、技能目录与详情/获得方式使用 `LazyVStack`、高级筛选使用系统 `List`。已移除这些页面的页码、上一页/下一页；筛选更改回到结果起点，详情返回保留滚动位置。
- 图鉴/技能使用真实 petId/skillId，获得关系使用家族 key；PetSkill 改为真实关系复合 ID（pet、skill、source、legacyType、ordinal），不使用数组 offset。

滚动 cell 没有新增 material、blur、mask 或 shadow。图鉴 GeometryReader 保留用于冻结的图片几何布局：基线 `AnchoredPortrait.body` 相关样本约 134 ms，远低于解码热点；不通过猜测移除它，也没有重写交互式返回转场。

## 验证

- `swift test --package-path ios/Packages/RocoContent`：31 项通过。覆盖来源索引与原查询一致、家族数量与实际获得关系一致、稳定关系 ID、不改变同名技能获取/过滤语义。
- Release 真机目标构建通过；最终版本已安装到用户 iPhone。技能目录性能 trace 对应 row.dSYM（UUID 7578CECE-41C0-37E4-88C7-77D22E0B59A4）；随后仅将详情/获得方式行收拢为单一容器，重新构建、通过嵌套列表回归并安装。
- 原生 host focused tests：4 项通过，覆盖共享请求仅一次解码、尺寸变化、取消/缺图、两个图片入口共享同一 bitmap、预取上限、首屏 lazy decode 和 source/hero 同一 UIImage。
- 模拟器：iPhone 18 Pro / iOS 27。图鉴跨原 24 项边界滚动、打开详情并返回保持位置、搜索空结果；精灵详情技能、技能获得方式、高级筛选连续滚动；UIKit hosting controller 缩略图环境传播均通过。
- 技能正常字体及最大辅助字体（AX XXXL）连续滚动、打开详情、返回保持位置已通过。初次失败来自测试行程不足、长行中心离屏以及辅助字体下切换控件变为菜单；修正测试定位与断言，保留失败 xcresult。单根技能行结构变更后的正常/最大字体回归再次通过；详情技能和获得列表的连续滚动回归也再次通过。
- SwiftUI 静态审计：36 个文件，0 high；全 App 43 medium，主要为原有固定尺寸、GeometryReader 和其他功能的 offset ID，已检查本次滚动区域。
- 已查看正常图鉴、技能和最大辅助字体截图；用户真机反馈图鉴“已明显顺滑，没有明显停顿”、技能“已顺滑，没有明显停顿”。VoiceOver、深色/高对比、长时间峰值内存及精确 ProMotion 帧率未在本轮完整测量。

本次未修改 Web 或 canonical 数据，不运行 Web build。其他功能的分页不在本轮图鉴/技能滚动范围。

Apple Fidelity 暂评 84/100（standard）：现有原生导航、图鉴 shared zoom、连续列表身份/取消语义、Dynamic Type 与 Reduce Motion 路径已有运行证据；缺少完整 VoiceOver/降低透明度/高对比矩阵，按技能证据上限不授予 90 分。此评分不替代上述真机性能数据，短 hitch 仍明确保留。
