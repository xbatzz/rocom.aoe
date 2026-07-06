# 技能查询现状审计

本文记录当前项目技能相关功能、数据来源和低风险优化方向。仅做分析，不修改业务代码、`public/data`、`scripts` 或锁文件。

## 当前技能功能地图

- 当前已新增第一版独立 `/skills` 技能页面，用于查询技能本身信息。
- 技能能力主要分布在三个页面：
  - `/skills`：技能百科查询页，展示全局技能名称、ID、属性、分类、能耗、威力和描述。
  - `/pets/:id`：宠物详情页，展示单只宠物的自有技能、学习技能、遗传技能、技能覆盖和高威力技能。
  - `/table`：宠物表格页，支持按某个技能筛选拥有该技能的宠物。
  - `/team`：配队页，支持为队伍宠物选择技能，并基于技能类别、覆盖和描述识别定位。
- 主要文件：
  - `src/pages/skills.vue`
  - `src/features/skills/skillAdapter.ts`
  - `src/features/skills/SkillResultCard.vue`
  - `src/pages/pets/[id].vue`
  - `src/pages/table.vue`
  - `src/pages/team.vue`
  - `src/components/SkillIcon.vue`
  - `src/lib/interface.ts`
  - `src/lib/teamAnalysis.ts`

## 技能数据来源

- `public/data/moves.json`：全局技能字典，约 475 条。字段包括 `id`、`name`、`move_type`、`localized.zh.name`、`localized.zh.description`、`move_category`、`energy_cost`、`power`、`description`。
- `public/data/PetSkillIndex.json`：宠物技能索引，包含 `entries` 和 `skills`。`entries` 记录每只宠物的 `move_pool_ids`、`move_stone_ids`；`skills` 是轻量技能目录，含 `id`、`name`、`type_label`、`move_category`。
- `public/data/pets/{id}.json`：宠物详情，包含完整 `move_pool`、`move_stones`、`legacy_moves`。这些技能对象含图标、中文描述、属性、分类、能耗和威力。
- `public/data/bloodline_index.json`：图鉴列表用于血脉技能关键词命中。
- `public/data/handbook-topic-skill-names.json`：图鉴任务文本中技能 ID 到技能名的映射。
- `public/assets/webp/items/{icon_id}.webp`：`SkillIcon.vue` 使用的技能/特性图标资源。

## 当前技能搜索/筛选能力

宠物详情页 `/pets/:id`：

- 支持在自有技能和学习技能中搜索技能名称、描述、技能 ID。
- 支持按技能属性筛选。
- 支持按技能分类筛选：物理输出、魔法输出、防御、状态等。
- 不支持威力区间或能耗区间筛选。
- 自有技能和学习技能共用同一组筛选状态，因此切换 tab 时筛选条件会延续。
- 遗传技能索引展示血脉技能，但不是同一套可搜索技能列表。

表格页 `/table`：

- 支持通过技能选择器搜索技能名称、技能 ID、属性、分类。
- 支持按技能来源筛选宠物：全部技能、自有技能、学习技能。
- 结果是“拥有该技能的宠物列表”，不是技能详情列表。
- 技能选择器使用 `PetSkillIndex.json` 的轻量 `skills` 目录，不包含技能描述、能耗、威力。

图鉴页 `/encyclopedia`：

- 搜索提示包含血脉技能；实际通过 `bloodline_index.json` 命中血脉技能名称、属性、技能 ID。
- 不直接搜索宠物详情里的自有技能或学习技能。

配队页 `/team`：

- 选择宠物后展示可选技能，来源包括技能池、技能石和当前血脉遗传技。
- 技能用于队伍定位识别、覆盖分析和基础伤害估算。
- 这是配队工作流中的技能选择，不适合作为通用技能查询入口。

## 当前 UI/体验问题

- 当前已有一个“输入技能名就看技能详情”的独立入口，但第一版不展示完整宠物反查。
- `/pets/:id` 的技能展示信息完整，适合查看单宠技能，但必须先进入某只宠物。
- `/table` 能跨宠物按技能筛选，但入口藏在表格筛选区，结果以宠物为中心，不以技能为中心。
- `PetSkillIndex.json` 的技能目录缺少描述、能耗、威力，导致表格页技能选择器只能做轻量筛选。
- `moves.json` 有全局技能详情，但未直接承载“哪些宠物拥有该技能”的完整来源关系，也不包含技能图标 `icon_id`。
- 手机端详情页技能卡片可读，但长列表筛选和跳转成本较高；战斗中快速查技能仍偏慢。

技能卡片当前展示字段：

- 技能图标。
- 中文技能名。
- 技能 ID。
- 英文/内部技能名。
- 中文描述。
- 技能属性。
- 技能分类。
- 能耗。
- 威力，`null` 显示为 `-`。

## 是否建议做独立技能查询页

建议做，但应低风险独立实现，不要重构现有详情页或表格页。

理由：

- 技能是个人版核心高频功能之一，和属性克制、图鉴同级。
- 当前已有数据足够支撑基础版技能页：`moves.json` 提供技能详情，`PetSkillIndex.json` 提供技能到宠物的反查关系。
- 独立页面可直接服务战斗查询：按名称、描述、ID、属性、分类、能耗、威力搜索，再展示关联宠物。
- 可以避免把技能查询塞进图鉴或表格页，降低与上游核心页面冲突。

当前落地状态：

- 已新增第一版 `/skills` 页面。
- 第一版只查询技能本身，不展示拥有该技能的宠物完整列表。
- `/skills` 会合并 `moves.json` 与 `PetSkillIndex.json.skills`：同名技能优先保留 `moves.json` 的主记录、英文名、描述、能耗、威力和分类，再用 `PetSkillIndex` / 宠物详情补充图标与补充来源 ID。
- `PetSkillIndex.json.entries` 仅在适配层中作为技能池/技能石统计和图标补齐索引备用，不混入血脉技能反查。
- `SkillSearchItem` 输出包含 `iconId`。适配层优先使用技能对象自带 `icon_id`；当目录技能缺少图标时，通过 `PetSkillIndex.json.entries` 定位少量宠物详情，从 `move_pool` / `move_stones` 中按技能 ID 或中文名补齐图标 ID。
- 合并后的搜索文本包含主 ID 和补充来源 ID，例如同名技能可同时通过 `134`、`#134`、`7040250` 或中文名命中同一条结果。
- 血脉技能应在后续反查设计中作为独立来源处理，不能直接算作宠物普通自带技能。

## 低风险优化建议

当前状态：已新增 `src/features/skills/skillAdapter.ts` 作为独立技能查询页的数据适配层，并已接入第一版 `/skills` 页面。页面可基于 `moves.json` 和 `PetSkillIndex.json` 生成技能搜索项，并支持关键词、属性、分类筛选。

第一轮建议：

- 继续打磨独立 `/skills` 页面，并优先在 `src/features/skills` 下新增展示组件。
- 只读取 `moves.json` 和 `PetSkillIndex.json`，不改生成数据。
- 支持技能名称、描述、ID 搜索。
- 支持属性、分类筛选。
- 展示技能卡片：名称、ID、属性、分类、能耗、威力、描述。

第二轮可以做：

- 基于 `PetSkillIndex.json` 反查拥有该技能的宠物数量和列表，并区分自有技能/学习技能。
- 增加能耗、威力区间筛选。
- 支持“只看攻击技能 / 状态技能 / 防御技能”快捷筛选。
- 从技能卡片跳转到拥有该技能的宠物，或带筛选参数跳转 `/table`。

暂时不要碰：

- 不要改 `public/data/moves.json`、`PetSkillIndex.json`、`pets/*.json`。
- 不要重写 `src/pages/pets/[id].vue` 的技能 tabs。
- 不要重写 `src/pages/table.vue` 的表格筛选逻辑。
- 不要把 PVP 伤害公式、队伍导入导出和技能查询混在第一版里。

## 后续实施顺序

1. 继续验证 `/skills` 第一版的搜索、筛选和移动端布局。
2. 增加能耗、威力等进阶筛选，但仍以技能本身查询为主。
3. 设计宠物反查的数据分层，明确区分自有技能、学习技能、技能石和血脉技能。
4. 再做关联宠物反查和跳转，不在第一版引入复杂计算。
5. 后续如接入 PVP 查询，应复用适配层，不把伤害公式写入技能页面。
