# Swift 只读 ContentStore（schema v2）

2026-10-02。真实 canonical/素材包验收完成；没有 SQLite、SwiftData、PVP 计算或正式 UI，未修改 P0、RocoCore、UIKit shared zoom bridge、Web 上游或冻结 schema。新增独立 RocoContent package，单向依赖原 RocoDomain。

## 文件结构

```text
ios/Packages/RocoContent/
  Package.swift
  Sources/RocoContent/
    ContentIDs.swift          新增稳定 ID，SeasonID 明确支持 S0
    ContentModels.swift       冻结 schema 派生的 immutable Codable/Sendable DTO
    DecodingSupport.swift     required/null、未知字段、开放 JSON、错误和 SHA-256
    BundleReader.swift        Bundle 路径边界、读取、hash/bytes、重复键检查
    ContentStore.swift        一次加载与集中只读索引、同步/后台初始化
    ContentValidation.swift   FK、复合键、环、scope、素材引用一致性
    AssetManifest.swift       素材 materialization manifest 强类型
    AssetResolver.swift       WebP URL 或明确 missing 状态
  Sources/ContentProbe/Probe.swift
  Tests/RocoContentTests/ContentStoreTests.swift
scripts/ios-store/
  generate-models.py          从 schema 生成模型；不写源数据
  prepare-bundle.py           拷贝冻结产物到独立 Bundle；不重新生成内容
  probe-ios.py                无界面 iOS 27 Release/strict concurrency 探针
```

运行 `python3 scripts/ios-store/prepare-bundle.py`，资源暂存为 ignored `build/ios-content/store/ContentResources.bundle`：

```text
ContentResources.bundle/
  Info.plist
  Content/canonical/          17 个数组 JSON + manifest.json
  Content/assets/             asset-manifest、审计文件、images/*/*.webp
```

所有文件原样复制，目录结构保留。现有 P0 App 工程未嵌入这份 Bundle，也未改用真实数据。后续接入时将独立 Bundle 添加为资源，或在 App Bundle 中复制相同 Content 结构；不需要修改 frozen bridge。

## 初始化与使用

```swift
import RocoContent
import RocoDomain

// 验收工具使用 prepare-bundle.py 输出的 URL。
// App 接入时通过 Bundle.main.url(forResource:withExtension:) 取得资源 Bundle URL；
// 如果 URL 缺失，明确抛错，不能回退到 PrototypeCatalog。
let store = try await ContentStore.loadInBackground(bundleURL: resourceBundleURL)
let pet = store.pet(PetID(rawValue: 3001))
let skills = store.petSkills(for: PetID(rawValue: 3001))
let evolutions = store.evolutions(from: PetID(rawValue: 3001))
let terminalFamilies = store.families(for: PetID(rawValue: 3550), kind: .skillTerminal)
if let assetID = pet?.portraitAssetId {
    switch try store.assetResolver.resolve(assetID) {
    case .available(let url):
        // 交给后续图片层解码真实 Bundle WebP。
        print(url)
    case .missing(let status):
        // status.assetId / petIds / reason；此层不生成占位 bitmap。
        print(status)
    }
}
```

也提供同步 `try ContentStore.load(bundle: resourceBundle)`；默认 directory="Content"，appBuild=1。正式调用应传实际 App build；低于 manifest.minimumAppBuild 会报错。完整真实加载超过 UI 帧预算，后台入口用 Swift 6.4 的 `@concurrent` 执行，在内部打开 Bundle，返回编译器验证的 Sendable 值。

App 应持有一个 store 实例。每个 JSON 文件在一次初始化中只 decode 一次；文件 hash 在读取后校验，asset 图片字节只短暂读取/hash，不保留或解码 bitmap。manifest.assets 与 assets.json 是契约要求的两份描述，分别 decode 并逐实体比较。查询不重新打开/解析 JSON，不做全数组 filter。没有静默空目录、试错版本回退或全局可变 singleton。所有模型/索引是 let 值，无 @unchecked Sendable、锁或共享可变 cache。

## 索引

- `pets`、`petDetails`、`skills`、`types`、`traits`：稳定 ID → 强类型实体；`orderedPets` 保留 ordinal 展示顺序。
- `skillGroups`：SkillGroupID → group；displayId/aliasIds 是真实 SkillID，不能替代 group 身份。
- `petSkillsByPet`：PetID → 按 ordinal 排序的关系，保留 pool/stone/bloodline 与 nullable legacyTypeId。
- `evolutions`：EvolutionEdgeID → edge；`evolutionsByPet` / `incomingEvolutionsByPet`：源/目标 PetID → edges。
- `families`：FamilyIdentity(kind + familyKey) → family；`familiesByPet`：PetID → kind → **[Family]**。
- `shinySlots`：ShinySlotID → slot；`shinySlotsByPet` / `shinySlotsBySeason` 保留多槽位、多赛季关系。
- `badgeFootprints` / `badgeFootprintsByPet`：FootprintKey / PetID → footprint；`badgeLocations`：固定 location enum → location。
- `personalities` / `magicItems` / `seasons` / `battleEffects` / `assets`：各自稳定 ID → 实体；另有 `battleEffectsBySkill` / `battleEffectsByPet`。
- `AssetResolver`：canonical AssetID → validated URL / KnownMissingAsset，按素材清单的 relativeOutputPath 定位，不推测源文件名。

真实数据中 3550 同时属于 skillTerminal 的 species:189、190、191、192；不能假设每个 kind 只有一个 family。两类 family 身份独立，member 关系完整保留。shiny familyId 是 species 身份，不误连 Family.familyKey。

## 验证结果与 Codable 对齐

Swift 6.4 / Swift 6 language mode。iOS 探针编译启用 `-strict-concurrency=complete`、`-warnings-as-errors`、NonisolatedNonsendingByDefault；RocoContent library 不使用 MainActor 默认隔离。11 项 Swift Testing 通过，含实际跨 task group 的只读查询。覆盖全部 17 实体的 encode/decode round-trip、required null、missing key、未知字段/enum、数量/版本、duplicate、坏 FK/环、丢失/篡改 JSON、素材 hash/关联/引用、第三项 missing、越界路径和图片缺失/损坏。

17 类实体数量全部等于 manifest：pets/petDetails=721，skills/battleEffects=1079，types=19，skillGroups=580，petSkills=35573，traits=257，evolutions=356，families=405，shinySlots=81，badgeFootprints=601，badgeLocations=3，personalities=30，magicItems=5，seasons=5，assets=1467。

代表查询：3001=喵喵，speciesId=2，typeId=2，traitId=200076；skillId=1=聚能；3001→3025 进化；S0 可加载，S4 有19个异色槽位；3001 捕捉原值 thresholdRaw=1000、guaranteeRateBasisPoints=null。没有推导捕捉概率或执行 battleEffects 规则。

未发现冻结 schema 与真实 JSON 不一致。实现中修正了两个不能直接使用 Swift synthesized Codable/单值索引的假设：required nullable 必须显式编码为 null（合成 encodeIfPresent 会省略），同 pet/kind 允许多 family。模型生成器现同时生成严格 decode 和保留 null 的 encode；不需要改 schema。

素材结果为 available=1465、missing=2：3784/3785 各返回 `.missing`，reason=`source-file-missing`，带 canonical AssetID 和 PetID。没有第三项 unknown missing。其他不存在的 AssetID、缺失 WebP、损坏 hash、素材清单不匹配会 throw；没有生成替代图。UI 后续自行展示明确缺图状态。

## 实测耗时与内存

无 UI、arm64 iOS 27.0 (24A434) Simulator / iPhone 18 Pro，`swiftc -O`，同一新进程连续完整加载5次，保留最后一个快照；每次均做全部 JSON/索引/FK/hash 和 1465 张 WebP 文件完整性检查。

- 五次耗时：706.03、678.87、666.54、638.27、623.11 ms；首次约706 ms，后四次中位约652 ms。
- `mach_task_basic_info.resident_size`：基线25.70 MiB，首次加载后67.03 MiB，增量41.33 MiB；五次后67.16 MiB，增量41.45 MiB。
- 驻留增量包含 Foundation/解码/正则/allocator 暖机，不是精确 Swift 对象堆大小；未加载 UIImage/CGImage。未测真机、Instruments 峰值或 App 总内存。第一次是进程首次加载，未清空 OS 文件缓存，不能称磁盘冷启动。

可重现原始报告 `build/ios-content/store/ios27-report.json`；测试、iOS probe、Web build 日志同目录。性能不是正式 App 体验验收，但足以说明初始化应在后台完成。

```sh
python3 scripts/ios-store/prepare-bundle.py
swift test --package-path ios/Packages/RocoContent
python3 scripts/ios-store/probe-ios.py
# 可选独立 macOS Release 测量
swift run --package-path ios/Packages/RocoContent -c release content-probe \
  build/ios-content/store/ContentResources.bundle build/ios-content/store/macos-report.json
yarn type-check
yarn build
```

Swift Tests、iOS probe、Yarn type-check/build 均通过。Web build 保留已有 OpenCV externalization 与 chunk 体积提示；未修改 Web。未跑 canonical regeneration、sync:pet-data、P0 UI 回归或 SQLite。

冻结 hash 核对：schema `2d78d6b8ecb68ce8d59f190c5bb239a5bd208787f54c45a4bc6916bc477b5d84`；canonical manifest `b132e121ac385d4fe9a17ae7d7160257588a3252d49f887625c2f92264ceb78e`；asset manifest `973e6f1cf8665f13e3a596cbfbc19afaa026e1b8fe845cab13d96c71df441015`；P0 schema `34d12a1161027b37b910145366b2714dab56830b808b0d9ba33c329436c591ca`，均保持原值。

下一步可以接真实图鉴数据：先把这个已验收快照交给图鉴适配层、接资源 Bundle 和现有图片加载入口，再保留 P0 bridge 进行真实头像/缺图/详情长度的转场回归。本轮未进行这一步。
