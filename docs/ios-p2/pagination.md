# iOS 列表分页与收藏入口点击范围

2026-10-03。本轮使用 standard 界面方案，沿用系统按钮、菜单和现有页面样式。

## 行为

- 图鉴、技能目录、异色收集、命定勇者、草系徽章的地点足迹与家族奖牌，每页最多 24 项。
- 高级精灵筛选、技能获得精灵、精灵详情技能、配队精灵与技能选择、草系徽章家族足迹和家族搜索建议也采用相同分页。
- 列表顶部与底部提供上一页、下一页及页码菜单。单页仅显示项目范围，不显示翻页按钮；家族搜索建议只在顶部提供翻页。
- 搜索、筛选、排序与赛季变化后回到第一页。收集状态改变时保留当前页，结果减少到当前页不存在时修正到最后一页。进度统计仍使用完整数据。
- 翻页返回当前列表开头，精灵图鉴打开详情并返回时保留当前页。保留现有 shared zoom、Hero 挂载与返回机制。
- 异色收集按家族分组，家族跨页时重复显示家族标题，组内进度按完整赛季统计。当前赛季只有 19 项；选择全部赛季可浏览 81 项。
- 首页异色收集、草系徽章、命定勇者整行可进入，包含头像、进度和留白。进度条作为展示内容，入口中的文字仍提供数量信息。
- 最大辅助字号或卡片宽度不足时分页按钮改为纵向排列，避免逐字换行。没有新增自定义动画。

## 实现

`SharedUI/CatalogPage.swift` 负责边界和切片，`CatalogPagination.swift` 负责系统按钮与页码菜单，`CatalogPaginationModifier.swift` 负责页面级重置、修正与滚动。各页面持有自己的页码。嵌在详情分区内的列表由现有 ScrollViewReader 处理滚动，避免嵌套滚动容器。

相关修改位于 `ios/RocoNative/Features/{Encyclopedia,Skills,Tracking,Teams,Hub}`、`SharedUI/CompanionTabbedPage.swift` 和工程的三个新增源文件登记。Debug VisualReview 增加大量技能/获得精灵的测试入口；测试使用内存数据库。Web、生成数据、个人签名配置均未修改。

## 验证

Xcode 27.0 / Swift 6.4，scheme `RocoNative`，iPhone 18 Pro / iOS 27.0 Simulator，UUID `25EE507E-F0E7-4FB8-8484-0D7D216800DA`。

- iOS Simulator build 成功；相关 UI/Host 测试通过情况记录在对应 xcresult 中。
- `testPaginationTraversalAndShrinkingResults`：遍历 721 项无重复或遗漏，24/48/49 项边界、空结果、超界页码修正。
- `testCatalogPaginationAndSearchReset`：技能、命定勇者、草系徽章、全部赛季异色翻页及搜索清空重置；页码跳转至末页与下一页禁用。
- `testCollectionEntryPortraitAndWhitespaceNavigation`：三个入口分别从头像、进度/副标题区域和右侧留白进入并返回。
- `testPaginatedEncyclopediaReturnAndLargeText`：图鉴第二页打开详情后返回保留页码；最大辅助字号下命定勇者翻页。
- `testPaginationInLargeSkillAndPetResults`：学院呱呱技能石、防御技能获得精灵、高级筛选、配队精灵和技能选择翻页。
- 原有 `testPetDetailQuickSectionsAndSkillFilters`、`testSkillDetailSectionsRetainAcquisitionFilters`、`testDetailAndBitmapLifetime` 覆盖分区、筛选保留及图片返回生命周期。
- SwiftUI 静态审计：0 high、39 medium，新增分页组件没有审计项；medium 为既有固定尺寸、序号身份等提示。
- `git diff --check` 通过。按仓库的平台边界，只验证 iOS，没有运行 Web 构建。

结果包：`build/ios27-p0/pagination-fixed.xcresult`（Host 与原技能详情测试通过；UI 测试初始定位问题已由后续运行修正）、`pagination-final.xcresult`（主要列表与大字号）、`pagination-additional.xcresult`（原详情与图片返回测试）、`pagination-complete.xcresult`（补充列表与完整入口区域）、`pagination-layout.xcresult`（窄卡片布局、大字号与图鉴返回）、`pagination-controls.xcresult`（显式 Form 按钮样式、补充列表与第一页按钮禁用）。截图导出存放在 `build/ios27-p0/pagination-evidence/`，这些构建产物不提交。

已检查普通字号分页截图、最大辅助字号纵向分页截图；测试路径使用 Reduce Motion 参数。未完成完整浅深色/对比度/Reduce Transparency 矩阵、VoiceOver 与键盘实测、真机或 Instruments 性能采样，不据此宣称完整发布验收。

专项 Apple Fidelity 暂评 79/100：平台 13/15、布局 12/15、语义 13/15、交互 18/20、动效材料 10/15、可访问性 6/10、实现性能 7/10。受未完成完整视觉与辅助技术验证的证据限制，此分数不是整款 App 评分。
