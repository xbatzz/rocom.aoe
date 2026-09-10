# S4 更新问题与经验总结

本次 S4 数据更新相比此前赛季出现了较大的客户端资源格式变化。最终确认游戏数据本身可以完整提取，但 FModel/CUE4Parse、Bin 数据解析器以及项目自身的“已实装”假设均需要适配。

本文整理本次更新经验。FModel 编译和客户端 Package 检查经过由维护者提供；项目解析及导入记录见 [S4 数据更新审计](./S4_DATA_UPDATE_AUDIT.md)。

## 1. Pak 加密格式发生变化

S4 客户端更新后，旧版 FModel 虽然仍可使用原 AES Key 挂载部分 Pak，但新 Pak Entry 使用了新的 configurable/chunked crypto。

表现包括：

- 部分 Pak 无法正确读取；
- S4 新资源不可见；
- BinDataCompressed 无法得到正确原始数据；
- 旧导出结果实际上仍停留在 S3。

最终使用 CUE4Parse PR #430 中新增的 Roco Kingdom: World chunked crypto 支持重新编译 FModel 后解决。

因此：

> “AES Key 可用”不代表当前版本所有 Pak Entry 都能够正确解密。

后续赛季如再次出现“游戏已更新，但 FModel 数据仍未变化”，应首先检查 CUE4Parse 对当前客户端加密格式的支持情况。

## 2. 自行编译 FModel 时的兼容问题

使用新版 CUE4Parse 编译 FModel 时遇到两个问题。

其一是 CUE4Parse PR 调整了 Roco Kingdom: World 的 namespace，而 FModel dev 仍引用旧 namespace，需要同步修改引用。

其二是 CUE4Parse-Natives 需要 MSVC/CMake 环境。普通 PowerShell 中没有正确 C++ 编译环境时，会出现：

- `CMAKE_CXX_COMPILER not set`
- `CUE4Parse-Natives.dll` 未生成
- `MSB3030` 找不到 Native DLL

最终在 Visual Studio Developer PowerShell 中重新执行 CMake Release build/install 后解决。

## 3. FModel 导出方式

赛季数据更新所需资源不能全部使用同一种导出方式：

- `BinConf`：导出 Properties JSON；
- `BinDataCompressed`：导出 Raw Data，取得 `.bytes`；
- `BinLocalize/dev_CN`：导出 Raw Data，取得 `.bytes`；
- Pet1024 / SkillIcon / FeatureIcon：导出 Texture。

此前一次失败导出中，BinDataCompressed 和 BinLocalize 只有 JSON，没有真实 `.bytes`，因此不能作为正式数据源。

本次重新导出后得到：

- 868 个 BinConf JSON；
- 872 个 BinDataCompressed `.bytes`；
- 257 个中文本地化 `.bytes`。

## 4. 本地化正确不代表结构解析正确

重新导出的 S4 数据通过了名称和 localization sentinel，但随后发现 `PET_HANDBOOK` 的嵌套结构仍被错误解析。

典型错误：

- 图鉴 440 的宠物 ID 被解析为 `651904`，实际为 `3746`；
- 图鉴 466 的宠物 ID 被解析为 `658560`，实际为 `3796`；
- `pet_topic` 中任务字段也发生错位。

原因是旧解析器假设：

> `DynamicArray<EStruct>` = 多个固定尺寸结构连续内联存储。

实际格式为：

> 32 位 little-endian 结构引用 ID 列表 → 每个 ID 指向独立结构 blob → blob 首部为 presence bitmap → bitmap 后仅保存实际存在字段的数据。

顶层 row 和嵌套 struct 实际使用相同的字段 presence 机制。

因此修复了解析器，使顶层记录与嵌套结构共用 bitmap 解码逻辑，并支持嵌套结构再次引用其他 ref。

后续修改 Bin 解析器时，不应根据 schema 的全部字段尺寸直接推导嵌套结构固定长度。

## 5. Dry-run 需要语义校验

旧解析器即使读错结构，`export:bin-data --dry-run` 仍可能完成而不报错。

因此仅以“解析未抛异常”作为成功标准是不够的。

本次增加了跨表语义检查，例如：

- handbook pet ID 必须存在于 PETBASE；
- skill ID 必须存在于 SKILL_CONF；
- task / reward 引用必须能够关联真实目标；
- 已知记录需要验证实际字段含义。

经验：

> 二进制解析的成功标准应是“结构正确 + 引用正确 + 语义合理”，而不仅仅是“程序运行成功”。

## 6. S4 打破了旧的 442 图鉴上限假设

S3：

- PETBASE：1128
- PET_HANDBOOK：442
- SKILL_CONF：1894

S4：

- PETBASE：1147
- PET_HANDBOOK：468
- SKILL_CONF：1988

项目中原先存在 `species_id <= 442` 等硬编码。

S4 后改为依据当前 `PET_HANDBOOK` 实际存在的 ID 集合验证，而不是简单把 `442` 改成新的 `468`。

原因是 `468` 同样只是当前版本数字，继续硬编码会在下一赛季再次失效。

## 7. PETBASE 中存在不等于已经正式实装

S4 PETBASE 中存在：

- 3784 云梦豚
- 3785 长江豚

两者已有名称、配置以及明确的头像资源引用，例如：

`/Game/NewRoco/Modules/System/Common/Icon/Pet1024/img_Wat_ZhuZhuTun1_001_Res`

但即使 FModel 使用 `Loading Mode = All`，客户端中仍不存在对应 Pet1024 / Pet256 Package。

PetOutline1024 中虽然存在部分同名 `img_Wat_ZhuZhuTun...` 资源，但 PETBASE 并未引用该目录，因此不能用它们替代正式头像。

用户已在游戏内确认世界图鉴实际为 468，3784/3785 均为正式实装的世界图鉴内容。这两条记录不能归类为“预载未实装”；其问题是客户端缺失了配置明确引用的上游资源。

因此后续项目逻辑不能再简单认为：

`PETBASE 中存在 = 当前版本已实装`

更合理的做法是结合图鉴、战斗、获取方式、活动等数据判断实际状态，并将“资源是否完整”作为独立检查。

注意：也不能因为头像缺失就反向定义为“未实装”，否则会形成：

`头像缺失 → 判定未实装 → 不检查头像`

从而掩盖真实资源导出遗漏。

**实现更正：** 已撤销同步脚本中的主头像可用性条件，implemented 恢复为不依赖头像文件是否存在。3784/3785 保持正常实装，不设 ID 白名单。资源检查独立处理：源资源存在但网站缺失属于项目错误；确认客户端源 package 本身不存在属于上游资源缺失。仅本地导出目录缺文件不能证明上游缺失。本次未修改资源检查脚本、重新生成数据或运行验证。

## 8. 资源命名规则不能写死

S4 出现了过去少见的：

`img_Wat_ZhuZhuTun...`

资源名，而大量旧资源使用 `JL_...`。

因此资源处理代码不能假设头像名称一定以 `JL_` 开头，应优先使用 PETBASE 中记录的真实 Unreal Resource Reference。

同样，不应仅根据文件名在多个目录中猜测资源，应尽量保留：

`完整 Unreal 路径 + resource key`

## 9. 本次 S4 最终数据变化

核心数据：

| 数据 | S3 | S4 |
| --- | ---: | ---: |
| PETBASE | 1128 | 1147 |
| PET_HANDBOOK | 442 | 468 |
| SKILL_CONF | 1894 | 1988 |

ID 变化：

- PETBASE：新增 32，删除 13；
- PET_HANDBOOK：新增 26；
- SKILL_CONF：新增 96，删除 2。

首次资源同步新增：

- 精灵头像：75；
- 技能图标：26；
- 特性图标：13。

这也说明赛季更新不能简单理解为“只追加新 ID”，官方会同时删除、替换、预载和调整旧配置。

## 10. 后续赛季更新建议流程

以后更新新赛季时优先遵循：

`验证 FModel/CUE4Parse` → `确认新赛季资源确实可见` → `导出真实 .bytes` → `严格解析` → `旧数据 sentinel` → `新赛季 sentinel` → `跨表语义验证` → `生成数据` → `同步图片` → `区分预载与已实装内容` → `最终测试与 build`

如任一步骤出现异常，不应通过手工修改生成 JSON、伪造图片、ID 白名单或放宽 unresolved reference 检查来绕过。
