# P2-A：图鉴列表搜索 / 筛选 / 排序

2026-10-03，基于同步后的 main。仅扩展真实 ContentStore 图鉴列表；详情、PortraitSurface、PortraitStore、image-only animator、手势和导航栏实现保持原样。AlignedNavigation 仅向 Grid 多传一个 ContentStore 参数。

## canonical 能力检查

- Pet 已有 nameZh、resourceKey、searchAliases、form、handbookId、petId、typeIds、defaultLegacyTypeId、attackStyle、isLeader、baseStats、parentPetId、ordinal。
- BattleType 可把属性 ID 映射到中文名称；PetDetail 不需要参与本次列表查询。
- 721 条 Pet、356 条 evolution edges。按 parentPetId 反查比 evolution edges 多出34个来源，因此可进化取父引用反查与边来源的并集。初始/已进化依据 parentPetId 是否为空，与 Web 规则一致。它是目录形态关系，不是满足等级、材料等条件的可执行进化判断；canonical evolution 没有进化条件字段。

## 实现与范围

- 搜索为列表内原生 SwiftUI TextField，支持清除、提交收键盘、交互滚动收键盘。避免把 searchable 挂到需要 NavigationStack 的主导航，保留现有 UIKit 导航结构；只有筛选 sheet 自带独立 NavigationStack/Form。
- 文本搜索：中文名、资源名、别名、形态、主副属性中文名、默认血脉属性中文名。去首尾空白、不区分大小写、全角数字转半角。
- 纯数字：真实 handbookId 采用 Web 的去前导零、补三位、前缀/补零后缀规则；配置 petId 单独精确匹配（允许前导零），不把 speciesId 或配置 ID 当图鉴编号。两条路径取并集。
- 双属性筛选匹配任意属性位，两项取交集；再与攻击倾向、首领/非首领和进化状态相交。清除筛选保留搜索与排序；无结果提供整体重置。
- 按筛选、搜索、排序依次计算。默认 canonical ordinal；总种族值和速度降序；中文名使用固定 zh_CN locale。所有同值以配置 ID 升序打破平局。
- 保留既有721条目录范围，不引入 Web 全量未实装配置、分页、重复首领折叠、技能/血脉技能反查、收藏或详情扩展。血脉技能反查属于本轮范围取舍，不能声称 canonical 完全缺少技能关系。要求的搜索/筛选/排序字段没有数据缺口。
- 未将完整 Web 未实装目录补进 canonical；进化条件也没有扩 schema。未按缺失条件猜测能否立即进化。
- 结果只包含 Pet 值；ForEach 仍以 PetID 标识，PortraitOrigin 仍为 PetID + encyclopedia-grid。UIImage 继续仅在 LazyVGrid cell 内按需解码，不预加载整个目录。

## 验证

只运行一次快速无签名 generic iOS build，Xcode27/Swift6.4，BUILD SUCCEEDED / exit0。日志 `/tmp/rocom-p2a-build.log`。只有既有无 AppIntents dependency 的 metadata extraction 提示。未运行 UI Test、XCUITest、host tests、大型矩阵或 Web 构建。git diff --check 通过。真机视觉、键盘与返回行为待用户手测。

```sh
DEVELOPER_DIR=/Applications/Xcode_27.app/Contents/Developer xcodebuild \
  -project ios/RocoNative.xcodeproj -scheme RocoNative \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios-content/wiring-device CODE_SIGNING_ALLOWED=NO build
```

真机五个场景：

1. 搜索喵喵、形态文本、属性名和别名，清除搜索后恢复721条。
2. 搜索002/００２与3001：前者命中真实图鉴编号规则，后者精确找到配置3001；不会将3001当图鉴编号。
3. 组合双属性、攻击倾向和首领/非首领；制造无结果再重置，检查清除筛选保留关键词和排序。
4. 初始/已进化/可进化分别筛选，同时切换四种排序；往返切换确认结果与同值顺序稳定。
5. 在搜索筛选排序后的结果中点头像进入详情，滚动后返回并取消一次边缘返回；检查来源头像、列表状态和滚动位置保持，快速滚动时不串图。
