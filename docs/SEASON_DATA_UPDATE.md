# 赛季数据解包与导入手册

本文记录 S3 数据更新的实际处理流程，供后续赛季复用。目标是把 FModel 导出的游戏配置和图片安全导入项目，并尽早发现补丁层、本地化、测试形态和资源缺失问题。

## 1. 数据链路

完整链路如下：

```text
游戏 Paks
  -> FModel 导出 NRC/Content/...
  -> 校验补丁层和中文本地化
  -> 更新 public/data/BinData/*.json
  -> yarn sync:pet-data
  -> 生成 Pets.json、pets/*.json、PetSkillIndex.json 等
  -> yarn import:fmodel-icons
  -> 生成 friends/*.webp 和 items/*.webp
  -> 测试、类型检查、构建和人工抽查
```

`NRC/` 是本地解包目录，体积较大，已经加入 `.gitignore`，不得提交。

## 2. FModel 导出设置

使用最新版 FModel，并为游戏选择正确的 Version Override。加载存档时使用：

```text
All (Except Patched Assets)
```

不要使用会让旧资源和补丁资源同时生效的加载模式。旧的表结构、数据和本地化文件混用时，JSON 仍能成功生成，但字符串会按错误的索引写入，看起来像正常中文，实际内容完全错位。

需要导出的配置目录：

```text
NRC/Content/ScriptC/Data/Bin/BinConf/
NRC/Content/ScriptC/Data/Bin/BinDataCompressed/
NRC/Content/ScriptC/Data/Bin/BinLocalize/dev_CN/
```

需要导出的图片目录：

```text
NRC/Content/NewRoco/Modules/System/Common/Icon/Pet1024/
NRC/Content/NewRoco/Modules/System/BattleUI/Raw/Atlas/SkillIcon/
NRC/Content/NewRoco/Modules/System/BattleUI/Raw/Atlas/FeatureIcon/
```

FModel 应保留资源原始目录，例如技能图片导出为 `SkillIcon/101065.png`，特性图片导出为 `FeatureIcon/200308.png`。导入脚本会按 `SKILL_CONF.icon` 的完整路径找到它们，再转换为同名 WebP。

Lua 的 `unluac` 设置只影响 Lua 反编译，不参与宠物、技能和图片导出。

## 3. 补丁层与本地化

### 3.1 不要只按“最新文件”覆盖

游戏数据分布在基础包和多个补丁包中。同名表可能出现于不同层，最新补丁层不一定包含可用的本地化文件。应满足：

- 数据文件使用最终生效的补丁版本。
- `BinConf` 表结构与该数据版本兼容。
- `BinLocalize/dev_CN` 与数据中的本地化索引匹配。
- 缺少本层表结构时，可以向较早层回退寻找 schema。
- 不可把不同版本的本地化文件与最新数据盲目组合。

如果使用分层导出，应保留原 pak 层目录，不要先把同路径文件全部压平成一个 `NRC/`。可参考 [Roco-Kingdom-World-Data](https://github.com/kikozz/Roco-Kingdom-World-Data) 的做法：各 pak 层分开保存，解码时记录 schema 和本地化来源。

### 3.2 S3 已确认的来源层

以下仅记录 `2026-07-16` S3 快照的实际选择，用于复盘，不应直接套用到未来赛季：

| 表 | S3 来源层 |
| --- | --- |
| `PETBASE_CONF` | `_2_P` |
| `LEVEL_SKILL_CONF` | `_2_P` |
| `PET_HANDBOOK` | `_2_P` |
| `PET_EVOLUTION_CONF` | `_2_P` |
| `SKILL_CONF` | `_3_P` |
| `PET_CLASSIS_CONF` | `_0_P` |
| `PET_EGG_CONF` | `_3_P` |
| `PET_RANDOM_EGG_CONF` | `_2_P` |
| `PET_NAME_MAP_CONF` | `_2_P` |
| `BAG_ITEM_CONF` | `_2_P` |
| `MEGAMAP_GATHERING_CONF` | `_2_P` |
| `MONSTER_CONF` | `_3_P` |
| `MONSTER_CATCH_CONF` | `_2_P` |
| `REWARD_CONF` | `_2_P` |
| `VISUAL_ITEM_CONF` | `_2_P` |
| `EXCHANGE_CONF` | `_2_P` |
| `ITEM_LABLE_TYPE_CONF` | `_0_P` |

特别注意：S3 的 `_3_P/BAG_ITEM_CONF` 行结构有效，但名称为空或错误；项目最终采用 `_2_P`，否则 `items.json` 会生成 0 条。

### 3.3 本地化抽样检查

不要只检查文件能否被 `JSON.parse`。每次至少人工核对：

- 已知旧精灵的名称和简介。
- 一只本赛季新精灵的名称和简介。
- 一个新技能的名称和描述。
- 一条新图鉴的名称和任务文案。
- 道具表至少一个常见道具名称。

S3 的有效哨兵值：

| 表与 ID | 正确值 |
| --- | --- |
| `PETBASE_CONF[3746].name` | `睡铃雪影娃娃` |
| `PETBASE_CONF[3747].name` | `莫比乌乌` |
| `SKILL_CONF[7021280].name` | `缓一缓` |
| `PET_HANDBOOK[440].name` | `睡铃雪影娃娃` |
| `BAG_ITEM_CONF[100001].name` | `一小箱金币` |

本次错误导出的典型表现：

- 3746 的名称变成天气提示。
- 7021280 的名称变成“冰爪”。
- 多个精灵共用完全无关的简介。
- 道具名称为空，最终生成 0 条物品。

出现任一情况时，不得把该 JSON 写入 `public/data/BinData/`。应重新检查 FModel 版本、Version Override、加载模式和补丁层组合。

## 4. 项目依赖的原始表

`scripts/sync-pet-data.mjs` 直接依赖以下 17 张表：

```text
PETBASE_CONF.json
PET_HANDBOOK.json
PET_EVOLUTION_CONF.json
LEVEL_SKILL_CONF.json
SKILL_CONF.json
PET_CLASSIS_CONF.json
PET_EGG_CONF.json
PET_RANDOM_EGG_CONF.json
PET_NAME_MAP_CONF.json
BAG_ITEM_CONF.json
MEGAMAP_GATHERING_CONF.json
MONSTER_CONF.json
MONSTER_CATCH_CONF.json
REWARD_CONF.json
VISUAL_ITEM_CONF.json
EXCHANGE_CONF.json
ITEM_LABLE_TYPE_CONF.json
```

确认本地化正确后，把最终版本写入：

```text
public/data/BinData/
```

不要直接手工编辑 `Pets.json` 或 `public/data/pets/*.json` 来补赛季数据；这些都是脚本生成结果，下次同步会被覆盖。

## 5. 正确统计赛季精灵

不能只用“新增 ID”统计赛季内容。一个赛季可能同时包含：

- 全新常规精灵。
- 已存在精灵的回归或赛季归属更新。
- 异色、异地、地区和季节形态。
- 首领、超进化或强化形态。
- 剧情战斗复制体。
- 尚未完成的测试占位。

优先使用以下字段交叉判断：

```text
season_version
belong_season
pictorial_book_id
level_skill_conf_id
JL_res
available_time
```

同时检查该记录是否拥有：

- 有效 `PET_HANDBOOK` 归属。
- 可解析的 `LEVEL_SKILL_CONF`。
- `SKILL_CONF` 中存在的技能 ID。
- 非测试或剧情专用的模型/图片引用。

S3 的复盘统计：

```text
PETBASE 总数：1128
相对旧数据新增 PETBASE：63
belong_season = 3：59 条
去重名称：50 个
独立图鉴：49 个
新增 LEVEL_SKILL：22 套
PET_HANDBOOK 总数：442
相对旧数据新增图鉴：95
SKILL_CONF 总数：1894
```

其中 3746–3760 只是 15 个新常规编号，不代表整个 S3。`5055–5062` 还包含新增的独立强化/首领技能配置；`3778–3792` 等带“占位”的记录不可直接当作正式图鉴精灵。

## 6. 生成前端数据

更新 17 张原始表后运行：

```bash
yarn sync:pet-data
```

S3 的正常摘要为：

```text
Generated 1128 pet index entries, 1128 pet detail files, and 4119 item entries from BinData.
```

重点检查生成结果：

```text
public/data/Pets.json
public/data/PetSkillIndex.json
public/data/bloodline_index.json
public/data/items.json
public/data/handbook-rewards.json
public/data/handbook-topic-skill-names.json
public/data/pets/
public/data/tables/
```

如果物品数量突然变成 0，首先检查 `BAG_ITEM_CONF` 的 `name` 字段和补丁层，而不是修改生成脚本绕过。

### 6.1 占位记录与图鉴重复

`PETBASE_CONF` 会同时保存可收集精灵、首领技能配置、剧情战斗复制体和未完成占位。它们不能从原始表删除，因为战斗配置仍可能引用这些 ID。

生成脚本采用以下边界：

- 常规精灵必须能解析到 `PET_HANDBOOK` 中 `1–442` 的真实图鉴条目，并拥有有效战斗数据，才标记为已实装。
- 首领记录必须拥有图鉴关联、展示资源和大于 0 的总种族值，才标记为已实装。
- 名称明确含“占位、测试、废案、临时”的记录判为未实装。
- 没有自己的图鉴和上线时间，却复用另一只图鉴精灵完整头像模板的记录判为未实装。
- 零种族值首领保留在 `Pets.json` 和详情 JSON 中，但默认图鉴不会显示。
- 图鉴列表只合并“同物种、同中文名、同头像资源键”的首领配置，保留 ID 较小的有效代表。
- 普通形态与首领形态不合并；异色、异地、地区和季节形态也不合并。

例如 S3 数据中：

- `3761–3776`、`3778–3792` 共 31 条未完成记录复用了雅丹鬃 `3745` 的头像和战斗模板，保留原始数据但判为未实装。
- 圣光迪莫 `3048`、圣草迪莫 `3051` 已确认未在游戏中实装，判为未实装；实际存在的首领记录 `5025`、`5026` 保持已实装。
- 没有真实图鉴关联的记录保留为未实装；前端显示“配置 ID”，不得用 PETBASE ID 冒充 `No.001–No.442` 图鉴编号。
- 圣水守护保留已实装首领 `5010`；零种族值的 `4005`、`8101` 仍可查询，但不进入默认图鉴。
- 烈火战神保留已实装首领 `5017`；零种族值的 `4006`、`8102` 不进入默认图鉴。

同步后运行数据质量回归检查：

```bash
yarn test:pet-data-quality
```

## 7. 精灵、技能和特性图片

### 7.1 精灵图片

项目通过 `JL_res`、`JL_shiny_res` 等字段读取：

```text
/Game/NewRoco/Modules/System/Common/Icon/Pet1024/JL_xxx
```

输出位置：

```text
public/assets/webp/friends/JL_xxx.webp
```

文件名后缀必须保留：

| 后缀 | 含义 |
| --- | --- |
| `_yise` | 异色 |
| `_shouling` | 首领 |
| `_qiu` | 地区或季节形态 |
| `_yidi` | 异地形态 |
| `_huoshan` | 火山等地区形态 |
| `_xushui` | 特定状态/地区形态 |
| `_shouling_yise` | 异色首领 |

这些名称是不同资源键，不能把后缀删除或合并。

### 7.2 技能图片

项目组件最终读取：

```text
public/assets/webp/items/{icon_id}.webp
```

必须以 `SKILL_CONF.icon` 的实际资源引用为准。普通战斗技能通常指向：

```text
/Game/NewRoco/Modules/System/BattleUI/Raw/Atlas/SkillIcon/101065
```

FModel 应导出到：

```text
NRC/Content/NewRoco/Modules/System/BattleUI/Raw/Atlas/SkillIcon/101065.png
```

再转换为：

```text
101065.webp
```

`Common/Icon/SkillBase/*_png.png` 是战斗界面使用的 `512×256` 横向技能插画，不是技能列表所需的正方形图标，禁止用它补齐 `SkillIcon`。正确的 `SkillIcon` 原图通常为 `128×128`；导入脚本会拒绝非正方形源图，避免横图被静默写入 `public/assets/webp/items/`。

### 7.3 特性图片

精灵的 `pet_feature`、`pet_glass_feature` 或 `pet_chaos_feature` 会关联 `SKILL_CONF` 中的特性记录。其 `icon` 字段通常指向：

```text
/Game/NewRoco/Modules/System/BattleUI/Raw/Atlas/FeatureIcon/200308
```

FModel 对应导出目录：

```text
NRC/Content/NewRoco/Modules/System/BattleUI/Raw/Atlas/FeatureIcon/
```

输出位置与技能图标相同：

```text
public/assets/webp/items/{icon_id}.webp
```

如果特性卡片显示名称首字，说明对应 WebP 不存在或加载失败，应优先检查该目录，而不是 `SkillBase/`。

### 7.4 自动导入

把 `Pet1024/`、`SkillIcon/` 和 `FeatureIcon/` 放到本文约定的 `NRC` 路径后运行：

```bash
yarn import:fmodel-icons
```

脚本会：

- 从当前 `PETBASE_CONF` 和 `SKILL_CONF` 收集实际引用。
- 保留精灵形态后缀。
- 按 `SKILL_CONF.icon` 的完整 `/Game/...` 路径定位 FModel 导出文件，不再将技能引用映射到 `SkillBase`。
- 按资源路径区分战斗技能和特性图标，并在同一资源键指向不同路径时直接报错。
- 校验所有待转换图标均为正方形，拒绝 `512×256` 等横向插画。
- 转换为带透明通道的 WebP。
- 默认跳过已有的正方形图片；若已有 WebP 不是正方形，会自动从正确源路径重新生成。
- 汇报仍然缺少的源文件。

确实需要重新压缩全部现有图片时才使用：

```bash
yarn import:fmodel-icons --overwrite
```

只需要用重新导出的方形素材覆盖战斗技能图标时使用：

```bash
yarn import:fmodel-icons --overwrite-skills
```

该参数不会覆盖宠物头像或特性图标，适合每赛季补齐和纠正 `SkillIcon`。

## 8. 验收清单

依次运行：

```bash
node scripts/test-handbook-progress.mjs
yarn test:pet-data-quality
yarn type-check
yarn build
```

人工抽查至少包括：

1. 图鉴列表能搜索到多只新赛季精灵。
2. 新精灵详情页显示正确中文名、属性、种族值和特性。
3. 升级技能、技能石与技能描述不为空。
4. 普通、异色、首领和地区形态读取各自图片。
5. 技能页的新技能图标不显示文字占位。
6. 抽查新技能的源 PNG 与目标 WebP 均为 1:1；如果脚本报告“图标源图必须为正方形”，应检查是否误导出了 `SkillBase` 横向插画。
7. 道具页仍有正常数量和中文名称。
8. `git status` 中不出现 `NRC/`。

如果低文件句柄环境运行 Vite 时出现：

```text
EMFILE: too many open files, watch
```

这是构建环境的文件监听上限问题。先确认 `yarn type-check` 和数据测试结果，再在文件句柄限制更宽松的终端或 CI 环境重新执行构建；不要把它误判成本地化或 JSON 结构错误。

## 9. 提交建议

赛季数据更新建议独立提交，不与页面功能或个人数据混在一起。提交前检查：

```bash
git status
git diff --stat
git diff -- public/data/Pets.json
git diff -- public/data/PetSkillIndex.json
```

提交说明应包含：

- 游戏数据快照日期。
- FModel 版本和 Version Override。
- 实际采用的各表补丁层。
- 原始表和生成文件数量变化。
- 新增图片数量。
- 本地化哨兵检查结果。
- 已运行的验证命令及结果。
