# S4 数据更新审计

本次更新的维护经验见 [S4 更新问题与经验总结](./S4_UPDATE_LESSONS.md)。实装状态与资源完整性独立处理；已撤销将头像文件可用性作为 implemented 条件的改动。

## 写代码前的字节分析

当前源：`NRC/Content/ScriptC/Data/Bin`，不使用 S3 backup 作为来源。用户报告 FModel 包含 CUE4Parse PR #430 修复；本地通过实际 bytes 验证。NRC 受 gitignore 保护。

数值均为小端；结构 bitmap 按 schema Properties 顺序，从每字节最高位开始。schema 的 Offset 是未压缩布局，不能用于定位压缩结构中的值。

| 样本 | 原始布局与引用链 | 语义 |
| --- | --- | --- |
| PET_HANDBOOK 440 | row offset 14954，34 bytes，bitmap `fb80`；include ref 665 的 blob `7e070000` → ref 1918 的 blob `80f2090000` → ref 2546 的 blob `a20e0000` | `80` 表示唯一字段存在；字段是 primitive 动态数组引用，最终元素 3746 |
| PET_HANDBOOK 466 | row offset 15838，34 bytes，bitmap `fb80`；include ref 704 的 blob `b1070000` → ref 1969 的 blob `800c0a0000` → ref 2572 的 blob `d40e0000` | 最终元素 3796 |
| PET_HANDBOOK 440 pet_topic | ref 666：`ca020000cb020000fc0600007f07000080070000` | 五个结构引用：714、715、1788、1919、1920，不是一个含五字段的内联结构 |
| PET_HANDBOOK 466 pet_topic | ref 705：`ca020000cb020000fc060000b2070000b3070000` | 五个结构引用：714、715、1788、1970、1971 |
| 两图鉴的首任务 | ref 714：`f801000000010000007d0500000100000011150300` | `f8`：五字段存在；topic_Id=1、topic_type=1、localized ref=1405、topic_cnt=1、topic_reward=202001 |
| LEVEL_SKILL_CONF 3001（旧 S3 对照） | row key 1，offset 4，92 bytes；bitmap `dffffe00`；level ref 1 首元素 ref 571：`e00100000001000000481f6b00` | `e0`：三个字段存在；level_point=1、stage=1、param=7020360，与仓库 S3 JSON 相同（S3 另有现 schema 已移除的 level_gain_skill 字段） |
| LEVEL_SKILL_CONF 3001 machine_skill_group | ref 2 首元素 ref 587：`c048a56c00be0e0000` | `c0`：两个字段存在；machine_skill_id=7120200，machine_skill_name 继续引用普通字符串 ref 3774 |

S3 对照使用已有 `public/data/BinData/LEVEL_SKILL_CONF.json` 的语义结果；本地 backup 没有对应 bytes，未宣称验证旧二进制格式。

编码结论：顶层 row table 提供 row key / size / offset；ref table 提供 ref ID / size / offset。单个 EStruct 的 ref 目标为带 bitmap 的结构；EStruct 数组（ArrayDim > 1 或 DynamicArray）目标为 uint32 ref 列表，每个目标结构独立带 bitmap。primitive 动态数组目标为相应类型的连续数值。嵌套字段可继续引用数组、结构、普通字符串或本地化字符串。元素边界由 ref table 的 size 决定，不由 schema 字段长度求和决定。

旧解析器把结构引用列表当作字段，并忽略子结构 bitmap，造成伪宠物 ID 和任务错位；引用值碰巧存在，使严格 unresolved-ref 检查未能发现语义错误。

## S3 → S4 table audit

| Table | S3 | S4 | Added IDs | Removed IDs |
| --- | ---: | ---: | ---: | ---: |
| PETBASE_CONF | 1128 | 1147 | 32 | 13 |
| PET_HANDBOOK | 442 | 468 | 26 | 0 |
| SKILL_CONF | 1894 | 1988 | 96 | 2 |
| LEVEL_SKILL_CONF | 906 | 925 | 19 | 0 |
| BAG_ITEM_CONF | 4844 | 5153 | 315 | 6 |

## New handbook entries and canonical pet IDs

| Handbook | Name | PETBASE | Generated implemented |
| --- | --- | --- | --- |
| 443 | 诅咒狼灵 | 3761 | True |
| 444 | 新月狼灵 | 3762 | True |
| 445 | 银月狼王 | 3763 | True |
| 446 | 新月鹭 | 3764 | True |
| 447 | 月辉鹭 | 3765 | True |
| 448 | 月使鹭纳 | 3766 | True |
| 449 | 热团团 | 3574 | True |
| 450 | 焰米龙 | 3575 | True |
| 451 | 圣凯布米龙 | 3576 | True |
| 452 | 章脑丸 | 3767 | True |
| 453 | 智辉章脑 | 3768 | True |
| 454 | 未完虫 | 3542 | True |
| 455 | 玳龟 | 3589 | True |
| 456 | 玳塔 | 3590 | True |
| 457 | 量风碗 | 3663 | True |
| 458 | 测风蝉 | 3664 | True |
| 459 | 小浣蛋 | 3771 | True |
| 460 | 黑手浣熊 | 3772 | True |
| 461 | 幽铃 | 3773 | True |
| 462 | 摇铃魔偶 | 3774 | True |
| 463 | 星星眼 | 3236 | True |
| 464 | 布灵 | 3775 | True |
| 465 | 布灵布灵 | 3776 | True |
| 466 | 果实立方人 | 3796 | True |
| 467 | 云梦豚 | 3784 | True |
| 468 | 长江豚 | 3785 | True |

## New PETBASE records (implementation is the existing project heuristic)

| ID | Name | Implemented | Leader form |
| --- | --- | --- | --- |
| 3796 | 果实立方人 | True | False |
| 4107 | 烈焰狂战士 | False | True |
| 4108 | 满月砣 | False | True |
| 4109 | 满月砣 | False | True |
| 5063 | 烈焰狂战士 | True | True |
| 5064 | 满月砣 | True | True |
| 5065 | 满月砣 | True | True |
| 8029 | 银月狼王 | False | False |
| 8030 | 被污染的黑手浣熊 | False | False |
| 8031 | 被污染的玳塔 | False | False |
| 8032 | 被污染的星星眼 | False | False |
| 8033 | 被污染的布灵布灵 | False | False |
| 8034 | 被污染的智辉章脑 | False | False |
| 8035 | 被污染的测风蝉 | False | False |
| 8036 | 被污染的未完虫 | False | False |
| 8037 | 被污染的摇铃魔偶 | False | False |
| 8201 | 武斗酷猫 | True | True |
| 8202 | 画间沉铁兽 | False | False |
| 8203 | 卷毛鸭 | False | False |
| 8204 | 泥吼牙 | False | False |
| 8205 | 蒲公英娃娃 | False | False |
| 8206 | 格兰球 | False | False |
| 8207 | 伊贝粉粉 | False | False |
| 8208 | 奇丽花 | False | False |
| 9004 | 金月陨星 | False | False |
| 9005 | 赤月陨星 | False | False |
| 9820 | 月陨星 | False | False |
| 13000173 | 满月砣 | True | True |
| 13000174 | 烈焰狂战士 | True | True |
| 32000004 | 不咕钟 | False | False |
| 32000005 | 莫比乌乌 | False | False |
| 32000006 | 量风碗 | False | False |

## Added skill IDs (includes features, combat variants and abandoned records)

200314: 铭记于月亮; 200315: 热成像; 200316: 冷光源; 200317: 秋收; 200318: 基因编辑; 200319: 风速仪; 200320: 翻垃圾桶; 200321: 正模标本; 200322: 盗魂铃; 200323: 宇宙之眼; 200324: 乌龟塔理论; 200325: 旧玩具; 200326: 吐水; 280037: 蒸汽革命; 280038: 月相; 289100: 草木苏醒时; 289101: 变形活画; 289102: 得寸进尺; 289103: 无差别过滤; 289104: 勇敢; 289105: 生长; 289106: 腐植循环; 289107: 养分重吸收; 298054: 金月陨星; 298055: 赤月陨星; 298057: 捣药; 298058: 顽强; 298059: 迷梦; 298060: 祈愿; 298061: 婵娟; 298062: 潮汐; 298063: 迅击; 298064: 炽焰; 298065: 余温; 298066: 钢骨; 298067: 余烬; 298068: 爆燃; 298069: 盗魂钟; 7000381: 陨星攻击; 7000383: 陨星攻击; 7030620: 麦芒; 7040690: 暖阳; 7040700: 星火; 7050520: 废弃; 7050530: 汇流; 7050531: 应对！汇流; 7060280: 分光; 7060290: 闪光弹; 7070330: 广播; 7070340: 拖拉机; 7100330: 废弃; 7100340: 废弃; 7130360: 信息素; 7130370: 迁飞扩散; 7150400: 月影交错; 7150410: 惊鸿一瞥; 7150420: 无风; 7150421: 应对！无风; 7170320: 废弃; 7170330: 小型打劫; 7170340: 回收; 7170350: 掠影; 7170360: 离魂术; 7180450: 掉包; 7180460: 暴打; 7190460: 重组; 7190461: 应对！重组; 7190470: 月蚀; 7190480: 仰望夜空; 7190481: 废弃; 7190490: 观测者效应; 7190491: 废弃; 7190500: 量子涨落; 7190510: 奇点; 7190520: 引力偏转; 7190521: 应对！引力偏转; 7880058: 魔能爆; 7880059: 风起; 7880060: 主场优势; 7880061: 棘刺; 7880062: 光合作用; 7880063: 打湿; 7880064: 蓄势待发; 7880065: 速冻; 7880066: 龙威; 7880067: 增程电池; 7880068: 疫病吐息; 7880069: 加油; 7880070: 降灵; 7880071: 纺纱; 7880072: 二律背反; 7880073: 应对！二律背反; 7880074: 毒液渗透; 7880075: 冰点; 7880076: 应对！冰点; 7880077: 折射

## Before / after parser samples

| Sample | Before | After |
| --- | --- | --- |
| Handbook 440 | pet 651904; one misaligned topic | pet 3746; 5 topics, capture reward 202001 |
| Handbook 466 | pet 658560; one misaligned topic | pet 3796; 5 topics, final task 使用1次麦芒 / count 1 / reward 205201 |
| Handbook 443 | pet 652672; empty topics | pet 3761; 3 topics (capture, talent, evolution) |
| LEVEL_SKILL_CONF 3001 | first level 571 / stage 572 / skill 573; 5 levels, 8 machines | first level 1 / stage 1 / skill 7020360; 16 levels, 17 machines; first machine 毒沼 7120200 |

All 468 handbook entries reference existing PETBASE IDs. All topic rewards resolve to REWARD_CONF. All level and machine skills resolve to SKILL_CONF. These checks now run in the exporter before writes. The 17 tables parse with strict refs and exact structure lengths. 18 manifest sentinels cover old/new names, descriptions and nested content. Manifest: `NRC/bin-data-sources.s4.json` (ignored, one current merged source; no invented pak-layer assignments).

## 修复范围与回归验证

- `decode_struct`：抽取顶层和嵌套结构共用的 bitmap 解码；不再假设所有字段存在，拒绝截断与尾部多余字节。
- `decode_struct_array`：按 uint32 引用列表逐个解码独立结构，元素边界来自 ref table。
- `decode_ref_blob` / `decode_value`：正确区分结构数组、primitive 数组和字符串数组；嵌套字段继续经统一引用解析。
- `encoded_size`：数组/结构/字符串字段在父结构内占一个 32 位引用，primitive 元素按自身宽度读取。
- `parse_row`：复用 `decode_struct`，缓存 row infos，消除每一行重新扫描整个索引的开销。
- `export_bin_data.py`：写盘前额外检查图鉴宠物、任务奖励和升级/技能石跨表语义关系。

`yarn test:bin-data-export` 共 12 项测试全部通过，包括原有 5 项、真实 440/466 引用链、任务字段与 S3 技能对照、通用 DynamicArray<EStruct> 多层引用及缺省字段、跨字节 bitmap、损坏长度/未解析子引用、跨表伪 ID 拒绝，以及当前 NRC 完整快照哨兵和语义验证。当前快照测试在未安装 NRC 的环境显式跳过，独立字节 fixture 仍然运行。

图鉴前端使用同步脚本生成的 `src/lib/generated/handbookIds.json` 集合，替换固定 442 上限；质量测试直接验证该集合与 PET_HANDBOOK 一致。S3 固定占位 ID 范围和固定无图鉴 ID 列表改为当前关联及占位名称检查，允许 3761 等旧 ID 在 S4 正式实装。

S4 头像使用 `img_…` 资源键。同步脚本提取完整资源键，仅对旧 `JL_` 前缀保持兼容；FriendPortrait、蛋组图表与徽章测试使用同一头像路径函数，不伪造拼音资源名，也不复制替代图。

## 图片导入与尚未通过的验收

| 类型 | 实际新增转换 | 已存在跳过 | 缺失资源键 | 转换失败 |
| --- | ---: | ---: | ---: | ---: |
| Pet1024 | 75 | 738 | 24 | 0 |
| SkillIcon / 其他战斗引用 | 26 | 613 | 4 | 0 |
| FeatureIcon | 13 | 212 | 0 | 0 |

本次新增共 114 张真实 FModel 资源。未使用 SkillBase 或生成图片替代。全部 SkillIcon 源为 128×128；FeatureIcon 为 256×256 或 500×500。Pet1024 中 821 张为 1024×1024，3 张旧非方形资源没有进入本次转换；导入时仍强制检查待转换源图为正方形。

**更正：用户已在游戏内确认当前世界图鉴为 468。云梦豚 3784（图鉴 467）和长江豚 3785（图鉴 468）均为当前世界图鉴已实装内容，但客户端缺失其 PETBASE 所引用的 Pet1024/Pet256 资源。它们不是预载未实装记录。**

用户已确认在 FModel Loading Mode = All 下，对应 Pet1024/Pet256 package 仍不存在；这是独立的上游资源缺失（upstream/source asset missing），不是 FModel 导出失败，也不是未实装证据。PetOutline1024 的同名资源不属于 PETBASE 引用目标，不能替代。PETBASE 已引用以下普通/异色头像及 Pet256 下同名资源：

目录：`NRC/Content/NewRoco/Modules/System/Common/Icon/Pet1024/`

- `img_Wat_ZhuZhuTun1_001_Res.png`（云梦豚普通）
- `img_Wat_ZhuZhuTun1_101_Res.png`（云梦豚异色）
- `img_Wat_ZhuZhuTun2_001_Res.png`（长江豚普通）
- `img_Wat_ZhuZhuTun2_101_Res.png`（长江豚异色）

此前徽章测试因缺图失败，该历史结果不代表精灵未实装。本次撤销头像可用性条件，恢复原有实装判断，不以头像文件是否存在决定 implemented；3784/3785 保持正常实装，不隐藏、不删除、不增加 ID 白名单。未重新生成数据，上一轮加入头像条件后也未执行同步，因此生成结果仍保留两者的 implemented=true。

资源问题应独立分类：FModel 对应源资源存在但网站缺失，属于项目导入/路径错误；只有确认当前客户端对应 package 本身不存在，才能归类上游资源缺失。仅本地 NRC 缺文件不足以区分上游缺失与导出遗漏。本次不修改资源检查脚本，也不将历史失败改写为通过。其余 20 个缺头像引用为原有未实装记录；4 个缺技能图标键为原有 `700025`、`btn_huangchong_png`、`img_BossSkill`、`img_BossSkill1`。特性图标没有缺失。

抽查 3761 / 3766 / 3796 的名称、种族值、图鉴关联、特性及描述正常，升级/技能石/血脉技能条数分别为 13/15/18、15/16/18、13/12/18。生成结果共 1147 精灵、631 条标记已实装、4436 条物品。这里的“已实装”沿用项目基于配置的判断，并非对每个剧情/首领变体作独立游戏内确认。

## 此次最小修改之前的命令结果

后续仅修改实装判定与本报告，未重新同步生成数据，未运行测试、type-check、build 或审计；下表不是这次修改后的验证结果。

| 命令 | 结果 |
| --- | --- |
| yarn export:bin-data --dry-run | 17 表通过，严格引用与结构长度校验 |
| yarn export:bin-data --manifest NRC/bin-data-sources.s4.json --dry-run | 17 表及 18 哨兵通过 |
| yarn export:bin-data --manifest NRC/bin-data-sources.s4.json | 完成写入 |
| yarn sync:pet-data | 完成生成 |
| yarn import:fmodel-icons | 114 张新增转换，0 转换失败；缺图如上 |
| yarn test:bin-data-export | 12 项通过 |
| yarn test:pet-data-quality | 通过 |
| yarn test:skill-acquisition | 通过，610 个规范技能组 |
| yarn test:badge-trials | **失败：3784 / 3785 缺头像** |
| node scripts/test-handbook-progress.mjs | 通过 |
| yarn type-check | 通过 |
| yarn build | 通过；有 OpenCV Node 模块浏览器 externalization 和大 chunk 提示，不是构建失败 |

无未确定的嵌套二进制布局，没有未解析引用或伪 ID 遗留；3784/3785 已按用户游戏内确认更正为正式实装，头像问题独立归类上游客户端资源缺失。本次未运行测试、type-check、build 或审计，未提交或 push，也未修改/引用 NRC_S3_backup 的内容。
