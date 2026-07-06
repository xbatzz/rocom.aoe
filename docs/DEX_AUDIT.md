# 图鉴页面现状审计

本文记录当前图鉴相关页面、数据来源、搜索筛选能力和后续低风险优化方向。仅做分析，不修改业务代码、`public/data`、`scripts` 或锁文件。

## 当前图鉴功能地图

- 页面路径：图鉴列表为 `/encyclopedia`，宠物详情为 `/pets/:id`。
- 主文件：`src/pages/encyclopedia.vue`；详情页为 `src/pages/pets/[id].vue`。
- 相关组件：`FriendPortrait.vue` 用于宠物头像，`SkillIcon.vue` 用于详情页技能/特性图标；页面还使用 UI 组件 `Card`、`Input`、`Select`、`Badge`、`Tabs`、`Dialog`、`HoverCard`、`Skeleton` 等。
- 相关工具：`src/lib/petHandbook.ts` 处理图鉴编号和关键词匹配；`src/lib/bloodline.ts` 处理血脉技能命中；`src/lib/petImplementation.ts` 处理实装状态、蛋组摘要。
- 列表数据：`public/data/Pets.json`、`public/data/bloodline_index.json`、`public/assets/webp/friends/JL_{name}.webp`。
- 详情数据：`public/data/pets/{id}.json`、`types.json`、`Pets.json`、`moves.json`、`items.json`、`handbook-rewards.json`、`tables/PET_HANDBOOK.json`。

## 当前数据结构摘要

`Pets.json` 是列表核心索引，当前约 1065 条。主要字段包括：

- 基础字段：`id`、`species_id`、`name`、`form`、`localized.zh.name`、`implemented`。
- 属性字段：`main_type`、`sub_type`、`default_legacy_type`，均含 `id`、`name`、`localized.zh`。
- 战斗倾向：`preferred_attack_style`，页面显示为双修、魔攻、物攻等。
- 种族值字段：`base_hp`、`base_phy_atk`、`base_mag_atk`、`base_phy_def`、`base_mag_def`、`base_spd`。
- 进化/首领字段：`evolves_from_id`、`leader_potential`、`is_leader_form`。
- 繁育字段：`breeding`、`breeding_profile`，含蛋组、性别比例、孵化、身高体重等。
- 详情扩展：`species`、`trait`、`move_pool`、`move_stones`、`legacy_moves`、`evolution_tree`、`world_profile`、`catch_info`。
- 技能字段：技能含 `id`、`name`、`icon_id`、`move_type`、`localized.zh.name`、`localized.zh.description`、`move_category`、`energy_cost`、`power`、`description`。

## 当前搜索/筛选能力

已支持：

- 列表关键词搜索：`src/pages/encyclopedia.vue` 的 `filteredPets` 调用 `matchesPetKeyword()`。
- 名称搜索：支持中文名、英文/内部 `name`、`form`。
- 编号搜索：支持 `species_id`/图鉴编号，含补零编号；不等同于稳定搜索所有内部 `id`。
- 属性搜索：关键词支持主属性、副属性、默认遗传属性中文；也有独立属性筛选。
- 血脉技能搜索：通过 `bloodline_index.json` 匹配血脉技能名、技能属性、技能 ID。
- 详情页技能搜索：在 `/pets/:id` 内可按技能名称、描述、技能 ID 搜索自有技能和学习技能。

不支持或支持有限：

- 图鉴列表不直接搜索 `move_pool` / `move_stones` 中的自有技能和学习技能。
- 图鉴列表没有按技能类型、技能分类、能耗、威力筛选。
- 图鉴列表没有按种族值区间、蛋组、刷新地点、捕捉难度筛选。
- 编号搜索主要面向图鉴编号，不是所有详情 JSON 文件名 `id` 的完整搜索。

筛选与排序：

- 筛选：属性、攻击倾向、阶段/特殊状态、实装状态。
- 阶段/特殊：首领形态、可转首领、基础形态、已进化、可继续进化。
- 排序：图鉴编号、总种族值、速度、名称。
- 分页：每页 24、48、72 条，筛选状态会同步到 URL query。

## 当前 UI/体验问题

- 搜索入口存在且带图标，但和五个筛选下拉放在同一排；桌面信息密度高，移动端会纵向堆叠较长。
- 搜索提示写有“血脉技能”，但用户可能误以为能搜索全部技能；实际列表只搜索血脉技能索引。
- 卡片适合浏览基础信息：头像、编号、名称、攻击倾向、属性、遗传属性、总种族值、速度、最高单项、进化/首领/血脉命中。
- 卡片对战斗快速查询仍偏“图鉴浏览”，缺少更突出的属性、速度、攻击倾向和技能入口。
- 手机端布局基本可用：列表单列、筛选控件堆叠、详情页 tabs 和技能卡片有移动端布局；但筛选区较长，快速二次搜索不够轻。
- iPad/桌面上卡片网格清楚，但首屏摘要和筛选占据空间，搜索优先级还有提升空间。

详情页展示内容较完整：

- 顶部：头像、图鉴任务、编号、属性、遗传属性、首领/未实装、名称、物种、攻击倾向、类型描述。
- 摘要：总种族值、最高单项、自有技能数量、技能覆盖属性。
- 档案：介绍、栖息地、刷新与培育、蛋组、孵化时长、身高体重。
- 捕捉：难度、保底次数、推荐用球、捕捉提示。
- 战斗：特性、技能摘要、进化链、雷达图、六维种族值、技能覆盖、高威力技能、遗传技能索引。
- 技能 tabs：自有技能、学习技能，支持名称/描述/ID 搜索、属性筛选、分类筛选。
- 图鉴任务：读取 `PET_HANDBOOK` 和奖励数据，进度来自本地 handbook progress 逻辑。

## 低风险优化建议

第一轮建议：

- 强化 `/encyclopedia` 搜索区，文案明确“名称 / 图鉴编号 / 属性 / 血脉技能”。
- 增加更清晰的搜索结果状态和 active filter chips，降低移动端筛选成本。
- 优化卡片信息层级：把属性、速度、攻击倾向、总种族值做成更适合快速扫视的战斗摘要。
- 优先新增 `src/features/battle-query` 或 `src/features/dex` 组件，再轻量接入页面，减少直接大改主文件。

第二轮可以做：

- 规划独立技能查询入口，复用 `moves.json`、`PetSkillIndex.json` 和详情页技能展示模式。
- 给图鉴列表增加可选的“战斗视图 / 图鉴视图”切换。
- 增加按种族值区间、技能覆盖属性、蛋组等高级筛选，但先做适配层，避免改数据结构。

暂时不要碰：

- 不要手工修改 `public/data/Pets.json`、`public/data/pets/*.json`、`bloodline_index.json`、`PetSkillIndex.json`。
- 不要重写 `src/pages/pets/[id].vue`，该文件体量大、数据依赖多，上游冲突风险高。
- 不要把个人收藏、备注、队伍数据写入 `public/data`。
- 不要把图鉴任务/打卡进度作为个人版核心方向。

## 后续实施顺序

1. 先做图鉴搜索区与卡片层级的小步 UI 优化，保持现有筛选和 URL query 行为。
2. 抽出低风险展示组件，例如 `src/features/battle-query/DexQuickSearch.vue` 或 `src/features/dex/PetResultCard.vue`。
3. 再规划独立技能查询页或组件，避免把技能搜索硬塞进图鉴列表。
4. 最后再考虑高级筛选和详情页信息重排；详情页改动应小步进行，每次只触碰一个区域。
