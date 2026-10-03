# 连续图鉴重设计（2026-10-03）

采用 standard profile：图片优先、轻量文字、原生控制层。网格与底部玻璃各自承担内容和操作层级。

## 当前控制层更新

以下控制层实现取代下文早期的底部左右按钮与全屏筛选方案；其余记录保留为历史验证。

- 筛选图标固定在系统导航栏右上角，以按钮边界为锚点使用 SwiftUI popover，compact adaptation 保持 popover；属性、形态、阶段、排序与升降序的二级选项在一级菜单左侧连续展开。形态显示“普通 / 首领”，点外部关闭。
- 搜索使用同一个输入框和玻璃表面，默认展开且不请求焦点。空词、未聚焦并手动向下滚动时，忽略 20pt 小幅调整，再在 100pt 距离内直接驱动连续 morph；聚焦或非空词时保持展开。
- 左下边缘固定，宽度、圆角、placeholder 和清除/取消控件随进度变化。点击圆形图标在同一交互中展开并通过官方 UITextField first-responder API 聚焦；空词取消时按原路径收回。safeAreaInset 保持搜索栏位于键盘上方。
- 使用 GlassEffectContainer、glassEffect、稳定 glassEffectID 和 glassEffectTransition；滚动进度不启动 spring。仅搜索时保护键盘焦点，不改变列表连续滚动或冻结 portrait transition。
- 最新 iPhone 18 Pro 验证：4 项针对控件的 UI 测试通过，覆盖默认展开不弹键盘、一次点击聚焦、键盘位置、浏览收起、非空词保留、筛选浮层与最大辅助字体；iOS 构建及独立连续进度检查通过。

## 实现

- `PetGrid.swift`：保留连续 LazyVGrid、lazy 图片所有权、预取及 portrait origin；增加图片占比，居中名称、真实图鉴编号和轻量属性图标。cell 不使用 material、blur、shadow 或卡片底板。
- `CatalogBottomControls.swift`：官方 GlassEffectContainer / glassEffect / glassEffectID / glassEffectTransition。筛选与排序胶囊锚定 leading safe-area 20pt，独立搜索圆按钮锚定 trailing safe-area 20pt；快速滚动时左侧原位缩为 52×52，右侧位置与尺寸不变；idle 恢复；compact badge 不影响按钮尺寸；搜索圆按钮通过同一 glass ID 扩展为单一输入面。收起输入保留搜索词，清除按钮仅清除搜索。
- `CatalogScrollSample.swift`：64pt 分段采样，超过 700pt/s 收缩，只对手动滚动生效，不逐帧写网格状态，不使用延时恢复。
- `CatalogFilterSheet.swift`：双属性、攻击倾向、首领形态、进化状态、技能及来源；图鉴编号/总种族值/速度/中文名排序。技能列表可按名称或 ID 搜索。
- `PetCatalogQuery.swift`：后台查询直接使用 ContentStore.catalogPets。首领筛选匹配 isLeader；leaderPotential 不参与条件。技能及来源必须匹配同一记录。保留原有编号搜索、稳定排序和首领重复配置归并。
- `AdvancedPetFilterView.swift`：移除旧实装筛选和状态文字。
- `NavigationTests.swift`、`PetCatalogPresentationTests.swift`：同步搜索入口，覆盖筛选、来源、连续滚动返回、空结果和最大辅助字体。

图鉴入口已由全屏弹层改为首页 NavigationLink，移除“功能首页”浮动按钮。CatalogNavigationPage / CatalogNavigationController 和 AlignedNavigation 的外围接线提供左上角返回及系统边缘返回；详情期间禁止外层返回，离开图鉴恢复原手势代理。未修改 portrait animator、内部详情 edge-pan、PortraitSurface、PortraitStore 或详情页；image-only shared portrait transition 保持冻结实现。未修改 Web 或生成游戏数据。

## 验证

- Xcode 27.0 / Swift 6.4 / iOS 27 Simulator 构建通过。
- `swift test --package-path ios/Packages/RocoContent --filter PetCatalogPresentationTests`：6 项通过。
- iPhone 18 Pro：8 个不同 UI 测试通过，覆盖底部筛选/搜索、连续网格详情返回、详情图片、辅助字体控制层；另对底部交互做重复验证。
- iPhone 18 Pro Max：浅色默认字号、深色最大辅助字体截图人工检查。最大辅助字体下胶囊标题简化为“筛选”，VoiceOver 标签仍为“筛选与排序”。图标保持合理尺寸，触控区域至少 44pt。
- Reduce Motion 路径覆盖；玻璃转场改用 identity，状态改变不使用动画。Reduce Transparency 提供不透明系统底色。
- SwiftUI 静态审计：0 high；medium 提示为固定图标/触控尺寸和保留的 GeometryReader 等，已检查相关布局。
- `git diff --check` 通过。

性能设计检查：cell 无视觉特效；滚动采样对象不发布逐帧变化；玻璃仅位于底部控制层；筛选后台执行。尚未采集真机 Instruments、帧率和峰值内存数据；快速滚动中的收缩/morph 连续轨迹仍需真机视觉确认。未做完整 VoiceOver、提高对比度及 Reduce Transparency 实机验收。

Apple Fidelity 暂评 84/100（平台 14/15、布局 14/15、原生语义 14/15、交互连续性 17/20、动效材质 12/15、可访问性 6/10、性能实现 7/10）。分数按未完成辅助技术验收的证据上限封顶，不代表完整发布或性能验收。

## 左右锚定与返回路径追加验证

- 几何测试验证 leading=20pt、trailing=20pt；展开/收缩左侧 minX 不变，搜索按钮 minX/width 不变，compact 为 52×52。
- 最后一排“迪莫”筛选结果在滚到底部时完整位于 controls 上方至少 16pt；32pt 内容底部留白叠加 safeAreaInset 的控制层占位。
- 左上角返回、图鉴根页系统边缘返回、详情按钮返回图鉴、随后技能页边缘返回均通过。
- 最大辅助字体与连续滚动原位返回再次通过。
- 初次嵌套导航验证发现默认外层手势代理拒绝隐藏导航栏的根页面。外围桥接改用受图鉴根状态约束的系统 edge recognizer 代理，并在离开页面时恢复原代理，最终首页/技能侧滑测试通过。
- 最终“详情侧滑→图鉴侧滑→首页”串联测试断言通过；XCTest 在冻结详情手势结束后仍出现两次各 60 秒的动画结束通知等待。实际 didShow 已完成、Grid input 已恢复；这项自动化通知限制没有被描述为消失，也未修改冻结 animator / detail edge-pan 来规避它。
- 本轮只做 iOS 验证，没有运行 Web build。真机滚动性能、交互取消及完整辅助技术验收仍未完成。
