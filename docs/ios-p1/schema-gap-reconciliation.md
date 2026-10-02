> 历史调查，已被 [八功能 scope pruning](scope-pruning.md) 取代；其中扩展奖励/材料 schema 的提案不再适用。

# P1 schema-gap reconciliation — 决策报告

本轮只调查和提出决策，未修改冻结 schema、canonical 生成器/校验器、P0 bridge/UI、Web 数据，也未批量转图。现有五类错误继续严格失败。证据以**当前 public/data/BinData → scripts/sync-pet-data.mjs → Web 消费**为主；本机 NRC BinConf 用于核对字段类型，S3 备份只作为历史结构证据，不当作当前数据。当前 PET_HANDBOOK / PET_EVOLUTION_CONF 的 tables 镜像与 BinData 结构相等。

机器可核对的静态快照见 [schema-gap-evidence.json](/Users/batzz/Projects/rocom.aoe/docs/ios-p1/schema-gap-evidence.json)，只读审计脚本为 [audit-schema-gaps.mjs](/Users/batzz/Projects/rocom.aoe/docs/ios-p1/audit-schema-gaps.mjs)。统计中“出现次数”按原始配置、唯一奖励包或课题展开分别注明，不能把上一轮 7,114 条诊断当作实体数。全量读取用于枚举实际形态，不是完整测试，没有执行 sync、canonical generate、build、runtime 或 UI。

## Schema-gap matrix

| blocker | upstream evidence | current frozen schema | why incompatible | recommended resolution | additive / breaking | proposed schemaVersion impact |
| --- | --- | --- | --- | --- | --- | --- |
| 捕捉阈值 / rate | [源配置字段](/Users/batzz/Projects/rocom.aoe/NRC/Content/ScriptC/Data/Bin/BinConf/MONSTER_CATCH_CONF.json:20)、[Web 生成连接及选择](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:692)、[读取/分类](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:401)、[原值/百分比显示](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:555)。当前原表没有 catch_guarant_rate 字段；748 个非空 catch_info 的 rate 均 null | [PetDetail.catchInfo](/Users/batzz/Projects/rocom.aoe/docs/ios-p0/content.schema.json:412)：required rate(number|null)、habitatText、notes | 真实 threshold 是原始门槛，不是概率；rate 没有单位约定，也没有 threshold/ballLevel 字段。将已知阈值隐藏进 notes 不能成为正式的结构化映射 | 改成有明确来源的 thresholdRaw、ballLevelRaw、guaranteeRateBasisPoints(nullable)，保留 habitatText/notes；删除/弃用含糊 rate；不计算未知概率 | 数据模型上新增 raw 字段；删除/重命名 rate 是 breaking；严格 v1 解码器也不接受新增字段 | **v2**；仅把当前缺失 guarantee rate 表达为 null 可 mapping，但不能解决完整 gap |
| 多道具进化 | [PETBASE 结构](/Users/batzz/Projects/rocom.aoe/NRC/Content/ScriptC/Data/Bin/BinConf/PETBASE_CONF.json:282)、[Web 逐项消费](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:1897)、[实际 3005](/Users/batzz/Projects/rocom.aoe/public/data/BinData/PETBASE_CONF.json:521)。58 配置有两个声明槽，54 完整、4 含缺失 ItemID | [Evolution](/Users/batzz/Projects/rocom.aoe/docs/ios-p0/content.schema.json:724)：单 itemId|null、level|null、conditionText|null | 单 ID 不保存 N 个 FK、数量、洛克贝成本和源 task ID；文本不是结构化 FK。即使 N=1，也丢 quantity | 以 itemRequirements: array|null 的 `{itemId,count,sourceOrdinal}` 替代单 itemId；保留 moneyCostRaw/sourceTaskId/原条件文本。每项 ID/数量必须完整有效；4 条缺 ID 数据仍失败 | 替换单值关系为列表是 breaking；费用/来源字段是语义 additive、wire breaking | **v2**，另需修复/明确处理真实缺失源 ID，schema 修复不能代替源修复 |
| 课题货币 / 资源奖励 | [REWARD entry 模型](/Users/batzz/Projects/rocom.aoe/NRC/Content/ScriptC/Data/Bin/BinConf/REWARD_CONF.json:74)、[Type 1/2 分流](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:1306)、[Web Type=1 道具链接](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:3326)、[资源独立展示](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:3504)。597 个课题奖励包内 Type=1 1,071 项、Type=2 601 项 | [HandbookTopic](/Users/batzz/Projects/rocom.aoe/docs/ios-p0/content.schema.json:936)：rewardItemIds: ItemID[]，没有数量/资源实体 | Type=2 目标是 VISUAL_ITEM_CONF，不是 BAG_ITEM_CONF；纯 ID 数组还丢每项 count（即使全部为 Type=1） | 新增资源目录，Reward 用 kind=item/resource 的带数量引用；明确 namespace、源 RewardID 和 ordinal；rewardItemIds 移除或只作为有一致性检查的兼容派生字段 | 新增资源实体是语义 additive；严格顶层/对象扩展及奖励字段替换是 wire breaking | **v2**；不能靠把资源 ID 填进 ItemID 解决 |
| 配置 9001 的属性 20 | [原始 unit_type=[1]](../../public/data/BinData/PETBASE_CONF.json#L108573)、[Web Unknown=20](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:27)、[raw 映射](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:36)、[fallback](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:808)。当前 9 配置生成 Unknown，均未实装；正常 types 仅 1–19 | [Pet 字段](/Users/batzz/Projects/rocom.aoe/docs/ios-p0/content.schema.json:253)及[语义契约](/Users/batzz/Projects/rocom.aoe/docs/ios-p0/contracts.md:11)：typeIds 1–2 个正常类型、FK 必须可解析 | normalized 20 是生成器 sentinel，不能加一个没有弱点/抵抗定义的战斗属性。9001 的默认血脉也继承此 sentinel | 保留全部配置时，引入显式 typeResolution（known/unresolved、源 raw 值及生成层 sentinel 来源），未解析配置与正常战斗类型分开；禁止虚构 BattleType 20。另一方案是独立、显式批准的发布根集合排除这 9 项，记录原因和引用闭包 | 保留全配置并表达 unresolved 是契约 breaking；显式改变发布范围不是 schema 修改，但也是需决策的内容策略，不能静默实施 | **推荐全配置 v2**；批准根集合排除且闭包不引用时可维持 v1，当前未批准/未实施 |
| WebP asset | [导入器固定 WebP](/Users/batzz/Projects/rocom.aoe/scripts/import-fmodel-icons.mjs:140)、[头像 URL](/Users/batzz/Projects/rocom.aoe/src/lib/petPortrait.ts:2)、[浏览器 img 消费](/Users/batzz/Projects/rocom.aoe/src/components/FriendPortrait.vue:62)。检查 824 头像 + 2,236 物品文件，全部 RIFF/WEBP 头有效，3 个样本经 metadata 确认为 WebP | [Asset](/Users/batzz/Projects/rocom.aoe/docs/ios-p0/content.schema.json:1204)：format=png/jpeg/placeholder，另有 sourcePath/sourceSha256 与 outputPath/outputSha256 | 当前只有源 WebP，没有符合 schema 的输出位图与尺寸/hash；不是 enum 定义错误，缺的是规划中的转换阶段 | 独立 deterministic asset-conversion：只读 WebP，输出固定 PNG/明确 JPEG profile 后补齐 Asset 字段，再严格发布 canonical；sourcePath 仍可指向 .webp | 不改 schema；新增构建阶段 | **v1 已可表达**；随其他 gap 的 v2 包一起发布也无需为 WebP 单独升级 |

**版本建议：**集中评审为内容 schema v2，不逐项产生 v2/v3/v4。v1 的 additionalProperties=false、所有字段 required、Manifest.schemaVersion const=1 意味着即使“只增加字段”，已有严格 reader 也不兼容。本文的 v2 只是提案，原 schemaVersion、rulesVersion、minimumAppBuild 全部未改；后续需按真实消费者兼容性确定 minimumAppBuild，不能现在猜一个 build。没有改 PVP 规则语义的证据，不建议因这些内容结构变化修改 rulesVersion。

## 1. 捕捉阈值与 rate：原值可保留，概率不能推导

真实连接路径是 MONSTER_CONF.id → MONSTER_CATCH_CONF.id，再通过 MONSTER_CONF.base_id 连接 PetBaseID。Web 生成器会在一个 base 的多个候选中，取**首个有限 Catch_Threshold 候选，否则取首个候选**；不是取最大、最小或平均，也不检查数值冲突。[生成逻辑](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:692)

| 字段 | 原定义 / 当前快照 | Web 行为 | nullable 与单位结论 |
| --- | --- | --- | --- |
| Catch_Threshold → catch_threshold | EUint32；2,324 行中 1,751 有值，值集合 250/500/1,000/10,000/50,000；生成详情仅 250/500/1,000 | 原样显示“捕捉阈值”，不比较、不除以百分比、不用它执行 Web 捕捉概率计算 | 原始无量纲门槛整数；游戏内部实际阈值公式/量纲缺证。原字段未编码时生成 null，不能把它当 0 或 rate |
| catch_guarant_rate | 当前 MONSTER_CATCH_CONF BinConf **未定义**；当前 BinData 2,324 行完全无此字段；748 个非空详情对象全部为 null | 难度分段：>=10000 必定、>=5000 非常容易、>=2000 容易、>=500 普通、>0 困难、<=0 无法野外捕获；UI 显示 raw/100 %，普通球约 ceil(10000/(raw×1.2)) 次，高级球约 ceil(10000/(raw×2)) 次 | Web 数值尺度以 10000 为满刻度，100 单位显示 1%；只能称“保底率/保底进度的 Web 表示”，**不证明独立单次概率**。当前没有数值样本，不能凭代码分支声明真实有效范围只有 0…10000 |
| Catch_Ball_level → catch_ball_level | EUint32；原表 1,376 有值且均为 1；生成详情 353 个为 1、395 个 null | 检索当前 src，仅接口声明，无消费/比较/显示 | 原始球等级整数；缺值为 unknown/not supplied，不代表等级 0；1 是观测值，不是永久 enum |

[难度分类](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:401)、[保底次数](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:466)、[按球估计](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:480)、[原始 UI](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:1950)、[Web 接口](/Users/batzz/Projects/rocom.aoe/src/lib/interface.ts:150)。公式是 Web 展示启发式，没有游戏实际判定实现的证据；不应作为新的原生计算契约。

nullable 必须保留两层区别：399 个详情 catch_info=null 表示没有匹配记录；748 个非空对象中 149 个三字段全 null 表示有匹配记录但没有这些值。Web hasCatchInfo 只看 threshold/rate，故全 null 对象不显示，但 canonical 不能据此把它销毁。[可见性](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:575)

建议正式字段映射（**非实现**）：

- thresholdRaw ← catch_info.catch_threshold，精确保留整数/null；未来若直接从源接入，类型约束可参考 EUint32，不用观测最大值 1000 作限制。
- ballLevelRaw ← catch_info.catch_ball_level，精确保留整数/null。
- guaranteeRateBasisPoints ← catch_info.catch_guarant_rate；当前合法地全部 null，只有以后真实提供该字段并重新核对后才允许非 null。不把 threshold 填进去，也不凭暂无数据合成 rate=0。
- habitatText 若沿用，来自已有 world_profile.description_habitat 显示文本，作为独立文字信息，不用于推导 rate。[world_profile 生成](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:347)

补充确定性风险：729 个 base 有多个 catch 候选，269 组原三元组不一致。3064 的候选有 threshold=1000/500/250/50000，当前生成选择 1000。仅消费固定生成详情可保持 Web 当前结果；以后若重新从原 MONSTER 表选代表，必须显式决策选择规则并保留 sourceMonsterId/来源，不能顺手换成排序首条或极值。映射新 schema 不会自动解决这一源归并策略问题。

## 2. 多道具进化：当前 N=2；4 条不完整源仍是独立阻断

当前 BinConf 有 evolution_need_level、evolution_need_money、evolution_task_id、evolution_need_items。items 是 EStruct 数组，结构 `{evolution_need_item:EUint32, number:EUint32}`，声明 ArrayDim=4；解码器根据引用 blob 解出数组，实际长度不能仅凭这个声明推定总是 4。[当前定义](/Users/batzz/Projects/rocom.aoe/NRC/Content/ScriptC/Data/Bin/BinConf/PETBASE_CONF.json:264)、[struct array 解码](/Users/batzz/Projects/rocom.aoe/scripts/export_pet_json.py:196)

当前 1,147 个 PetBase 的结构组合：

| 出现过的形态 | 配置数 |
| --- | ---: |
| 没有这些 requirement 字段 | 672 |
| 只有 level | 417 |
| level + money + items | 54 |
| money + items | 3 |
| level + money + items + taskId | 1 |

items 字段未出现的 1,089 行不等于有显式 `[]` 或“已证实免费进化”；它只表示没有声明这组道具参数。有字段的 58 行**均为两个槽**。完整正 ItemID 条目统计：54 行两个有效项，4 行一项完整 + 一项缺 ItemID；没有完整、明确仅单道具的当前实例。代码采用逐项遍历，不存在单道具限制，因此模型必须容纳 0/1/N；当前数据实际证明的是没有声明与 N=2，不应伪称已经观察到完整 N=1/N=3/N=4。

水灵 3005：level=36、money=30000、items=[{itemId:100202,count:10},{itemId:100103,count:5}]，另外有 taskId=1130023。Web 生成全部道具文本、等级和洛克贝条件，但没有读取此 taskId 来形成条件。[源](/Users/batzz/Projects/rocom.aoe/public/data/BinData/PETBASE_CONF.json:521)、[条件生成](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:1870)、[Web 展示逐条 conditions](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:2414)

生成详情共有 61 种不同条件文字，当前只有“等级达到 X 级”“消耗 X 洛克贝”“消耗道具 ×N”三种形态（完整文字枚举在 evidence）。观测 level=1…100，Web 仅在 >1 时显示；money=10000…50000，数量=1/2/5/10。观测范围不作为将来硬限制；源存在的 level=1 不能因为 UI 不显示就当缺失。

S3 BinConf **历史上**还定义 evolution_need: `{evolution_need_type,data1[],data2[]}`。生成器有性别、路线、蛋组、羁绊、分支、血脉、技能试炼、形态联动、区间、能量、材料、击败指定类型等分支；当前 BinConf 没有该字段，当前 BinData **0 条**实际出现。不能把这些历史分支列为本快照“真实条件枚举”，也不能据此宣称 type enum 已完整验证。[历史定义](/Users/batzz/Projects/rocom.aoe/NRC_S3_backup/Content/ScriptC/Data/Bin/BinConf/PETBASE_CONF.json:322)、[保留的描述函数](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:1950)

3019/3303/3304/3305 的首个 item 槽均为 `{number:5}`，没有 evolution_need_item；其余显式 ItemID 都能连接 BAG_ITEM_CONF。源解码采用 presence bitmap：未编码字段不会自动填 0。[源 3019](/Users/batzz/Projects/rocom.aoe/public/data/BinData/PETBASE_CONF.json:2408)、[解码](/Users/batzz/Projects/rocom.aoe/scripts/export_pet_json.py:173)。Web 生成器会跳过不完整项，这不是可继承的严格规范化行为。[跳过逻辑](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:1903)

建议 itemRequirements required but nullable：源字段未声明 → null；明确空列表 → []；完整条目 → 保留 itemId/count/sourceOrdinal；不完整条目 → 失败。moneyCostRaw/sourceTaskId 亦显式 nullable。保留 conditionText 只服务可读说明，不用反解析文字决定 ID；源 task ID 是否存在/对应哪个源表须另取确证，不把它猜成已支持的任务条件。即使换 v2，四个缺 ItemID 槽仍不能合法导出。

## 3. 课题奖励：物品与资源是不同命名空间，数量不可丢

`PET_HANDBOOK.pet_topic[].topic_reward` 指向 REWARD_CONF 的奖励包；包里的 RewardItem[] 才是 `{Type,Id,Count,...}`。奖励包顶层 Type 与 entry.Type 不是同一层含义。当前 entry 定义还支持 DropWeight 等字段；不能把整个奖励模型当作一个 ItemID 数组。[定义](/Users/batzz/Projects/rocom.aoe/NRC/Content/ScriptC/Data/Bin/BinConf/REWARD_CONF.json:74)

Web 映射明确：entry.Type=1 → BAG_ITEM_CONF.id/name/icon；entry.Type=2 → VISUAL_ITEM_CONF.id/displayName/bigIcon/iconPath。后者包括货币，也包括经验和研究点，并非全是“currency”。Web 输出仍保留 type/id/name/icon_id/count。[生成](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:1277)

当前课题引用 597 个不同奖励包，原条目 1,071 个 Type=1、601 个 Type=2；所有这些条目都有 Count，当前无 dangling ItemID/ResourceID。生成的 handbook-rewards 同样只有 1/2 两类。上一轮 3,375 是每个课题引用展开后的资源诊断次数，并非 3,375 种资源。

| 课题出现的 kind | 目标身份 | 实际资源 |
| --- | --- | --- |
| Type=1 / item | BAG_ITEM_CONF / ItemID | 例如 100699 分光水晶，count=50 |
| Type=2 / resource | VISUAL_ITEM_CONF / ResourceID（独立于 ItemID） | 3 许愿星、7 魔法经验、17 课题研究点 |

例：202001=[resource:7×150,resource:17×5]；202002=[item:100699×50,resource:17×10]。[原奖励](/Users/batzz/Projects/rocom.aoe/public/data/BinData/REWARD_CONF.json:54796)、[资源 7](/Users/batzz/Projects/rocom.aoe/public/data/BinData/VISUAL_ITEM_CONF.json:86)、[资源 17](/Users/batzz/Projects/rocom.aoe/public/data/BinData/VISUAL_ITEM_CONF.json:543)

Web 对 Type=1 链接 `/items?highlight=<id>` 并读取道具详情；资源只展示名称、icon、数量，没有套用道具详情/FK。[道具分支](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:3326)、[资源分支](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:3504)

全 REWARD_CONF 原 entry 出现过的 Type 代码为 **1,2,3,4,6,10,11,13,14,15,17,18,20,21,22,23,26,28,29,30,37**。Web handbook 生成器只处理 1/2，会忽略其他值；当前课题集合没有其他值，所以本 gap 不需要实现 21 种奖励业务。其余代码的正式枚举含义没有在当前 Web 消费中证实，不为它们猜名字；以后若课题出现其他 Type 必须新诊断，不自动归入 resource。

建议 `resources[]` 使用独立 ResourceID；`HandbookTopic.rewards[]` 为带 kind、targetId、count、sourceRewardId、sourceOrdinal 的 discriminated union，严格按 kind 连接 items/resources。保留原顺序，不把同 ID 合并/去重以免丢数量或位置；ItemID 与 ResourceID 即使数值相同也不冲突。资源显示名/图标精确映射已有源字段，资源说明字段是源拼写 `discription`，需明确适配，不能误写后当缺值。不得把完整奖励 JSON 塞入 sourceParameters 作为绕过正式 schema/FK 的方案。

## 4. 属性 20：生成层 Unknown sentinel，而非第 20 个战斗属性

这儿存在两套编号，必须分开：

- **raw unit_type=20** 经映射成为 **normalized TypeID=18 / Phantom**，是已有正常属性。
- **normalized TypeID=20 / Unknown** 是生成器自己定义的 UNKNOWN_TYPE_ID；并不是 raw=20 的直接保留。
- 9001 的 raw 值是 **[1]**，RAW_TYPE_TO_NORMALIZED_ID 没有 1，所以 fallback 为 normalized 20；default_legacy_type 直接复制 main_type，故同样为 20。[定义](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:27)、[映射表](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:36)、[fallback](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:808)、[默认血脉来源](/Users/batzz/Projects/rocom.aoe/scripts/sync-pet-data.mjs:324)

当前 Unknown 九项：9001/9002/9003（raw=[1]）、9819/9820（源 unit_type 缺失）、10000（raw=[0]）、10001（raw=[1]）、10021（raw=[21]）、10022（raw=[22]）；均 implemented=false。普通属性表只有 1–18 加 19 Leader，没有 20 和任何 Unknown 克制定义。[源 9001](/Users/batzz/Projects/rocom.aoe/public/data/BinData/PETBASE_CONF.json:108573)、[生成配置](/Users/batzz/Projects/rocom.aoe/public/data/pets/9001.json:5)、[类型表](/Users/batzz/Projects/rocom.aoe/public/data/types.json:1)

结论的证据边界：**normalized 20 确定是 Web fallback sentinel**；没有找到 raw=1/0/21/22 的正式游戏 enum 语义，因此不能进一步断言它们都合法、都是历史值，或都是脏数据。9001 确实是源内真实存在的“幸运惊喜盒”配置，不是 JSON 损坏证据；其“特殊/内部配置”的判断来自名称、未实装状态和没有普通属性定义，仍不能伪造 Normal 类型。

Web 图鉴读取 public-visible 配置（当前只排除 3777），类型选项从宠物现值生成，因此切到未实装/全部状态时 Unknown 可出现；PVP/配队已实装过滤会排除这些九项。直接详情显示已有属性标签。属性关系页来自 types.json 并排除 Leader，Unknown 不进入关系图；当前倍率 helper 对未找到类型返回 1，这是 Web 容错，不是 Unknown 有中性战斗关系的证据。[图鉴候选](/Users/batzz/Projects/rocom.aoe/src/pages/encyclopedia.vue:728)、[筛选选项](/Users/batzz/Projects/rocom.aoe/src/pages/encyclopedia.vue:204)、[状态过滤](/Users/batzz/Projects/rocom.aoe/src/pages/encyclopedia.vue:311)、[PVP 候选](/Users/batzz/Projects/rocom.aoe/src/pages/pvp-lite.vue:736)、[配队](/Users/batzz/Projects/rocom.aoe/src/pages/team.vue:69)、[关系页](/Users/batzz/Projects/rocom.aoe/src/pages/attributes.vue:493)、[倍率容错](/Users/batzz/Projects/rocom.aoe/src/features/battle-query/typeDefenseMatchup.ts:73)

推荐保留全部 PetID 并增加显式 resolution 状态。known 配置仍严格要求 1–2 个正常 TypeID；unresolved 配置单独记录 rawUnitTypeIds（缺失为 null，与 [] 区分）、源生成层 normalized 值和 defaultLegacy sentinel，并没有可参加正常属性计算的引用。任何允许 typeIds=[] / defaultLegacyTypeId=null 的策略都必须同时要求这个明确状态与来源记录，**不是通用放宽 nullable/FK**。不新增 BattleType 20，不为它填空 weak/resist。

备选是在已明确的发布根集合中排除全部九个非游戏候选，并以独立清单保留来源/理由/旧 ID 策略。静态检查当前没有父配置、shiny member 或 handbook 引用这些九个 ID，但这不是完整发布依赖闭包证明；原方案还要校验技能/进化/其他关联。P0 契约保留未实装语义，Web 未实装图鉴也可见，故这属于需要批准的产品范围变更，不能把它冒充一个无损 mapping patch。本轮不选择/实施该排除。

## 5. WebP：需要独立转换阶段，v1 已能表达最终产物

必要静态检查覆盖两个现有目录的全部文件头：friends 824 个 / 57,528,034 bytes，items 2,236 个 / 12,045,892 bytes，全部 RIFF/WEBP 标记有效；不是只相信扩展名。sharp.metadata 抽样确认 JL_miaomiao、JL_songzai 都是 1024×1024、有 alpha 的 WebP，700005 为 128×128、有 alpha。这里只读 metadata，没有解码重写或批量转图，未声称所有文件已完整像素解码验证。完整格式/解码检查应在真正转换阶段执行。

Web importer 把源图以 `.webp({quality:85,alphaQuality:100,effort:6})` 写入 public；头像由 petPortrait helper 定位 .webp，FriendPortrait 使用浏览器 img，技能/奖励也使用 items 下 WebP。[导入](/Users/batzz/Projects/rocom.aoe/scripts/import-fmodel-icons.mjs:126)、[头像 helper](/Users/batzz/Projects/rocom.aoe/src/lib/petPortrait.ts:2)、[头像消费](/Users/batzz/Projects/rocom.aoe/src/components/FriendPortrait.vue:62)、[技能消费](/Users/batzz/Projects/rocom.aoe/src/components/SkillIcon.vue:25)、[奖励消费](/Users/batzz/Projects/rocom.aoe/src/pages/pets/[id].vue:1000)。浏览器失败时的名字 fallback 是 Web UI 行为，不是原生构建时的素材批准。

Asset.format 结合 outputPath/hash/width/height，应明确解释为**输出格式**；sourcePath 可保持 .webp。因此不需要扩 format enum 加 WebP，更不需要把已有 WebP 标为 placeholder。[冻结字段](/Users/batzz/Projects/rocom.aoe/docs/ios-p0/content.schema.json:1204)

建议独立阶段（设计提案，未执行）：

1. 输入只读源清单，按稳定 assetId 排序；每项包含 purpose/sourcePath/sourceSha256、版本化 conversion profile。检查真实格式、尺寸、alpha、页数；明确拒绝未支持动画/多页内容、坏解码和源 hash 变化。所有缺图列错误；获正式记录的例外再走独立 knownMissingAssets 政策。
2. profile 固定方向/颜色处理、resize 尺寸和 kernel、fit、不放大规则、PNG/JPEG 编码参数、metadata 保留策略；透明源优先 PNG，JPEG 只用于明确配置且验证完全不透明的项。Grid/Hero 两档的具体尺寸继续依照资源计划单独决策，不在本调查中拍定视觉策略。
3. 固定 Node/Sharp/libvips/WebP/PNG/JPEG 编码库、架构与构建环境，保留版本和 profile hash。仅锁 yarn.lock 不足以保证不同 native codec/平台的位图字节相同；跨平台一致性应以实际双生成对照证明。
4. 输出仅到 build/ios-content 的 staging，路径由稳定 assetId/purpose/profile 推导，不用时间或 UUID；strip 非必要时间/EXIF 字段。生成后复读实际 output format/width/height/sha256，不能凭扩展名或请求的编码格式填 metadata。
5. 内部 source-only 中间清单与发布 canonical 区分；转换完整之后才组装 assets.json/manifest 并执行当前严格闭包/FK/hash 验证。转换失败不发布新包，保留旧包。
6. 同一固定输入和固定环境独立转换两次，比对输出文件字节、每项 hash、assets.json 和 manifest；记录结构/图片字节量。性能、图片质量、包体裁剪另属后续验收，不在本轮做 UI 或 runtime。

完成转换时 v1 Asset 可以同时记录源 WebP hash 与输出 PNG/JPEG hash；因此这项是**构建阶段缺失**，不是必须修 schema 的数据模型缺口。

## 决策边界与建议审批顺序

- 可保持 schema：WebP → 明确转换输出后的 Asset mapping。当前不存在的 guarantee rate → null 本身也是有证据的 nullable mapping，但不能代替 threshold/ballLevel 的结构化表达。
- 必须正式修 schema 才能完整表达：捕捉模型、进化多项及数量、课题跨命名空间奖励及数量。推荐一起评审 v2。
- 属性 20：**不扩战斗 enum**。保留全配置则正式增加 unresolved 模型并修语义契约（v2）；唯有另行明确批准缩小发布根集合，才可能无 schema 改动地排除这组 sentinel 配置。
- schema 修复后仍必须保留源失败：四个缺 ItemID 进化槽、未经决策的 catch 多候选冲突、以后出现的新 reward kind，以及未转换/未经记录处理的缺图。不能因为版本升到 v2 就自动通过。

本轮只提交此 matrix 与静态证据。先决策 v2 字段/未知类型政策，再授权修改 schema/映射；资源转换阶段独立实施。P0 architecture frozen 继续有效，数据 schema 是否正确由上述真实证据决定。
