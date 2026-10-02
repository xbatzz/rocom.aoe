# P1 八功能范围与 scope matrix

本文件取代此前以完整 Web 数据为目标的 gap 提案。仅服务图鉴、属性克制、技能查询、配队、PVP助手、异色收集、草系徽章、命定勇者。活动、道具图鉴/库存、商店、完整任务/课题系统、徽章/课题/货币奖励、进化材料及材料拥有状态全部 out of scope。首领材料按用户规则视为已拥有，不导出或验证消耗条件。

required 表示目标功能直接显示/筛选/计算；indirect 表示维持 required 的身份、来源或 FK；out of scope 表示不生成、不连接、不以其错误阻止导出。不能用一张大表“可能将来有用”证明 required。

| 原 19 个实体 | 分类 | 保留的 required 字段 | 保留的 indirect 字段 | out of scope / 决策 |
| --- | --- | --- | --- | --- |
| pets | required，图鉴/配队/PVP/收集 | petId、speciesId、handbookId、nameZh、form、typeIds、defaultLegacyTypeId、implemented、publicVisible、isLeader、leaderPotential、attackStyle、baseStats、searchAliases、ordinal | resourceKey、parentPetId、portraitAssetId | 非目标目录且未被 FK 闭包引用的内部/敌人/随机配置排除；不按名称或未知属性筛选 |
| petDetails | required，图鉴详情 | worldProfile 的 type_desc/description_habitat/introduction；catchInfo 原始 thresholdRaw/guaranteeRateBasisPoints/ballLevelRaw | petId、traitId | breedingSummary、体型/性别/蛋组/孵化概率、移动/分类/地域数组；不做捕捉概率计算 |
| types | required，克制/查询/PVP | typeId/name/nameZh/normalBattleType、weakToTypeIds/resistToTypeIds | — | 不新增 Unknown 战斗属性，不生成缺失关系 |
| skills | required，查询/配队/PVP | skillId/nameZh/category/typeId/power/energyCost/description | iconAssetId | 只有排除配置使用、且不是 base moves/有效检索组依赖的技能不导出 |
| skillGroups | required，技能查询 | groupId/displayId/aliasIds/nameZh/ordinal | alias 的真实 SkillID FK | 只保留 scoped 宠物可获得的组或 base moves 所在组；不把检索组 ID 当 SkillID |
| petSkills | required，合法配招/查询/PVP | petId/skillId/source/legacyTypeId/ordinal | — | 不读取排除配置的详情/配招，不连接其技能关系 |
| traits | required，详情/PVP资料 | traitId/nameZh/description | iconAssetId | 仅保留 scoped 详情引用的特性 |
| evolutions | required，图鉴关系 | sourcePetId/targetPetId | edgeId/ordinal（稳定边身份与源顺序） | level/itemId/conditionText/sourceEvolutionId 字段删除；材料数量、货币、taskId、特殊门槛全部不导出、不验证 |
| families | required，技能查询/两种徽章 | kind/familyKey/representativePetId/memberPetIds/typeIds/ordinal | — | 只按 scoped 宠物生成；两种 family kind 保持独立，无奖励/材料 |
| shinySlots | required，异色 | slotId/seasonId/familyId/targetPetId/representativePetId/memberPetIds | portraitAssetId | 不导出奖励/材料；完整保留赛季/路线身份 |
| badgeFootprints | required，草系/命定勇者 | footprintKey/petId/familyKey/isLeader/stageDepth | — | 只保留足迹/家族进度识别；没有徽章奖励实体或奖励 FK |
| badgeLocations | required，草系 | locationId/nameZh/targetCount | — | 无地区奖励、任务奖励 |
| handbookTopics | out of scope | — | — | 删除整实体/课题内容/奖励引用；图鉴收集的 handbookId 保留在 pets，不需要课题目录 |
| personalities | required，配队/PVP | personalityId/nameZh/modifiers | — | 固定性格定义，不是物品库存 |
| magicItems | required，配队战斗选项 | magicItemId/nameZh/description | — | 仅上游 5 个战斗魔法选项；不从 items/BAG_ITEM 扩大为道具系统，不保存拥有状态 |
| items | out of scope | — | — | 删除整实体及所有 ItemID FK，不创建资源目录 |
| seasons | required，异色筛选 | seasonId/nameZh | 默认赛季 FK | 不保留活动/赛季奖励 |
| battleEffects | indirect，PVP 后续内容读取契约 | kind/parameters/rawDescription/parseVersion/assumptions | effectId/petId/skillId/sourcePath | 此步仍只保留 scoped 技能的 unsupported 描述元数据，不解析/实现 PVP 特例；不声称完成规则计算 |
| assets | indirect，头像/技能/特性图标来源 | sourcePath/sourceSha256/sourceFormat/availability/missingReason | assetId/purpose | v2 是真实源描述，不是已转换运行时图片包；删除 outputPath/outputSha256/width/height/format 等未生成的输出元数据，不转图/造占位 |

发布集合规则记录在 shared/content/ios-scope.json。根集合包括公开真实图鉴配置、已实装配置（徽章上游目录需要保留其自己的规则，不能把图鉴的 3777 排除套到徽章）、异色目标/代表/成员，再递归加入父配置与相连源进化链。保留所有根与 dependency 的原 PetID；manifest.scope 明确列出 root/dependency/excluded IDs，排除不是静默修坏数据。若任何必要闭包依赖 Unknown 或坏 FK，依旧严格失败；不因为它未实装就跳过 required 依赖。

捕捉信息仅复制详情原值，null 仍为源未提供；不使用阈值推导 rate、不选新的 MONSTER 候选。保留 catch_info=null 与已有全-null 对象的区别。新的 catchInfo 不引入捕捉计算功能。

v2 Asset 是**源描述**：存在且 RIFF/WEBP header 有效则 availability=available、sourceFormat=webp、真实 SHA-256；ENOENT 则 availability=missing、hash/format=null、明确 source-file-missing。其他读错误/非法头仍失败。missing 不是伪造图片或悄悄改为空 FK，manifest.knownMissingAssets 必须精确匹配；图像转换/解码验收继续是独立阶段。JSON 管线不宣称源缺图已修复或完整运行时素材包已经可用。

schemaVersion=2：删除 required 实体/字段、替换 catch 模型、调整 Asset 阶段语义都属于不兼容契约，不能偷偷沿用 v1。新 schema 在 shared/content/content.schema.json；docs/ios-p0/content.schema.json 保留历史冻结文件，不改 P0。所有保留字段仍 required，nullable 明确；重复 ID、类型、enum、FK、环、引用字段冲突依旧失败。

| 原 blocker | 八功能范围中的状态 |
| --- | --- |
| 捕捉阈值/rate | 保留原始图鉴显示字段，正式 v2 mapping 解决。无概率猜测 |
| 多道具进化条件 | out of scope；不读材料/数量/条件文字，因此缺 ItemID 不阻塞关系图 |
| 课题货币/资源奖励 | out of scope；删除 handbookTopics/items，不读取奖励源，不扩资源或 Item schema |
| 9001 属性 20 | 由明确的目录根集合排除，不在必需闭包；不扩属性。闭包内 Unknown 仍失败 |
| WebP asset | v2 source-descriptor 阶段可精确表达，无批量转换；真实缺失素材明确列清单，后续转换阶段独立验收 |

## 决策的上游证据

| 决策 | 真实源/消费位置 | 兼容性及版本影响 |
| --- | --- | --- |
| 公开真实图鉴根与徽章根 | `src/lib/petHandbook.ts:getRealPetHandbookId`、`src/lib/generated/handbookIds.json`；`src/lib/badgeTrials/catalog.ts` 使用 implemented；`src/features/shiny-collection/catalog.ts` 提供异色目标/成员 | 产品范围裁剪，不将所有 Web 配置视为宠物目录；新增 manifest.scope 审计，v2 |
| 保留捕捉原值 | `scripts/sync-pet-data.mjs:buildCatchInfoByBaseId` 从 MONSTER_CATCH_CONF 选择当前详情记录；`src/lib/interface.ts:IPetsCatchInfo` 三字段 nullable；`src/pages/pets/[id].vue:catchRawThreshold/catchRawGuarantRate` 原样显示阈值、rate/100 显示百分数 | 原 v1 rate/habitatText/notes 无法表达，正式替换为三个 nullable 原字段，breaking v2；不重新选 BinData 候选、不推算概率 |
| 只保留进化关系 | `public/data/tables/PET_EVOLUTION_CONF.json:RocoDataRows[].evolution_chain[].petbase_id`；`src/lib/badgeTrials/catalog.ts`、`src/lib/petEvolutionFamilies.ts` 依赖父/家族关系；用户首领材料已拥有规则 | 删除材料条件/Item FK，breaking v2，不扩多道具 schema |
| 不接入课题/奖励 | 旧 handbookTopics 来自 HANDBOOK_TASK/HANDBOOK_REWARD；这些不属于八功能；草系实际足迹与地点来自 badgeTrials，不需要奖励 FK | 删除整实体与 items，breaking v2，不建立资源 schema |
| 9001 的 Unknown | `scripts/sync-pet-data.mjs` UNKNOWN_TYPE_ID=20；raw→normal 映射缺失会产生 Unknown；`public/data/Pets.json` 中 9001 未实装、非真实图鉴、非异色成员、未在必要关系闭包 | Unknown 是 Web 归一化 sentinel，不证明合法战斗类型；保持类型约束，不扩 enum；范围审计记录排除 |
| 保留 magicItems | `src/pages/team.vue` 读取 magic_items.json；`src/features/team-builder/TeamToolbar.vue` 选择 battle magic；`src/lib/teamStorage.ts` 保存 magicItemId | 这五个配队选项直接 required，不读取 items/BAG_ITEM、无材料库存扩张；原稳定 ID 保留 |
| 源 WebP 描述 | `src/components/FriendPortrait.vue` 与异色 catalog 使用 public/assets/webp；实际文件 RIFF/WEBP，generator 逐文件检查/sha256 | v1 的 png/jpeg/placeholder 和已转换输出字段语义不成立；改为 source descriptor，breaking v2；后续固定工具/参数/排序、清除时间元数据并逐输出 hash 的 deterministic conversion 单独验收 |

`ios-scope.json` 是当前实现的范围登记，不是任意可调的过滤表达式。改变选取规则应同步修改 selectPets 与范围契约，并重新验收。
