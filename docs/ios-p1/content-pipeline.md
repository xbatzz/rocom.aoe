# P1 八功能 canonical JSON 管线（schema v2）

当前契约是 `shared/content/content.schema.json`，范围见 [scope matrix](scope-pruning.md) 与 `shared/content/ios-scope.json`。只消费八个目标功能及必要 FK；不复制 Web 数据库。P0 schema/bridge/transition 保持原样。v2 是明确的 breaking 数据契约修订，不能交给 v1 解码器。

## 命令和输出

```sh
yarn ios:content:validate
yarn ios:content:generate
yarn ios:content:validate --out build/ios-content/v2/current
yarn ios:content:determinism
yarn ios:content:test
```

默认生成到 `build/ios-content/v2/current/`，不写 public 或 iOS 工程。每个保留实体一个数组文件，共 17 个实体 JSON，加 manifest 共 18 个文件。`--fixture shared/fixtures/ios/p1-sources.json` 用于独立小型测试；真实 generate/determinism 默认不使用 fixture。旧 v1 build 目录不会被此默认命令覆盖。

validate 执行 schema、唯一键、FK、nullable、枚举、父/进化环、来源一致性与 manifest 完整性检查；带 --out 时额外核对磁盘 hash/bytes 和当前源逐字节重生成。generate 在 staging 完整验证后原子替换受管理包；未知文件、符号链接、手改旧产物导致失败，失败保留上一包。只允许 build/ios-content 子目录输出。

## 范围和结构

保留 pets、petDetails、types、skills、skillGroups、petSkills、traits、evolutions、families、shinySlots、badgeFootprints、badgeLocations、personalities、magicItems、seasons、battleEffects、assets。

删除 items、handbookTopics 及所有奖励/材料 FK。移除 petDetails.breedingSummary、worldProfile 的体型/性别字段，进化边不包含材料、等级、条件文字。magicItems 是配队的五种战斗选项，具有独立 magicItemId，未接入道具或库存。

```json
{
    "petId": 3001,
    "traitId": null,
    "worldProfile": null,
    "catchInfo": {
        "thresholdRaw": 1000,
        "guaranteeRateBasisPoints": null,
        "ballLevelRaw": 1
    }
}
```

该 catch 示例是结构说明。实际值直接来自对应详情，不从阈值推导概率；catchInfo=null、对象中的显式 null 和缺失 required 字段含义不同，最后一种失败。`guaranteeRateBasisPoints` 表示 Web 显示时除以 100 得到百分数的原值，不是生成器计算出的概率。

进化：`{edgeId, sourcePetId, targetPetId, ordinal}`；edgeId=`evolution:<源行ID>:<源PetID>:<目标PetID>`。材料及条件无需解析；两个端点仍必须可解析。

assets 是 WebP **源描述**，不是运行时转图产物：`{assetId, purpose, sourcePath, sourceSha256, sourceFormat, availability, missingReason}`。存在时检查 RIFF/WEBP 容器头并 hash 真实字节；缺失时明确 missing/null/source-file-missing，并同步 knownMissingAssets。读权限/损坏头等错误失败；不伪造 PNG、占位图片、尺寸或转换 hash。此步不验证完整图像解码，也不执行转换。

## 确定性和 manifest

字段顺序来自 v2 properties；开放字典按 Unicode 字符串顺序。UTF-8、4 空格、LF、单末尾换行。实体数组按稳定 ID/复合键排序；集合 alias/member/weak/resist 明确排序。主副属性顺序与技能/进化列表 ordinal 保留业务位置含义；展示 ordinal 按 Unicode 名称 + ID 决定，无 locale/随机 UUID/当前时间。

稳定 PetID、SkillID、TraitID、TypeID 使用真实源 ID；不因源实体列表重排而改变。重复表 ID 直接失败；重复出现的同 ID 技能/特性只能在所有字段相等时 intern，冲突给出来源且失败。

manifest schemaVersion=2、generatorVersion=ios-canonical-v2，包含全部消费文件/生成器/schema/scope policy 的 inputHashes、contentVersion=`sha256-<source fingerprint>`、17 类 counts、每个实体文件的 hash/bytes、源 assets/缺失清单以及 root/dependency/excluded PetID。source fingerprint 是排序后 inputHashes 规范编码的 SHA-256；源文件真实字节顺序变化应改变来源 hash，但不能改变稳定 ID/实体内容。sourceRevision 记录 git HEAD；不写时间戳。

manifest 不自哈希；determinism 比较包括 manifest 的全部 18 文件，返回单独 manifestSha256。连续两次独立读取/生成/磁盘验证后逐字节比较，临时目录不进入内容。版本管理中的 `shared/fixtures/ios/p1-scoped-manifest.example.json` 示例来自 fixture，真实验收数据见 [verification](verification.md)。

不运行 sync:pet-data，不修改 Web 上游源，不运行完整 Web/P0 测试；本轮仅验证数据导出和其必要回归。
