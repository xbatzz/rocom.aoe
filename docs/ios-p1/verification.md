# 八功能 scoped v2 验收

此前 v1 全量导出失败记录已由本验收取代。此处全部真实源命令均未带 --fixture。

- `yarn ios:content:test`：43 项数据管线检查通过。覆盖 nullable/缺字段/类型/enum、重复 ID、FK、环、冲突来源、源乱序、scope 闭包、排除材料/奖励、WebP 坏头、source hash、磁盘篡改与受控写入。
- `yarn ios:content:generate`：成功输出 `build/ios-content/v2/current/`。
- `yarn ios:content:validate --out build/ios-content/v2/current`：源 + 磁盘包通过。
- `yarn ios:content:determinism`：两次独立真实生成，全部 18 文件（17 实体 + manifest）逐字节一致，hash 一致。

```json
{
    "status": "passed",
    "runs": 2,
    "files": 18,
    "sourceFingerprint": "bc9b2c6c5cf3d8f454092fba4f6e8c78300e2d3ce8bc14788444a2b34d1e0408",
    "manifestSha256": "b132e121ac385d4fe9a17ae7d7160257588a3252d49f887625c2f92264ceb78e"
}
```

| 实体 | 数量 |
| --- | ---: |
| pets / petDetails | 各 721 |
| types | 19（18 普通属性 + 首领血脉类别） |
| skills / battleEffects | 各 1,079（effect 仍为未解析元数据） |
| skillGroups | 580 |
| petSkills | 35,573 |
| traits | 257 |
| evolutions | 356 |
| families | 405 |
| shinySlots | 81 |
| badgeFootprints | 601 |
| badgeLocations | 3 |
| personalities | 30 |
| magicItems | 5 |
| seasons | 5 |
| assets | 1,467 |

源宠物 1,147：根 721、额外闭包依赖 0、排除 426；manifest.scope 完整列 ID。包含真实图鉴未实装配置，不按未实装直接删除。9001 及 9 个 Unknown 内部配置均非 required 根/关系依赖；没有扩类型、改源属性或造数据。没有读取 items、HANDBOOK_TASK/REWARD 或 BAG_ITEM。进化只提取关系，不验证材料。

素材描述中 1,465 个文件存在、header 合法并已有字节 hash；2 个源头像确实缺失：

- `public/assets/webp/friends/img_Wat_ZhuZhuTun1_001_Res.webp`
- `public/assets/webp/friends/img_Wat_ZhuZhuTun2_001_Res.webp`

两项都有明确 missing 状态与 manifest 清单。没有替代图或转换输出。JSON generate/determinism 没有剩余阻断；完整运行时素材验收仍待独立转换阶段和缺图决策，不能把本结果当素材已齐备。

未修改 P0 bridge/transition/UI、Web 上游源或 SQLite。P0 历史 schema SHA-256 仍为 `34d12a1161027b37b910145366b2714dab56830b808b0d9ba33c329436c591ca`。未运行完整 Web/P0 测试、build 或 sync:pet-data。

## 本轮文件

新增：`shared/content/content.schema.json`、`shared/content/ios-scope.json`、`scripts/ios/scope.mjs`、`shared/fixtures/ios/p1-scoped-manifest.example.json`、`docs/ios-p1/scope-pruning.md`。

更新：`scripts/ios/schema.mjs`、`normalize.mjs`、`integrity.mjs`、`source.mjs`、`content.mjs`、`test-content.mjs`；本目录 `content-pipeline.md`/`verification.md`；旧 gap 报告仅增加已被 scope pruning 取代的提示。

保留历史 P0 schema 原件和 v1 示例；active v2 文档只引用 scoped 示例。ignored build 产物不作为版本管理 fixtures。package.json 的四个 Yarn 命令延续原 P1 管线，本轮未新增业务入口。
