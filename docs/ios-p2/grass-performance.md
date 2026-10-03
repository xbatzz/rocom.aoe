# 草系徽章与通用缩略图性能

2026-10-03：修复草系徽章点击、记录修改和地点切换时的重复统计开销，并优化各功能页共用的图片与搜索路径。

## 原因与修改

`GrassBadgeView.statuses` 是计算属性。原进度统计遍历全部 601 条足迹，每次闭包访问 `statuses` 都重新读取全部 `GrassRecord`，筛选地点、映射并建立字典；各行与其他统计也会重复构建。记录越多，开销越大。现在每次 body 更新只建立一次状态快照，过滤、统计和行内容共用；点亮统计只遍历当前地点记录，并检查 canonical 足迹是否存在。快照仍由实时 `@Query` 驱动，不保存可能过期的派生状态。

足迹顺序移到启动时后台建立的 `TrackingCatalogIndex`，页面过滤保留该顺序，无需重复排序。地点足迹与家族奖牌只计算当前模式需要的结果。列表使用 `LazyVStack`，按可见范围创建行。

原 `CanonicalThumbnail.task` 在主线程同步进行路径校验、文件读取、SHA-256 和 ImageIO WebP 解码，重新进入页面还会重复执行。新增应用生命周期共享的 `CanonicalThumbnailStore` actor，串行执行后台校验与解码；缓存上限 16 MiB / 256 张，按资源 ID 和实际像素尺寸复用位图。只缓存成功的资源解析，内容包在此生命周期内保持不可变。首次使用仍校验文件；未知、损坏资源仍报错，既有 known-missing 才显示缺图。任务取消后不提交旧图片或错误，尺寸/显示倍率变化重新请求。缓存由 `PortraitStore` 持有，通过 App 环境和 UIKit 承载的 `PetDetail` 传递。

`PetSearch.Query` 每个结果集只进行一次去空白、全半角转换、小写转换和精确数字解析。草系、勇者、异色、图鉴筛选、技能来源和配队精灵选择复用这一查询；名称、形态、资源键、别名与精确配置/图鉴/种族编号语义保持一致。首页取得示例头像改用 lazy prefix / min，勇者计数用家族键查询。

## 测量

本机 macOS、Swift Release、同一 canonical 内容包，在内存中创建真实 `GrassRecord` 模型，分别执行旧进度闭包和修改后统计，5 次取中位数：

| 总记录数 | 旧统计 | 修改后统计 |
| --- | ---: | ---: |
| 601（一个地点） | 457.76 ms | 0.77 ms |
| 1,803（三个地点） | 714.12 ms | 1.27 ms |

两种统计结果逐次断言相同。无记录时旧统计约 0.033 ms，因此用户库为空时不能把重复记录统计当成主要卡顿原因；图片主线程解码与整页提前创建仍是独立的开销。搜索+目录查询中位数：空查询 0.67 → 0.17 ms，全角精确编号约 1.01 → 0.15 ms；中文模糊匹配约 6.45 → 6.12 ms，仍需要逐成员匹配。

[原路径测量](../../build/ios-performance/baseline.txt)、[修改后查询与统计对比](../../build/ios-performance/optimized.txt)、[临时测量程序](../../build/ios-performance/probe/Sources/main.swift)、[Time Profiler 记录](../../build/ios-performance/statistics.trace)保存在本机构建目录。Time Profiler 的统计调用栈包含重复 `statuses` / Sequence.filter / SwiftData 属性访问；这份 trace 使用对比程序，**不是 iPhone App 点按过程**。这些数字只描述统计和查询路径，不是整页点按到可交互时间，也不是帧率或真机 p95。尚未测真机动画帧时间。

## 验证

- `swift test --package-path ios/Packages/RocoContent --filter 'TrackingCatalogTests|PetCatalogPresentationTests|SkillSearchTests'`：8 项通过。新增搜索对照覆盖真实精灵、家族和异色槽位，含空白、全角编号、精确编号、形态和别名；验证预排序目录一致。
- `swift test --package-path ios/Packages/RocoContent --filter 'SelectedParityTests.exactMemberIdentifiersCombinedFiltersAndAllStatsSort|SelectedParityTests.concreteSkillFamilySourceAndMemberExpansion'`：2 项通过，覆盖组合筛选、排序、技能来源与成员展开。
- iOS 27 Simulator 快速 build 通过。
- `CanonicalThumbnailStoreTests`：并发相同请求共享 UIImage、不同尺寸、返回复用、缺图、未知资源和取消请求通过。
- `testCollectionEntryPortraitAndWhitespaceNavigation`、`testCatalogPaginationAndSearchReset`：三个收藏入口反复打开、目录分页及搜索重置通过。
- `testGrassRecordsStayLiveAcrossLocationAndModeChanges`：隔离内存库写入三个地点共 1,803 条记录，验证修改足迹、地点独立统计、奖牌独立统计、切换模式后实时更新通过。[结果](../../build/ios-performance/grass-records.xcresult)
- `testEncyclopediaHostedThumbnails`、`testRealContentSourceAndHeroShareBitmap`：UIKit 承载的图鉴详情缩略图、原有共享 UIImage 导航契约通过。[结果](../../build/ios-performance/thumbnail-hosts.xcresult)

所有 UI 测试使用 `--visual-review` 的隔离内存数据库，压力数据仅在 Debug 显式 `--grass-performance-fixture` 参数下生成。
