# Fork 同步上游与个人数据隔离策略

本文面向当前 fork 项目，目标是在继续同步 `aoe-top/rocom.aoe.top` 上游更新时，尽量减少冲突，并把个人收藏、备注、每日任务、常用队伍等私有功能和上游基础游戏数据隔离开。

## 1. `public/data` 下哪些文件是基础游戏数据

`public/data` 里有三层数据，需要分开看：

| 位置 | 性质 | 是否容易被上游或脚本覆盖 |
| --- | --- | --- |
| `public/data/BinData/*.json` | 游戏原始表的 JSON 化结果，是数据母版 | 极高 |
| `public/data/tables/*.json` | 从 `BinData` 镜像出来的公开表 | 高 |
| `public/data/pets/*.json` | 每只宠物详情，由同步脚本生成 | 极高 |
| `public/data/Pets.json` | 宠物列表索引，由同步脚本生成 | 极高 |
| `public/data/PetSkillIndex.json` | 宠物技能筛选索引，由同步脚本生成 | 极高 |
| `public/data/bloodline_index.json` | 血脉技能索引，由同步脚本生成 | 极高 |
| `public/data/items.json` | 道具索引，由同步脚本生成 | 极高 |
| `public/data/handbook-rewards.json` | 图鉴任务奖励索引，由同步脚本生成 | 极高 |
| `public/data/handbook-topic-skill-names.json` | 图鉴任务技能名映射，由同步脚本生成 | 极高 |
| `public/data/types.json` | 属性基础表，脚本输入之一 | 高 |
| `public/data/moves.json`、`magic_items.json`、`personalities.json`、`breeding.json`、`game_terms.json` | 静态/整理后的游戏数据 | 中到高 |

结论：`public/data` 整体都应视为上游基础游戏数据区，不建议在这里直接放个人收藏、备注或任务状态。

## 2. `yarn sync:pet-data` 的输入和输出

`package.json` 中：

```json
"sync:pet-data": "node ./scripts/sync-pet-data.mjs"
```

实际执行 `scripts/sync-pet-data.mjs`。

### 输入文件

脚本直接读取：

- `public/data/types.json`
- `public/data/BinData/PETBASE_CONF.json`
- `public/data/BinData/PET_HANDBOOK.json`
- `public/data/BinData/PET_EVOLUTION_CONF.json`
- `public/data/BinData/LEVEL_SKILL_CONF.json`
- `public/data/BinData/SKILL_CONF.json`
- `public/data/BinData/PET_CLASSIS_CONF.json`
- `public/data/BinData/PET_EGG_CONF.json`
- `public/data/BinData/PET_RANDOM_EGG_CONF.json`
- `public/data/BinData/PET_NAME_MAP_CONF.json`
- `public/data/BinData/BAG_ITEM_CONF.json`
- `public/data/BinData/MEGAMAP_GATHERING_CONF.json`
- `public/data/BinData/MONSTER_CONF.json`
- `public/data/BinData/MONSTER_CATCH_CONF.json`
- `public/data/BinData/REWARD_CONF.json`
- `public/data/BinData/VISUAL_ITEM_CONF.json`
- `public/data/BinData/EXCHANGE_CONF.json`
- `public/data/BinData/ITEM_LABLE_TYPE_CONF.json`

另外，脚本会查看 `public/data/tables/*.json` 已有哪些文件名，并从 `public/data/BinData/` 复制同名表到 `public/data/tables/`。

### 输出文件

脚本会生成或覆盖：

- `public/data/Pets.json`
- `public/data/bloodline_index.json`
- `public/data/PetSkillIndex.json`
- `public/data/items.json`
- `public/data/handbook-rewards.json`
- `public/data/handbook-topic-skill-names.json`
- `public/data/pets/*.json`
- `public/data/tables/*.json` 中有同名 `BinData` 来源的文件

这些文件不要手工塞个人数据，因为下次同步会被覆盖。

## 3. 图鉴页面直接依赖的 JSON 字段

图鉴主页面是 `src/pages/encyclopedia.vue`，直接读取：

- `/data/Pets.json`
- `/data/bloodline_index.json`

### `Pets.json` 直接依赖字段

图鉴页直接或通过 helper 使用这些字段：

- `id`
- `species_id`
- `name`
- `form`
- `main_type.id`
- `main_type.localized.zh`
- `sub_type.id`
- `sub_type.localized.zh`
- `default_legacy_type.localized.zh`
- `leader_potential`
- `is_leader_form`
- `preferred_attack_style`
- `localized.zh.name`
- `implemented`
- `base_hp`
- `base_phy_atk`
- `base_mag_atk`
- `base_phy_def`
- `base_mag_def`
- `base_spd`
- `evolves_from_id`
- `breeding_profile.egg_groups`

字段用途：

- 搜索：`id`、`species_id`、`name`、`form`、`localized.zh.name`、主副属性中文名、默认遗传属性中文名、实现状态文本、血脉技能命中。
- 筛选：主副属性 ID、攻击倾向、首领/进化状态、是否实装。
- 排序：图鉴编号、总种族值、速度、中文名。
- 展示：头像资源名 `name`、中文名、编号、属性、遗传属性、总和、速度、最高种族值、首领/未实装/可转首领标签。

### `bloodline_index.json` 直接依赖字段

图鉴页用于搜索血脉技能，直接依赖：

- `pet_id`
- `bloodline_moves`
- `bloodline_moves[].move_id`
- `bloodline_moves[].move_name`
- `bloodline_moves[].type_label`

类型定义中还保留了这些摘要字段，后续页面可能复用：

- `pet_name`
- `form`
- `implemented`
- `main_type_id`
- `sub_type_id`
- `default_legacy_type_id`
- `preferred_attack_style`
- `bloodline_moves[].type_id`
- `bloodline_moves[].type_name`
- `bloodline_moves[].move_category`
- `bloodline_moves[].energy_cost`
- `bloodline_moves[].power`

## 4. 属性关系页面直接依赖的 JSON 字段

属性关系页面是 `src/pages/attributes.vue`，直接读取：

- `/data/types.json`
- `/data/BinData/TYPE_DICTIONARY.json`

### `types.json` 直接依赖字段

- `id`
- `name`
- `localized.zh`
- `vulnerable_to`
- `resistant_to`

字段用途：

- `id`：排序、选择当前属性、图节点 ID。
- `name`：用英文名匹配克制关系。
- `localized.zh`：显示中文名，并和 `TYPE_DICTIONARY` 的中文字段做匹配。
- `vulnerable_to`：判断防守被哪些属性克制。
- `resistant_to`：判断防守抵抗哪些属性。

### `TYPE_DICTIONARY.json` 直接依赖字段

该文件按 `RocoDataRows` 包裹行数据，页面读取每一行：

- `RocoDataRows`
- `id`
- `type_name`
- `short_name`
- `evo_banding_color`
- `rolecard_favorite_pets_colour`

字段用途：

- `type_name`、`short_name`：清理“系/系别”等后，与 `types.json` 的 `localized.zh` 对齐。
- `evo_banding_color`：属性节点主色。
- `rolecard_favorite_pets_colour`：属性节点强调色/兜底色。

如果颜色字段无效，页面会回退到内置 `FALLBACK_TYPE_COLORS`。

## 5. 同步上游时最容易冲突的目录

最容易冲突：

- `public/data/`：大批量 JSON，尤其是 `BinData/`、`pets/`、`tables/` 和顶层生成文件。
- `public/assets/`：大量图片资源，尤其是 `webp/friends/`、`webp/items/`。
- `scripts/`：数据生成逻辑变更会影响生成结果。
- `src/lib/interface.ts`：数据结构类型一变，很多页面都会跟着动。
- `src/pages/encyclopedia.vue`、`src/pages/pets/[id].vue`、`src/pages/attributes.vue`、`src/pages/team.vue`：核心页面，容易和上游功能改动撞在一起。
- `package.json`、`yarn.lock`：依赖和脚本变更常见冲突点。

相对适合作为 fork 自定义区域：

- `src/features/personal-data/`
- `src/features/favorites/`
- `src/features/notes/`
- `src/features/daily-tasks/`
- `src/features/team-presets/`
- `public/user-data/`
- `docs/`

## 6. 个人收藏、备注、每日任务、常用队伍建议放哪里

目标是最大程度避免和上游冲突：不要改 `public/data` 的基础游戏数据，不要把个人状态塞进 `Pets.json` 或 `pets/*.json`。

推荐目录：

```text
src/features/personal-data/
src/features/favorites/
src/features/notes/
src/features/daily-tasks/
src/features/team-presets/
public/user-data/
```

推荐存储方式：

- 当前浏览器私有状态：优先用 `localStorage`。
- 需要导入/导出的个人模板：放 `public/user-data/*.json`。
- 需要提交到 fork 的默认配置：放 `src/features/*/defaults.ts` 或 `public/user-data/defaults/*.json`。

建议命名空间：

- 收藏：`rocom.personal.favorites.v1`
- 备注：`rocom.personal.notes.v1`
- 每日任务：`rocom.personal.daily-tasks.v1`
- 常用队伍：`rocom.personal.team-presets.v1`

建议文件：

```text
src/features/personal-data/storage.ts
src/features/favorites/favoriteTypes.ts
src/features/favorites/useFavorites.ts
src/features/notes/noteTypes.ts
src/features/notes/useNotes.ts
src/features/daily-tasks/dailyTaskTypes.ts
src/features/daily-tasks/useDailyTasks.ts
src/features/team-presets/teamPresetTypes.ts
src/features/team-presets/useTeamPresets.ts
public/user-data/README.md
public/user-data/defaults/favorites.example.json
public/user-data/defaults/notes.example.json
public/user-data/defaults/daily-tasks.example.json
public/user-data/defaults/team-presets.example.json
```

数据结构建议始终引用基础游戏数据的稳定 ID，而不是复制整份宠物/道具数据：

```json
{
    "version": 1,
    "pets": {
        "3001": {
            "favorite": true,
            "tags": ["主力"],
            "note": "个人培养备注"
        }
    },
    "items": {
        "100101": {
            "favorite": true,
            "note": "常用材料"
        }
    }
}
```

这样上游更新宠物名称、属性、技能时，个人数据仍然能按 ID 关联。

## 7. 是否建议创建数据适配层

建议创建，尤其是计划长期维护 fork 时。

推荐位置：

```text
src/features/pet-data/petAdapter.ts
src/features/pet-data/typeAdapter.ts
src/features/pet-data/itemAdapter.ts
```

原因：

- 上游 `public/data` 字段可能调整，适配层可以把变化挡在页面外。
- 个人功能可以依赖适配后的稳定模型，不直接耦合生成 JSON 的原始形状。
- 图鉴、收藏、备注、队伍预设都能共用同一套 ID、名称、头像、属性解析逻辑。

建议适配层职责：

- 只读基础游戏数据。
- 将 `Pets.json`、`pets/{id}.json`、`types.json` 转成页面/个人功能需要的稳定对象。
- 给字段缺失提供兜底，例如属性名、头像名、是否实装。
- 不在适配层写入个人状态；个人状态放到 `personal-data` 模块。

不建议一开始大规模重构现有页面。更稳的方式是：

1. 新个人功能先通过适配层读数据。
2. 后续碰到图鉴/队伍页面改动时，再逐步把重复数据读取逻辑迁到适配层。

## 8. 哪些目录不能随便改

这些目录和文件应视为上游/生成数据边界：

- `public/data/BinData/`
- `public/data/tables/`
- `public/data/pets/`
- `public/data/Pets.json`
- `public/data/PetSkillIndex.json`
- `public/data/bloodline_index.json`
- `public/data/items.json`
- `public/data/handbook-rewards.json`
- `public/data/handbook-topic-skill-names.json`
- `public/assets/webp/friends/`
- `public/assets/webp/items/`
- `scripts/sync-pet-data.mjs`
- `scripts/export_pet_json.py`
- `package.json`
- `yarn.lock`

不是绝对不能改，而是不要把 fork 私有功能直接写在这里。必须修改时，建议单独提交、写清楚原因，并同步检查生成结果。

## 9. 后续 fork 同步上游流程

首次配置上游：

```bash
git remote add upstream https://github.com/aoe-top/rocom.aoe.top.git
git fetch upstream
```

每次同步建议流程：

```bash
git status
git switch main
git fetch upstream
git merge upstream/main
```

如果你的主分支不叫 `main`，先用 `git branch` 确认分支名，再把命令中的 `main` 换成实际分支。

合并后重点检查：

```bash
git status
git diff --name-only HEAD~1..HEAD
yarn type-check
yarn build
```

如果上游改了 `public/data/BinData/`、`scripts/sync-pet-data.mjs` 或 `types.json`，再运行：

```bash
yarn sync:pet-data
```

然后检查是否产生预期数据变更：

```bash
git status
git diff -- public/data/Pets.json public/data/pets public/data/tables
```

推荐提交拆分：

1. `sync upstream`：只包含上游合并结果。
2. `regenerate data`：只包含运行 `yarn sync:pet-data` 后的生成结果。
3. `personal features`：只包含 fork 自己的功能代码。

遇到冲突时优先原则：

- `public/data`、`public/assets`：通常优先接受上游，再重新跑生成脚本。
- `scripts/sync-pet-data.mjs`：仔细合并，不要直接覆盖，因为它决定生成数据结构。
- `src/features/personal-*` 或 `public/user-data`：优先保留 fork 自己的实现。
- 页面文件冲突：尽量把个人功能入口保持小而独立，避免在核心页面里大段分叉。

同步后建议做一次人工验收：

- 图鉴页能加载、筛选、排序。
- 宠物详情页能打开任意宠物。
- 属性关系页能显示关系图。
- 配队页能读取已有队伍缓存。
- 个人收藏、备注、每日任务、常用队伍仍能按 ID 关联到最新基础数据。
