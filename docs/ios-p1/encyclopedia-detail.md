# P2-B 图鉴详情

2026-10-03。仅补全原生图鉴详情；未进入 P2-C。保留 P2-A 工作区已有改动。

## 实施前数据核查

直接核对 `docs/ios-p0/content.schema.json`、RocoContent 的 ContentModels / ContentStore、`build/ios-content/v2/current` canonical 与 App 实际嵌入的 ContentResources.bundle；本轮使用的六个 canonical 文件与 bundle 字节一致。未修改 schema、模型、索引、生成器或上游数据。

- 721 pets：petId 为配置 ID；handbookId 可空，不能用配置 ID 冒充图鉴编号。form 的 default 显示为“默认形态”，其他值保留原文。六维 baseStats 为 required Int，总值只加当前 pet 的六个字段。
- 721 petDetails：traitId、worldProfile、catchInfo 均为 nullable；当前每条都有特性与 worldProfile。worldProfile 的实际键为 type_desc / description_habitat / introduction，分别展示为精灵类别、栖息描述、简介。不能把栖息描述冒充可捕捉地点。
- 35573 petSkills：pool 从当前配置 move_pool 导出；stone 从 move_stones 导出；bloodline 从 legacy_moves 导出，保留 legacyTypeId。每条均以当前 petId 为边界，不聚合家族学习能力。
- 1079 skills：typeId 有 2 条 null，power 有 413 条 null，energyCost 无 null；101 条真实能耗为 0。缺字段省略，真实的 0 保留。类别 Unknown 省略；技能名、实际属性/类别、非空威力/能耗与描述来自 exact skillId 查询，不替换为 skillGroups 的代表技能。
- 356 evolutions：仅 edgeId、sourcePetId、targetPetId、ordinal；没有等级、材料和条件。前置/后续使用 incomingEvolutionsByPet / evolutionsByPet；只去重当前关系里的重复 petId，保留分支。

## Family kind 的真实语义与展示选择

生成器 `scripts/ios/normalize.mjs` 调用以下 helper：

- badgeRoot：`src/lib/badgeTrials/catalog.ts` 的 buildBadgeTrialFamilies。排除首领形态，对已实现配置沿 parent 链找最低祖先，按该祖先 species 归组，用于徽章试炼；不展示内部徽章家族。
- skillTerminal：`src/lib/petEvolutionFamilies.ts` 的 buildPetSkillFamilies。排除首领形态，按最终后代的 species 归组，成员是这些最终形态的祖先路径。同一 pet 可以归属多个终点谱系（例如 3550 有四组）。展示为“进化谱系 · 代表精灵名”，只列当前配置之外的公开成员，不声称成员互相可以直接进化或共享可学习技能。

shinySlots 是另外的异色槽索引，不是 FamilyKind，本轮不展示。没有通过 family 类型数组猜当前形态的属性。

## UI 与数据来源

| 分组 | canonical | ContentStore |
| --- | --- | --- |
| 基础信息 | pets.json、types.json | 当前 Pet、types |
| 种族值与总值 | pets.json | 当前 Pet.baseStats |
| 特性 | pet-details.json、traits.json | petDetails[petId]、traits[traitId] |
| 进化关系 | evolutions.json、pets.json | incomingEvolutionsByPet、evolutionsByPet、pets |
| 进化谱系 | families.json、pets.json | familiesByPet[petId][skillTerminal]、pets |
| 技能池 / 技能石 / 血脉技能 | pet-skills.json、skills.json、types.json | petSkillsByPet[petId]、skills、types |
| 精灵资料 | pet-details.json | petDetails[petId].worldProfile |

Hero 保留原 ScrollView 内布局、原尺寸计算与 AnchoredPortrait。系统背景色的卡片、可换行文字和 ViewThatFits 基础值行支持浅/深色及辅助字体。无 NavigationStack / WebView / system zoom。

关联详情仍由现有 Coordinator push 到同一 UINavigationController。每个详情把自己的相关行注册到独立 PortraitAnchors；被 push 的详情携带这一 source/hero 对。delegate 只将相应参数传给原 PortraitNavigationAnimator；animator、PortraitSurface、边缘返回实现完全不变。原图鉴入口仍传原 anchors 与原 UIImage。相关行通过原 PortraitStore 加载、持有图片，push 直接取已注册 UIImage；关闭页面后来源视图仍由 weak 注册表持有。回调 weak 捕获 coordinator。

详情只查询当前 pet 索引，遍历当前关系/谱系成员；没有扫描 orderedPets / skills.values，没有运行时全表 join、解码 JSON 或重建全量索引。

## 暂未实现

catchInfo 有 559 条非空；thresholdRaw 541 条非空、ballLevelRaw 315 条非空，guaranteeRateBasisPoints 全部为空。原始阈值不等于捕获概率；本轮不显示概率、具体捕捉地点或捕捉条件。canonical 无培育资料、课题、进化等级/材料/条件。未恢复 rewards、items、handbookTopics，也未增加独立技能查询、属性克制、配队、PVP、收藏。

## 验证

仅一次快速 Debug Simulator build：

```sh
DEVELOPER_DIR=/Applications/Xcode_27.app/Contents/Developer xcodebuild \
  -project ios/RocoNative.xcodeproj -scheme RocoNative -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/ios-content/wiring-simulator CODE_SIGNING_ALLOWED=NO build
```

exit 0，BUILD SUCCEEDED。日志 `build/ios-content/p2-b/build.log`。仅工具链提示未依赖 AppIntents，跳过其 metadata extraction。git diff --check 通过。未跑 UI Test、XCUITest、矩阵、Web build；未执行真机验证。

## 五个真机手测场景（待用户执行）

1. 喵喵 3001：确认 No.002 / 配置3001、默认形态、草属性、六维与总值370、特性与栖息简介；Hero 随页滚动。
2. 喵喵技能：确认技能池16、技能石17、血脉18；血脉属性与技能属性分开，null 属性/威力省略，聚能等实际0能耗仍显示，无家族学习声明。
3. 棋棋 3550（白子）：四条后续分支、四组终点谱系；点进分支，再连续返回。粉星仔3319也可用于两分支确认。
4. 喵喵→喵呜→后续详情：在关联行/谱系进入多层详情，滚动 Hero 离屏后边缘返回取消与完成、按钮返回，最后返回图鉴；确认图片、原列表位置及既有 frozen 转场体验。
5. 云梦豚3784→长江豚3785：确认原缺图状态、关联可点；在系统最大辅助字体与深色模式检查卡片、技能长描述换行和滚动，终态不出现空后续形态或伪造条件。
