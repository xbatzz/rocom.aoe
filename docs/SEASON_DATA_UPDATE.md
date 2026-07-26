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
NRC/Content/NewRoco/Modules/System/Common/Icon/SkillBase/
```

FModel 可能把技能图片导出成 `101065_png.png`。图片导入脚本会把它规范化为 `101065.webp`。

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

## 7. 精灵和技能图片

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

FModel 的 `SkillBase` 文件名通常是：

```text
101065_png.png
```

应转换为：

```text
101065.webp
```

### 7.3 自动导入

把 `Pet1024/` 和 `SkillBase/` 放到本文约定的 `NRC` 路径后运行：

```bash
yarn import:fmodel-icons
```

脚本会：

- 从当前 `PETBASE_CONF` 和 `SKILL_CONF` 收集实际引用。
- 保留精灵形态后缀。
- 去掉技能图的 `_png` 导出后缀。
- 转换为带透明通道的 WebP。
- 默认只补缺失文件，不覆盖现有图片。
- 汇报仍然缺少的源文件。

确实需要重新压缩全部现有图片时才使用：

```bash
yarn import:fmodel-icons --overwrite
```

## 8. 验收清单

依次运行：

```bash
node scripts/test-handbook-progress.mjs
yarn type-check
yarn build
```

人工抽查至少包括：

1. 图鉴列表能搜索到多只新赛季精灵。
2. 新精灵详情页显示正确中文名、属性、种族值和特性。
3. 升级技能、技能石与技能描述不为空。
4. 普通、异色、首领和地区形态读取各自图片。
5. 技能页的新技能图标不显示文字占位。
6. 道具页仍有正常数量和中文名称。
7. `git status` 中不出现 `NRC/`。

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

