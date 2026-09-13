# 异色收集

入口：侧栏「资料与收集 → 异色收集」、首页工具列表，路由 `/shiny-collection`。

## 使用与统计

- 默认 S4，可切换 S1–S4 和「其他」，赛季参数保存在 URL（例如 `?season=3`）。
- 点击卡片标记或取消收集，支持撤销最近一次操作；名称、形态、图鉴编号搜索会展开对应家族。
- 支持收集状态、普通 / 地区形态、首领形态筛选。赛季总进度和家族分母不随筛选变化。
- 每个进化阶段、地区形态、首领分支独立计数。采用 `s{season}:{petBaseId}` 保存，不能按图鉴编号或精灵名称合并。
- S4 月亮砣 / 满月砣的上下弦、S3 地鼠的枯水期 / 储水时、海盔虫与千棘海针的本来 / 磨损、S2 加油蟹的单双海葵分别记录。
- 返场沿用原赛季归属，不在 S4 重复计数；旧赛季后续增加的形态按游戏的归属赛季补入。

当前数据快照（2026-09-13）：

| 归属 | 形态数 |
| --- | ---: |
| S1 暗夜拾光 | 52 |
| S2 狂欢怪谈 | 41 |
| S3 铅字幻梦 | 54 |
| S4 月涌狂想 | 47 |
| 其他 | 4 |

数量包含所有进化阶段和可获得的首领分支，并非攻略里的家族数。

## 来源与生成

名单来源是仓库已经同步的游戏配置：

- `public/data/BinData/PETBASE_CONF.json`：`have_shiny === 1`、`belong_season`、`form`、`JL_shiny_res`。
- `public/data/BinData/PET_EVOLUTION_CONF.json`：家族、形态分支来源。不能仅依赖 `Pets.json.evolves_from_id`，该索引对千棘海针、满月砣的部分分支会使用同一个父体。
- `Pets.json`：已有实装判定、图鉴编号、属性与名称；限定可获得的 3xxx / 5xxx 配置，排除 4xxx 首领遭遇副本、7xxx 及其他战斗用配置。
- 赛季标题对照 [洛克王国世界 WIKI 精灵图鉴](https://wiki.biligame.com/nrc/精灵图鉴)（2026-09-13 查阅）。

检索时发现 [2026-08-31 S4 预告名单](https://www.ldmnq.com/6190/zixun/1059140.html) 含音速犬、电企鹅等，与当前配置不一致。它不作为名单依据：护主犬 / 音速犬只有异色资源引用、没有开放标记；电企鹅没有异色开放标记或异色立绘引用。避免因素材存在就认定已开放。

火红尾、雅丹鬃、云梦豚、长江豚有异色开放标记但未指定 `belong_season`，归入「其他」，不自行猜测赛季。云梦豚、长江豚的两张异色立绘目前缺失（见 `S4_DATA_UPDATE_AUDIT.md`），页面显示文字降级并保留记录能力。

`scripts/build-shiny-catalog.mjs` 被现有 `yarn sync:pet-data` 调用，生成隔离文件 `src/features/shiny-collection/generated/catalog.json`。客户端只导入这份轻量目录，不请求不随生产环境部署的 BinData。此功能不手工改动基础游戏 JSON。

## 保存与迁移

进度存储在 `rocom.shiny-collection.v1`，结构为 `{ version: 1, entries: { "s4:3583": { collected: true, updatedAt: "ISO 时间" } } }`。

取消收集保留带时间戳的 `collected: false`，合并时以较新的操作为准，避免旧备份将已取消记录重新点亮。同时间戳优先取消。不同标签页监听存储变化，每次修改前读取并合并最新记录；写入失败不会展示为已保存。

完整备份升级到版本 3，增加 `data.shinyCollection`；兼容版本 1 和 2。合并旧备份保留本机异色，完全替换旧备份会清空异色；数据管理界面明确提示这一点。替换支持恢复损坏的本机异色数据；导入失败时恢复写入前的内容。

## 验证

```sh
yarn sync:pet-data
node scripts/test-shiny-collection.mjs
yarn type-check
yarn build
```

回归脚本执行实际 TypeScript 存储 / 备份模块，检查生成目录一致性、形态区分、资源缺失、取消合并、旧版本兼容、损坏数据恢复和导入失败回滚。
