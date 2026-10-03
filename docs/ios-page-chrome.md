# iOS 一级页面 Chrome 规范

> 适用范围：`ios/RocoNative` 中的一级功能页面（图鉴、技能查询、异色收集、草系徽章、配队、属性克制、PVP 助手等）。
>
> 目标：统一页面标题、顶部导航按钮、底部系统搜索与滚动行为；优先使用 UIKit / SwiftUI 的系统控件，同时保证滚动时内容几何稳定、无 safe-area 跳动。

## 1. 已验证的基准

当前以图鉴页为交互基准，参考：

- `ios/RocoNative/Features/Encyclopedia/PetGrid.swift`
- `ios/RocoNative/SharedUI/CompanionScrollChrome.swift`
- `ios/RocoNative/Features/Encyclopedia/AlignedNavigation.swift`

这些文件中的“页面 chrome”行为经过真机反复调整。迁移其他页面时，应复用其原则，不要重新发明一套滚动栏逻辑。

图鉴专用的共享头像转场（`PortraitNavigationAnimator`、自定义 interactive pop 等）**不是**通用页面 chrome 规范的一部分，不要为了统一 UI 而改写或抽走。

## 2. 核心原则

### 2.1 页面标题属于内容，不属于导航栏

一级页面的大标题应放在页面的 `ScrollView` 内容顶部，例如：

```swift
VStack(alignment: .leading, spacing: 4) {
    Text("图鉴")
        .font(.largeTitle.bold())

    Text("\(results.count) 只精灵")
        .font(.subheadline.monospacedDigit())
        .foregroundStyle(.secondary)
}
```

要求：

- 标题和副标题正常随内容向上滚走。
- 不把一级页面标题做成 sticky header。
- 不使用 `.navigationTitle(...)` 来承载一级页面的大标题。
- 标题滚出屏幕后，不要折叠成小导航标题。
- 页面副标题可以是数量、状态或简短说明；没有副标题时可以省略。

正确视觉结构：

```text
[顶部系统导航行：返回/首页]                [筛选/操作]

图鉴
600 只精灵

[页面内容……]
```

滚动后，“图鉴 / 600 只精灵”应自然滚走，而不是固定在屏幕顶部。

### 2.2 系统 bar 的几何高度必须稳定

**一级页面滚动过程中，禁止通过隐藏整个 bar 来实现 chrome 消失。**

不要在普通滚动显隐中调用：

```swift
navigationController.setNavigationBarHidden(...)
navigationController.setToolbarHidden(...)
```

也不要通过切换整个 bar 的存在状态来制造动画。

原因：`UINavigationBar` / `UIToolbar` 的 hide/show 会触发 safe-area / adjusted content inset 重算，SwiftUI `ScrollView` 会发生明显的整体上移或下移。用户看到的表现是标题、数量、列表突然“补位”或“被顶开”。

**规范：bar 始终 mounted，只显隐 bar 内部的交互控件。**

### 2.3 顶部按钮：移除 item，不隐藏导航栏

滚动时：

- `UINavigationBar` 本身保持可见且保留高度。
- 只移除 `leftBarButtonItem` / `rightBarButtonItem`。
- 停止滚动后恢复原来的 item。
- 恢复时继续使用系统 `UINavigationItem` 动画。

参考图鉴当前实现：

```swift
if shouldShow {
    owner.navigationItem.setLeftBarButton(leadingItem, animated: animated)
    owner.navigationItem.setRightBarButton(filterItem, animated: animated)
} else {
    owner.navigationItem.setLeftBarButton(nil, animated: animated)
    owner.navigationItem.setRightBarButton(nil, animated: animated)
}
```

注意：

- 保存原始 item 引用，再恢复同一个 item。
- 不要因为按钮消失而让导航栏高度改变。
- 不要把系统按钮替换成手工绘制的 Liquid Glass 仿制品。

### 2.4 底部搜索：移除 placement item，不隐藏 toolbar

搜索继续使用系统 `UISearchController` + integrated placement：

```swift
owner.navigationItem.searchController = searchController
owner.navigationItem.preferredSearchBarPlacement = .integrated
owner.navigationItem.searchBarPlacementAllowsToolbarIntegration = true
owner.navigationItem.hidesSearchBarWhenScrolling = false

let searchItem = owner.navigationItem.searchBarPlacementBarButtonItem
owner.toolbarItems = [
    searchItem,
    UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
]
```

滚动时：

- `UIToolbar` 本身始终保留。
- 只从 `owner.toolbarItems` 中移除 `searchBarPlacementBarButtonItem`。
- 保留 flexible-space item，使 toolbar 仍然有稳定布局。
- 停止滚动后把**同一个** search placement item 恢复。
- toolbar 的 safe-area 高度不能变化。

参考模式：

```swift
if shouldShow {
    owner.setToolbarItems([searchItem, toolbarSpacer], animated: animated)
} else {
    owner.setToolbarItems([toolbarSpacer], animated: animated)
}
```

不要尝试仅修改：

```swift
searchController.searchBar.alpha
```

integrated search 的真实 view 层级由 UIKit 管理，可能被 re-parent / reset；实际可靠的控制点是 `searchBarPlacementBarButtonItem`。

## 3. 滚动状态

SwiftUI 页面负责提供“正在滚动还是已停止”的粗粒度状态：

```swift
@State private var chromeVisible = true

.onScrollPhaseChange { _, phase, _ in
    chromeVisible = phase == .idle
}
```

原则：

- 只在 scroll phase 边界更新。
- 不做每帧 GeometryReader / offset 采样。
- 不根据每一个像素手工计算 toolbar/nav bar 位移。
- 不自制连续 morph 动画。
- UIKit 负责系统 item 的真实视觉和交互。

当前策略：

- `.idle`：顶部按钮和底部搜索显示。
- dragging / decelerating：顶部按钮和底部搜索消失。
- 搜索正在激活，或 query 非空时：搜索 chrome 保持显示，避免输入过程中控件被移走。

## 3.1 嵌套导航页面的归属规则

如果一级页面内部为了特殊详情转场而持有自己的 `UINavigationController`，**一级页面 chrome 仍必须属于外层首页 NavigationStack**。

图鉴就是这个例子：

```text
首页 NavigationStack（拥有一级页面 chrome）
├── 返回首页
├── 筛选
├── 底部搜索
└── CatalogNavigationPage
    └── 私有 CatalogNavigationController（不显示自己的 bar）
        ├── 图鉴 Grid
        └── PetDetail（只负责内部 push/pop 与共享头像动画）
```

要求：

- 首页 ↔ 一级页面：使用外层导航容器的系统 bar 和 interactive pop。
- 一级页面内部特殊详情：可以保留私有导航控制器，但私有导航栏 / toolbar 默认隐藏。
- 不要把一级页面的返回、筛选、搜索挂到私有导航控制器，否则外层 interactive pop 时这些控件会作为页面内容一起横向移动，与其他一级页面不一致。
- 私有导航需要详情返回按钮时，优先让外层 bar 的 leading item 临时改为“返回内部详情”，而不是再显示第二条导航栏。
- 外层与内层导航手势必须互斥：内部详情存在时禁用“返回首页”的外层 pop；回到一级根页面后再恢复。

## 4. 为什么不用 `hidesBarsOnSwipe`

不要把 `UINavigationController.hidesBarsOnSwipe` 作为这个项目一级 SwiftUI 页面默认实现。

图鉴的层级是 SwiftUI `ScrollView` 嵌在 UIKit navigation controller 中，实测系统 swipe-bar gesture 没有稳定接管滚动，因此出现过“无论怎么滑按钮都不消失”的情况。

本项目的已验证策略是：

1. SwiftUI 用 `onScrollPhaseChange` 识别 phase；
2. UIKit 保持 bar 几何；
3. 只添加/移除系统 item。

## 5. Liquid Glass / 系统控件约束

优先使用 iOS 系统控件和系统 chrome：

- `UIBarButtonItem`
- `UIMenu`
- `UISearchController`
- `searchBarPlacementBarButtonItem`
- 系统 toolbar / navigation bar

不要为了“更像系统”而手工实现：

- 模拟玻璃背景
- blur + stroke + shadow 组合
- 透明 nav anchor + 全屏 overlay
- 手工坐标转换的菜单锚点
- 自制搜索框去模拟系统 search morph

内容区域（属性 badge、卡片、游戏素材等）可以有项目自己的视觉风格；系统 chrome 不要仿制。

## 6. 推荐的公共抽象

图鉴与技能查询现在共用 `CompanionScrollChrome.swift`。其他一级页面应直接复用这个共享实现，不再新增页面专用的 navigation/search chrome bridge。

推荐目标（名称可按现有目录规范调整）：

```text
ios/RocoNative/Shared/UI/
├── CompanionPageHeader.swift
└── CompanionScrollChrome.swift
```

### `CompanionPageHeader`

职责仅限内容标题：

- `title`
- 可选 `subtitle`
- 统一字体、间距、accessibility header
- 必须放在 `ScrollView` 内容内

它不管理 navigation bar，不 sticky。

### `CompanionScrollChrome`

职责：

- 接收 `visible`
- 可选系统搜索绑定
- 可选 leading/trailing bar items
- 可选 trailing `UIMenu`
- 保持 nav bar / toolbar mounted
- 通过增删 item 控制视觉显隐
- 搜索激活/非空 query 时保护搜索 UI
- 处理 attach / detach 生命周期

不要让这个抽象接管图鉴的共享头像转场、业务筛选逻辑或页面内容布局。

## 7. 页面迁移建议

优先迁移与图鉴结构最接近的页面：

1. `SkillsView.swift`（已有 `.searchable`）
2. `ShinyCollectionView.swift`（已有 `.searchable`）
3. `GrassBadgeView.swift`（已有 `.searchable`）

这三页确认真机交互一致后，再处理：

- `TeamBuilderView.swift`
- `TypeMatchupView.swift`
- `PVPBattleView.swift`
- 其他一级页面

不是所有页面都必须有搜索或筛选。统一的是**结构和显隐规则**：

- 有搜索：使用系统 integrated search + placement item。
- 无搜索：不创建搜索 item。
- 有筛选：使用系统 bar item / `UIMenu`。
- 无筛选：不创建多余按钮。

详情页、编辑 sheet、picker 页面可以继续使用正常 `.navigationTitle` / toolbar；本规范重点约束“一级功能入口页面”。

## 8. 禁止的回归

修改一级页面 chrome 时，不得重新引入以下行为：

- ❌ 滚动时 `setNavigationBarHidden(true)`
- ❌ 滚动时 `setToolbarHidden(true)`
- ❌ 标题因为 bar 显隐突然向上/向下跳
- ❌ 把一级页面标题固定成永不消失的标题栏
- ❌ 标题滚走后自动折叠成导航栏小标题
- ❌ 用 `searchBar.alpha` 当作 integrated search 的主要显隐手段
- ❌ 用透明 anchor + overlay 伪造系统 filter/search
- ❌ 为滚动 chrome 做逐帧 geometry 采样
- ❌ 为了统一 chrome 改坏图鉴的 `PortraitNavigationAnimator`

## 9. 真机验收标准

一级页面改造后，至少手测以下场景：

1. **初始状态**
   - 标题、副标题位于内容顶部。
   - 顶部系统按钮显示。
   - 有搜索时，底部系统搜索显示。

2. **轻微开始滚动**
   - 顶部按钮消失。
   - 底部搜索消失。
   - 页面内容没有突然补位或跳动。

3. **持续滚动**
   - 标题 / 副标题随内容自然滚出屏幕。
   - 列表、网格位置连续，无 safe-area 跳变。

4. **停止滚动**
   - 顶部按钮恢复。
   - 底部搜索恢复。
   - 恢复时页面内容位置不发生突兀位移。

5. **列表中部反复滚动 / 停止**
   - 不应出现整个页面向上或向下跳。

6. **搜索**
   - 点击系统搜索可正常输入。
   - 搜索激活或 query 非空时，搜索控件不会在用户输入过程中消失。
   - 取消/清空后恢复正常滚动显隐策略。

7. **导航**
   - 进入详情页时系统返回按钮正常。
   - 返回一级页面后 chrome 状态正常。
   - 图鉴共享头像 push/pop 转场保持原有手感。

## 10. Codex 执行规则

当任务涉及 iOS 一级页面 UI、搜索栏、导航按钮、滚动标题或 toolbar 时：

1. 先阅读本文件。
2. 以图鉴当前实现为行为基准。
3. 先确认修改是否会改变 navigation bar / toolbar 的几何高度。
4. 如果会改变 safe area，默认视为不符合本规范，除非需求明确要求。
5. 优先抽共享组件，不复制整份图鉴 bridge。
6. 不顺手重构图鉴共享头像转场。
7. 修改完成后说明：
   - 哪些 bar 始终 mounted；
   - 哪些 item 在滚动时被移除/恢复；
   - 是否改变 safe area；
   - 哪些页面已迁移；
   - 需要真机重点验收什么。

一句话原则：

> **一级页面标题属于滚动内容；系统 navigation bar 与 toolbar 永不因普通滚动改变几何高度；滚动时只隐藏/恢复其中的系统 item，避免任何 safe-area 跳动。**
