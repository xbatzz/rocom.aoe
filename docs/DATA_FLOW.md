# 数据维护方式与数据流

本文基于 `package.json`、`scripts/`、`public/data/` 以及页面中的实际 `fetch` 调用整理。结论先行：项目把游戏原始表放在 `public/data/BinData/`，再通过脚本生成适合前端读取的索引、详情和少量表镜像。个人收藏、备注等用户数据不应写进这些原始/生成数据文件。

## 1. `yarn sync:pet-data` 实际执行了哪个脚本？

`package.json` 中的命令是：

```json
"sync:pet-data": "node ./scripts/sync-pet-data.mjs"
```

所以实际执行的是 `scripts/sync-pet-data.mjs`。

## 2. 该脚本的数据来源是什么？是否需要本地游戏数据包？

`scripts/sync-pet-data.mjs` 的直接数据来源是仓库里的 JSON 文件，不直接读取 `.bytes` 游戏包：

- `public/data/BinData/*.json`：主要来源，脚本通过 `readTable()` 读取这里的表。
- `public/data/types.json`：属性基础列表，脚本会读取它来做属性 ID 归一化和名称映射。
- `public/data/tables/*.json`：不是输入主源；脚本会把已有 `tables/` 文件名对应的 `BinData/` 同名表重新镜像过去。

脚本读取的 `BinData` 表包括：

- 宠物与图鉴：`PETBASE_CONF.json`、`PET_HANDBOOK.json`、`PET_EVOLUTION_CONF.json`、`PET_CLASSIS_CONF.json`、`PET_NAME_MAP_CONF.json`
- 技能：`LEVEL_SKILL_CONF.json`、`SKILL_CONF.json`
- 孵蛋/繁育：`PET_EGG_CONF.json`、`PET_RANDOM_EGG_CONF.json`
- 捕捉与地图：`MEGAMAP_GATHERING_CONF.json`、`MONSTER_CONF.json`、`MONSTER_CATCH_CONF.json`
- 道具与奖励：`BAG_ITEM_CONF.json`、`ITEM_LABLE_TYPE_CONF.json`、`REWARD_CONF.json`、`VISUAL_ITEM_CONF.json`、`EXCHANGE_CONF.json`

是否需要本地游戏数据包，要分两步看：

- 运行 `yarn sync:pet-data`：不需要本地游戏数据包，只需要 `public/data/BinData/` 已经存在并且表结构符合脚本预期。
- 更新/重新导出 `public/data/BinData/`：需要本地游戏数据包。`scripts/export_pet_json.py` 的默认输入是 `Data/Bin`，并要求里面有 `BinConf/`、`BinDataCompressed/`、`BinLocalize/`；它会解析 `.bytes` 和表结构，导出 JSON。

维护链路可以理解为：

```text
本地游戏 Data/Bin
  -> scripts/export_pet_json.py
  -> public/data/BinData/*.json
  -> yarn sync:pet-data
  -> public/data/Pets.json、pets/*.json、items.json、handbook-rewards.json 等前端数据
```

## 3. `public/data` 下有哪些 JSON 文件？分别对应哪些页面？

### 顶层 JSON

| 文件 | 作用 | 读取页面/模块 |
| --- | --- | --- |
| `public/data/Pets.json` | 宠物列表索引，含基础属性、种族值、实现状态、繁育概要等 | 图鉴 `src/pages/encyclopedia.vue`、宠物表 `src/pages/table.vue`、蛋组 `src/pages/egggroup.vue`、孵化 `src/pages/incubate.vue`、繁育 `src/pages/breeding.vue`、配队 `src/pages/team.vue`、宠物详情 `src/pages/pets/[id].vue`、图鉴进度目录 `src/lib/handbookProgress/catalog.ts` |
| `public/data/PetSkillIndex.json` | 宠物技能筛选索引和技能目录 | 宠物表 `src/pages/table.vue` |
| `public/data/bloodline_index.json` | 每只宠物的血脉技能摘要索引 | 图鉴 `src/pages/encyclopedia.vue` |
| `public/data/breeding.json` | 旧繁育数据/说明型数据 | 当前源码中没有直接 `fetch` |
| `public/data/game_terms.json` | 游戏术语 | 当前源码中没有直接 `fetch` |
| `public/data/handbook-rewards.json` | 图鉴任务奖励映射 | 图鉴进度 `src/pages/handbook-progress.vue`、宠物详情 `src/pages/pets/[id].vue` |
| `public/data/handbook-topic-skill-names.json` | 图鉴任务中技能 ID 到技能名的映射 | 图鉴进度/宠物详情共用模块 `src/lib/handbookProgress/topicText.ts` |
| `public/data/items.json` | 道具索引 | 道具页 `src/pages/items.vue`、宠物详情 `src/pages/pets/[id].vue` |
| `public/data/magic_items.json` | 血脉魔法/配队用魔法道具 | 配队 `src/pages/team.vue` |
| `public/data/moves.json` | 技能列表 | 配队 `src/pages/team.vue`、宠物详情 `src/pages/pets/[id].vue` |
| `public/data/personalities.json` | 性格列表 | 配队 `src/pages/team.vue` |
| `public/data/types.json` | 属性/血脉基础列表 | 属性关系 `src/pages/attributes.vue`、配队 `src/pages/team.vue`、宠物详情 `src/pages/pets/[id].vue` |

### `public/data/pets/*.json`

当前有 1065 个宠物详情 JSON。路径形如：

```text
public/data/pets/{petId}.json
```

读取页面：

- 宠物详情页 `src/pages/pets/[id].vue`
- 配队页 `src/pages/team.vue`

这些文件由 `scripts/sync-pet-data.mjs` 批量生成。脚本运行时会先清空旧的 `public/data/pets/*.json`，再重新写入。

### `public/data/tables/*.json`

当前有 12 个表镜像：

- `ACTIVITY_INHERITANCE_CONF.json`
- `EGG_TYPE_CONF.json`
- `HOME_PET_LAY_EGG_RATE_CONF.json`
- `PETBASE_CONF.json`
- `PET_BLOOD_CONF.json`
- `PET_CLASSIS_CONF.json`
- `PET_EGG_CONF.json`
- `PET_EVOLUTION_CONF.json`
- `PET_HANDBOOK.json`
- `PET_RANDOM_EGG_CONF.json`
- `PET_TALENT_CONF.json`
- `SKILL_CONF.json`

当前页面直接读取：

- `public/data/tables/PET_HANDBOOK.json`：图鉴进度目录、宠物详情的图鉴任务
- `public/data/tables/HOME_PET_LAY_EGG_RATE_CONF.json`：繁育页

其他 `tables/` 文件目前主要是保留给前端或调试使用的公开表镜像。`sync-pet-data.mjs` 会按 `tables/` 里已有文件名，从 `BinData/` 同名文件同步内容。

### `public/data/BinData/*.json`

当前有 745 个 JSON 原始表。它们是站点的数据母版，绝大多数页面不直接读取。当前前端直接读取的 `BinData` 文件只有：

- `public/data/BinData/TYPE_DICTIONARY.json`：属性关系页 `src/pages/attributes.vue`

`scripts/sync-pet-data.mjs` 还会读取多张 `BinData` 表来生成前端索引和详情，详见第 2 节。

## 4. 图鉴页面读取的是哪些数据文件？

如果“图鉴页面”指 `src/pages/encyclopedia.vue`，它读取：

- `/data/Pets.json`
- `/data/bloodline_index.json`

如果把宠物详情页和图鉴任务也算作图鉴体系，则还会读取：

- `/data/pets/{id}.json`
- `/data/types.json`
- `/data/moves.json`
- `/data/Pets.json`
- `/data/tables/PET_HANDBOOK.json`
- `/data/handbook-rewards.json`
- `/data/items.json`
- `/data/handbook-topic-skill-names.json`

图鉴进度页 `src/pages/handbook-progress.vue` 及其工具模块读取：

- `/data/tables/PET_HANDBOOK.json`
- `/data/Pets.json`
- `/data/handbook-rewards.json`
- `/data/handbook-topic-skill-names.json`

进度本身不写入 `public/data`，而是写入浏览器 `localStorage`，键名为 `rocom_handbook_progress`。

## 5. 属性关系页面读取的是哪些数据文件？

属性关系页 `src/pages/attributes.vue` 读取：

- `/data/types.json`
- `/data/BinData/TYPE_DICTIONARY.json`

其中 `types.json` 提供属性基础条目，`TYPE_DICTIONARY.json` 提供属性克制/抗性关系数据。

## 6. 如果想做个人收藏和备注，应该新建哪些文件，避免影响原项目数据？

不要把个人收藏、备注写入这些位置：

- `public/data/BinData/`：原始游戏表，后续更新会替换。
- `public/data/tables/`：由 `BinData` 镜像，可能被 `sync:pet-data` 覆盖。
- `public/data/Pets.json`、`public/data/pets/*.json`、`public/data/items.json`、`public/data/handbook-rewards.json`、`public/data/handbook-topic-skill-names.json`、`public/data/bloodline_index.json`、`public/data/PetSkillIndex.json`：生成文件，运行脚本可能覆盖。

推荐新增独立的个人数据层，例如：

- `public/user-data/favorites.json`：个人收藏，按宠物 ID、道具 ID 或页面类型存储。
- `public/user-data/notes.json`：个人备注，按实体类型和 ID 存储。
- `public/user-data/tags.json`：个人标签/分组，可选。

示例结构：

```json
{
    "version": 1,
    "pets": {
        "3001": {
            "favorite": true,
            "tags": ["主力", "待培养"],
            "note": "速度优秀，适合先手配置。"
        }
    },
    "items": {
        "100101": {
            "favorite": true,
            "note": "常用兑换材料。"
        }
    }
}
```

如果个人数据只属于当前浏览器，不需要提交到仓库，更推荐使用 `localStorage` 或导入/导出 JSON。项目已有两个类似模式：

- 图鉴进度：`localStorage` 键名 `rocom_handbook_progress`
- 配队：`localStorage` 键名 `rocom.team-builder.v1`

建议新增个人收藏备注时使用独立命名空间，例如：

- `rocom.personal.favorites.v1`
- `rocom.personal.notes.v1`

这样可以避免和原项目数据、图鉴进度、配队缓存互相影响。

## 7. 维护注意事项

- `scripts/sync-pet-data.mjs` 会生成/覆盖：
  - `public/data/Pets.json`
  - `public/data/bloodline_index.json`
  - `public/data/PetSkillIndex.json`
  - `public/data/items.json`
  - `public/data/handbook-rewards.json`
  - `public/data/handbook-topic-skill-names.json`
  - `public/data/pets/*.json`
  - `public/data/tables/*.json` 中已有且在 `BinData/` 有同名来源的文件
- 手工维护个人数据时，应放在新目录或浏览器存储中，避免放入任何会被脚本覆盖的生成文件。
- 如果要更新游戏数据，优先更新 `public/data/BinData/`，再运行 `yarn sync:pet-data` 生成前端消费层。
