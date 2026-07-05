# 当前项目功能地图

本文用于个人版改造前的功能盘点，目标是在不触碰业务代码、`public/data` 和 `scripts` 的前提下，明确当前页面结构、数据来源和后续改造风险。项目是 Vue 3 + Vite + TypeScript 应用，页面采用 `src/pages` 文件路由；基础游戏数据集中在 `public/data`，转换与同步脚本在 `scripts`。

## 页面与功能总览

| 功能 | 页面路径 | 主要文件 | 使用的数据文件 | 首页核心入口 | 更多工具 | 修改风险 |
| --- | --- | --- | --- | --- | --- | --- |
| 首页 | `/` | `src/pages/index.vue`、`src/components/Income.vue`、`src/components/FriendlyLinks.vue` | 友情链接接口 `https://api.aoe.top/api/friendly/links` | 是 | 否 | 中 |
| 图鉴 | `/encyclopedia` | `src/pages/encyclopedia.vue`、`src/components/FriendPortrait.vue`、`src/lib/petHandbook.ts`、`src/lib/bloodline.ts`、`src/lib/petImplementation.ts` | `public/data/Pets.json`、`public/data/bloodline_index.json`、`public/assets/webp/friends/` | 是 | 否 | 高 |
| 宠物详情 | `/pets/:id` | `src/pages/pets/[id].vue`、`src/components/FriendPortrait.vue`、`src/components/SkillIcon.vue`、`src/lib/handbookProgress/*` | `public/data/pets/{id}.json`、`Pets.json`、`types.json`、`moves.json`、`items.json`、`handbook-rewards.json`、`handbook-topic-skill-names.json`、`tables/PET_HANDBOOK.json` | 否，作为图鉴详情页 | 否 | 高 |
| 属性关系/属性克制 | `/attributes` | `src/pages/attributes.vue` | `public/data/types.json`、`public/data/BinData/TYPE_DICTIONARY.json` | 是，高频战斗查询 | 可保留入口 | 中 |
| 技能 | 当前无独立技能页；分布在 `/table`、`/pets/:id`、`/team` | `src/pages/table.vue`、`src/pages/pets/[id].vue`、`src/pages/team.vue`、`src/components/SkillIcon.vue` | `public/data/PetSkillIndex.json`、`public/data/moves.json`、`public/data/pets/{id}.json` | 是，建议新增独立入口 | 可同时归入更多工具 | 中 |
| 配队/配对规划 | `/team` | `src/pages/team.vue`、`src/lib/teamAnalysis.ts` | `Pets.json`、`personalities.json`、`magic_items.json`、`types.json`、`moves.json`、`pets/{id}.json`、`localStorage: rocom.team-builder.v1` | 可作为核心入口 | 否 | 高 |
| 配种 | `/breeding` | `src/pages/breeding.vue`、`src/lib/eggGroups.ts`、`src/lib/petImplementation.ts` | `Pets.json`、`tables/HOME_PET_LAY_EGG_RATE_CONF.json` | 可保留 | 否 | 中 |
| 查蛋 | 当前无独立路由；能力集中在 `/incubate` | `src/pages/incubate.vue` | `Pets.json` 中的 `breeding`、`evolves_from_id`、身高体重与孵化数据 | 否，建议并入孵蛋/更多工具 | 是 | 低 |
| 孵蛋 | `/incubate` | `src/pages/incubate.vue`、`src/components/FriendPortrait.vue`、`src/lib/petImplementation.ts` | `Pets.json` | 否，除非个人高频使用 | 是 | 中 |
| 星图 | `/egggroup` | `src/pages/egggroup.vue`、`src/lib/eggGroups.ts`、`src/lib/petHandbook.ts` | `Pets.json`，ECharts 图布局 | 否 | 是 | 中 |
| 表格 | `/table` | `src/pages/table.vue`、`src/components/FriendPortrait.vue`、`src/lib/petHandbook.ts`、`src/lib/petImplementation.ts`、`src/lib/eggGroups.ts` | `Pets.json`、`PetSkillIndex.json` | 否，偏高级筛选 | 是 | 高 |
| 图鉴进度 | `/handbook-progress` | `src/pages/handbook-progress.vue`、`src/lib/handbookProgress/*` | `tables/PET_HANDBOOK.json`、`Pets.json`、`handbook-rewards.json`、`handbook-topic-skill-names.json`、`localStorage: rocom_handbook_progress` | 否，个人路线图暂不以打卡/进度为核心 | 是 | 中 |
| 道具 | `/items` | `src/pages/items.vue` | `items.json`、`public/assets/webp/items/` | 否 | 是 | 低 |

## 首页与导航现状

首页 `src/pages/index.vue` 当前突出三个入口：图鉴检索、配种模拟、配队规划；按钮区提供图鉴、表格、精灵配种和 GitHub。侧边栏 `src/components/Sidebar.vue` 暴露全部站内页面：首页、图鉴、图鉴进度、表格、配队、配种、孵蛋、星图、属性、道具。

按 `docs/MY_ROADMAP.md` 的个人版方向，首页更适合优先放“属性克制、图鉴搜索、技能搜索”。配队/PVP 可以作为核心或 Coming Soon 入口；配种、孵蛋、查蛋、星图、表格、道具、图鉴进度更适合收进“更多工具”。

## 技能功能现状

项目当前没有独立 `/skills` 页面。技能相关能力分布在：

- `/table`：通过 `PetSkillIndex.json` 做技能来源筛选，支持自有技能、学习技能和技能列表搜索。
- `/pets/:id`：展示单个宠物的自有技能、学习技能、遗传技能、技能覆盖属性和高威力技能。
- `/team`：选择队伍宠物技能，并基于技能类别、覆盖和描述识别定位。

个人版如果要把“技能查询”作为首页核心入口，建议新增 `src/features/battle-query` 中的技能查询组件，再轻量接入首页，避免直接大改 `table.vue` 或宠物详情页。

## 数据与脚本地图

基础数据入口：

- `public/data/Pets.json`：图鉴、表格、配队、配种、孵蛋、星图等页面的核心宠物索引。
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
2. 属性、图鉴、技能查询统一放入 `src/features/battle-query`，减少直接改核心页面。
3. PVP 后续放入 `src/features/pvp`，队伍导入导出不要写入 `public/data`。
4. `public/data` 和 `scripts` 继续视为上游基础数据层，不为了个人功能直接修改。
5. “更多工具”建议承载配种、孵蛋/查蛋、星图、表格、道具、图鉴进度，核心首页保持战斗查询优先。
