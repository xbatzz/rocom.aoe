# 当前项目功能地图

本文用于个人版改造前的功能盘点，目标是在不触碰业务代码、`public/data` 和 `scripts` 的前提下，明确当前页面结构、数据来源和后续改造风险。项目是 Vue 3 + Vite + TypeScript 应用，页面采用 `src/pages` 文件路由；基础游戏数据集中在 `public/data`，转换与同步脚本在 `scripts`。

## 页面与功能总览

| 功能 | 页面路径 | 主要文件 | 使用的数据文件 | 首页核心入口 | 更多工具 | 修改风险 |
| --- | --- | --- | --- | --- | --- | --- |
| 首页 | `/` | `src/pages/index.vue`、`src/features/my-home/MyHomeDashboard.vue` | 无 | 是 | 否 | 中 |
| 图鉴 | `/encyclopedia` | `src/pages/encyclopedia.vue`、`src/components/FriendPortrait.vue`、`src/lib/petHandbook.ts`、`src/lib/bloodline.ts`、`src/lib/petImplementation.ts` | `public/data/Pets.json`、`public/data/bloodline_index.json`、`public/assets/webp/friends/` | 是 | 否 | 高 |
| 宠物详情 | `/pets/:id` | `src/pages/pets/[id].vue`、`src/components/FriendPortrait.vue`、`src/components/SkillIcon.vue`、`src/lib/handbookProgress/*` | `public/data/pets/{id}.json`、`Pets.json`、`types.json`、`moves.json`、`items.json`、`handbook-rewards.json`、`handbook-topic-skill-names.json`、`tables/PET_HANDBOOK.json` | 否，作为图鉴详情页 | 否 | 高 |
| 属性关系/属性克制 | `/attributes` | `src/pages/attributes.vue`、`src/features/battle-query/TypeRelationCards.vue`、`src/features/battle-query/DualDefenseMatchupCards.vue`、`src/features/battle-query/DualOffensiveCoverageCards.vue`、`src/features/battle-query/typeDefenseMatchup.ts` | `public/data/types.json`、`public/data/BinData/TYPE_DICTIONARY.json` | 是，高频战斗查询 | 可保留入口 | 中 |
| 技能 | `/skills`；相关能力也分布在 `/table`、`/pets/:id`、`/team` | `src/pages/skills.vue`、`src/features/skills/SkillResultCard.vue`、`src/features/skills/skillAdapter.ts`、`src/pages/table.vue`、`src/pages/pets/[id].vue`、`src/pages/team.vue`、`src/components/SkillIcon.vue` | `public/data/moves.json`、`public/data/PetSkillIndex.json`、`public/data/pets/{id}.json` | 是 | 可同时归入更多工具 | 中 |
| PVP 对位助手 | `/pvp` | `src/pages/pvp.vue`、`src/lib/teamStorage.ts`、`src/lib/teamAnalysis.ts`、`src/lib/petHandbook.ts`、`src/lib/statCalculator.ts` | `public/data/Pets.json`、`public/data/types.json`、`public/data/personalities.json`、`localStorage: rocom.team-builder.v1` | 是，轻量对位参考 | 否 | 中 |
| 实战属性计算器 | `/stats` | `src/pages/stats.vue`、`src/lib/statCalculator.ts`、`src/lib/petHandbook.ts` | `public/data/Pets.json` | 否，作为 PVP 辅助工具 | 是 | 低 |
| 配队/配对规划 | `/team` | `src/pages/team.vue`、`src/lib/teamAnalysis.ts`、`src/lib/statCalculator.ts` | `Pets.json`、`personalities.json`、`magic_items.json`、`types.json`、`moves.json`、`pets/{id}.json`、`localStorage: rocom.team-builder.v1` | 可作为核心入口 | 否 | 高 |
| 配种 | `/breeding` | `src/pages/breeding.vue`、`src/lib/eggGroups.ts`、`src/lib/petImplementation.ts` | `Pets.json`、`tables/HOME_PET_LAY_EGG_RATE_CONF.json` | 可保留 | 否 | 中 |
| 查蛋 | 当前无独立路由；能力集中在 `/incubate` | `src/pages/incubate.vue` | `Pets.json` 中的 `breeding`、`evolves_from_id`、身高体重与孵化数据 | 否，建议并入孵蛋/更多工具 | 是 | 低 |
| 孵蛋 | `/incubate` | `src/pages/incubate.vue`、`src/components/FriendPortrait.vue`、`src/lib/petImplementation.ts` | `Pets.json` | 否，除非个人高频使用 | 是 | 中 |
| 星图 | `/egggroup` | `src/pages/egggroup.vue`、`src/lib/eggGroups.ts`、`src/lib/petHandbook.ts` | `Pets.json`，ECharts 图布局 | 否 | 是 | 中 |
| 表格 | `/table` | `src/pages/table.vue`、`src/components/FriendPortrait.vue`、`src/lib/petHandbook.ts`、`src/lib/petImplementation.ts`、`src/lib/eggGroups.ts` | `Pets.json`、`PetSkillIndex.json` | 否，偏高级筛选 | 是 | 高 |
| 图鉴进度 | `/handbook-progress` | `src/pages/handbook-progress.vue`、`src/lib/handbookProgress/*` | `tables/PET_HANDBOOK.json`、`Pets.json`、`handbook-rewards.json`、`handbook-topic-skill-names.json`、`localStorage: rocom_handbook_progress` | 否，个人路线图暂不以打卡/进度为核心 | 是 | 中 |
| 道具 | `/items` | `src/pages/items.vue` | `items.json`、`public/assets/webp/items/` | 否 | 是 | 低 |

## 首页与导航现状

首页 `src/pages/index.vue` 当前通过 `src/features/my-home/MyHomeDashboard.vue` 突出四个核心入口：属性查询、图鉴、技能查询、PVP 对位助手；“更多工具”区域保留实战属性、配队、配种、孵蛋/查蛋、星图、宠物表格、道具、图鉴进度。侧边栏 `src/components/Sidebar.vue` 暴露全部站内页面：首页、图鉴、技能、PVP、实战属性、图鉴进度、表格、配队、配种、孵蛋、星图、属性、道具。

按 `docs/MY_ROADMAP.md` 的个人版方向，首页更适合优先放“属性克制、图鉴搜索、技能搜索”。配队/PVP 可以作为核心或 Coming Soon 入口；配种、孵蛋、查蛋、星图、表格、道具、图鉴进度更适合收进“更多工具”。

## 技能功能现状

项目当前已有第一版独立 `/skills` 页面，用于查询技能本身信息。其他技能相关能力仍分布在：

- `/table`：通过 `PetSkillIndex.json` 做技能来源筛选，支持自有技能、学习技能和技能列表搜索。
- `/pets/:id`：展示单个宠物的自有技能、学习技能、遗传技能、技能覆盖属性和高威力技能。
- `/team`：选择队伍宠物技能，并基于技能类别、覆盖和描述识别定位。

`/skills` 第一版只读取并展示技能本身，不展示拥有该技能的宠物完整列表，避免把技能池、技能石和血脉技能来源混在一起造成误导。当前已新增 `src/features/skills/skillAdapter.ts` 作为独立技能查询页的数据适配层，可将 `moves.json` 与 `PetSkillIndex.json` 整理为可搜索、可筛选的技能结果。

## PVP 对位助手现状

项目当前已有独立 `/pvp` 页面，用于轻量单宠对位参考。页面读取 `Pets.json` 与 `types.json`，并通过 `src/lib/teamStorage.ts` 安全读取配队页保存到 `localStorage: rocom.team-builder.v1` 的槽位宠物 ID，让我方宠物可以优先从已保存配队中选择；双方也都支持按名称、图鉴编号和属性手动搜索。

`/pvp` v0.2 展示双方属性、编号、总种族值、六项种族值、我方打对方与对方打我方的属性倍率，并接入实战速度线参考。速度线仅支持速度个体值 0-10 与速度性格修正：无修正、加速 +20%、减速 -10%，计算复用 `src/lib/statCalculator.ts` 的分步四舍五入规则。从“我的配队”选择我方宠物时，页面会读取该槽位保存的 `individualValues.speed` 和 `personalityId`，自动填入我方速度线；该读取只用于当前 PVP 速度参考，不反写队伍构筑。对方速度区域提供满速、满个体、无速、减速 4 种常见速度线速览，用于估算而不代表对方真实配置。该页面明确不包含真实伤害计算、胜率预测、配招推荐、完整战斗模拟和队伍导入导出。

## 配队构筑现状

`/team` 保留原项目六人配队能力，并在构筑配置中记录每个槽位的性格、血脉、技能、定位与个体值。个体值保存字段为 `individualValues`，包含 `hp`、`phyAtk`、`magAtk`、`phyDef`、`magDef`、`speed` 六项，每项范围 0-10，最多 3 项大于 0，校验和归一化复用 `src/lib/statCalculator.ts`。旧的本地队伍数据或旧分享链接没有 `individualValues` 时会默认补齐六项 0。

## 实战属性计算器现状

项目当前已有第一版独立 `/stats` 页面，用于将宠物基础种族值换算为 PVP 实战属性。页面读取 `Pets.json`，支持按名称、图鉴编号和属性选择已实装宠物，展示生命、物攻、魔攻、物防、魔防、速度与种族值总和。

`/stats` v0.1 支持六项个体值输入，每项范围为 0-10，最多 3 项个体值可以大于 0；性格增强属性按 +20% 计算，性格削弱属性按 -10% 计算，增强和削弱属性不能相同。计算由 `src/lib/statCalculator.ts` 提供，生命和其他属性均按“每次乘法产生小数后立即四舍五入”的规则分步计算。

该页面暂不支持伤害计算、胜率预测、技能、血脉、装备和特性综合计算，也暂不接入 `/pvp` 或 `/team`。

## 数据与脚本地图

基础数据入口：

- `public/data/Pets.json`：图鉴、表格、配队、PVP、实战属性、配种、孵蛋、星图等页面的核心宠物索引。
- `public/data/pets/{id}.json`：宠物详情和配队按需加载的详情。
- `public/data/types.json`：属性基础数据。
- `public/data/moves.json`：技能列表。
- `public/data/PetSkillIndex.json`：技能筛选索引。
- `public/data/items.json`：道具列表。
- `public/data/tables/*.json`：从 `BinData` 镜像出的部分原始表。
- `public/data/BinData/*.json`：上游/游戏包原始 JSON 表。

脚本：

- `scripts/sync-pet-data.mjs`：由 `yarn sync:pet-data` 调用，从 `BinData` 和 `types.json` 生成 `Pets.json`、`pets/*.json`、`items.json`、图鉴奖励与技能索引等。
- `scripts/export_pet_json.py`：从本地游戏 `Data/Bin` 解包导出 JSON 的辅助脚本。
- `scripts/png_to_webp.py`：图片格式转换辅助脚本。
- `scripts/test-handbook-progress.mjs`：图鉴进度合并逻辑的轻量测试。

## 风险说明

- 高风险：`src/pages/pets/[id].vue`、`src/pages/table.vue`、`src/pages/team.vue`、`src/pages/encyclopedia.vue`。这些文件体量大、数据依赖多、上游也可能频繁改动。
- 中风险：`src/pages/index.vue`、`src/pages/attributes.vue`、`src/pages/breeding.vue`、`src/pages/incubate.vue`、`src/pages/egggroup.vue`、`src/pages/handbook-progress.vue`。适合通过新增 feature 组件后轻量接入。
- 低风险：`src/pages/items.vue`、新增 `docs/*`、新增 `src/features/*`、新增 `src/custom` 或 `public/my-data`。

## 改造建议

1. 首页改造先走新增组件路线：新增 `src/features/my-home`，再在 `src/pages/index.vue` 轻量接入。
2. 属性、图鉴、技能查询统一放入 `src/features/battle-query`，减少直接改核心页面；当前属性页已使用 `TypeRelationCards.vue` 展示四象限关系，并通过 `DualDefenseMatchupCards.vue`、`DualOffensiveCoverageCards.vue` 与 `typeDefenseMatchup.ts` 支持双属性防守查询和打击覆盖展示。
3. 技能独立查询页的数据适配逻辑和轻量展示组件放在 `src/features/skills`，`/skills` 页面直接复用该适配层，避免改动 `/pets/:id`、`/table`、`/team`。
4. PVP 继续保持独立页面和轻量辅助定位，队伍导入导出不要写入 `public/data`。
5. `public/data` 和 `scripts` 继续视为上游基础数据层，不为了个人功能直接修改。
6. “更多工具”建议承载配种、孵蛋/查蛋、星图、表格、道具、图鉴进度，核心首页保持战斗查询优先。
