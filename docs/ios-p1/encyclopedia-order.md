# iOS 与 Web 图鉴顺序对齐

2026-10-03。

## 原因

Web `src/pages/encyclopedia.vue` 默认排序为 `id`，比较 `getPetHandbookId(pet)`（`species_id ?? id`），相同时比较配置 ID。iOS `PetListQuery` 的“图鉴顺序”原先比较 canonical `ordinal`；`scripts/ios/normalize.mjs` 实际按 `nameZh` 的 Unicode 顺序生成该字段，因此两端默认排序语义不同。当前数据中 Web 首项为迪莫（配置 3004，图鉴 1），iOS 原先首项为霹雳迪迪（配置 3737，图鉴 370）。

另一处差异是 Web 在筛选后调用 `collapseDuplicateLeaderConfigurations`，iOS 原先保留全部重复首领配置。两端已实装公开配置集合相同，均为 630 条；Web 折叠后显示 600 条。

## 修正

- 新增 `PetCatalogPresentation`，默认排序按 `speciesId`、`petId` 升序，保留真实图鉴编号 `handbookId` 的显示与搜索语义。
- 列表在搜索/筛选之后、排序之前折叠重复首领。按 species、中文名、资源标识分组；代表选择遵循 Web 的实装优先、有种族值优先、较小配置 ID 优先。普通精灵与不同首领形态保持独立。
- 数量分母按折叠后的完整公开已实装目录计算。当前默认显示 600 / 600。
- canonical 数据、生成器及 `ContentStore.orderedPets` 保留现有存储顺序，导航测试的可见源改从实际图鉴展示顺序选取。

## 验证

`scripts/ios-tests/generate-catalog-fixtures.mjs` 直接执行 Web 的 TypeScript helper，并提取 Vue 列表的排序比较函数，生成 `WebCatalogFixtures.json`。五组样本覆盖完整默认目录、首领、非首领、草属性及筛选后替代首领；Swift 对照全部结果 ID，并用倒序输入确认展示顺序稳定。默认 600 条逐项一致。

通过：

- `swift test --package-path ios/Packages/RocoContent --filter PetCatalogPresentationTests`：3 项测试，含真实 Web 对照、无真实图鉴编号/ordinal 边界、首领代表选择优先级。
- `yarn type-check`、`yarn build`。
- 无签名 generic iOS build。
- Simulator `RocoNativeHostTests/NavigationLifetimeTests/testRealContentSourceAndHeroShareBitmap`：真实迪莫列表源与详情共用位图，1 项通过。
- Simulator 图鉴首屏截图复查：[截图](screenshots/encyclopedia-order.png)。

保留既有 Web 大 chunk 警告与 Xcode 无 AppIntents dependency 提示。未进行真机手势体验验收。
