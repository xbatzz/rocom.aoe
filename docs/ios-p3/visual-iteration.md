# P3 Visual Autonomous Iteration · 2026-10-03

分支 codex/p2-overnight。导航、业务规则、canonical 数据和 frozen image-only shared portrait transition 保持原状。不运行 XCUITest。

审计发现默认 List/Form 主导首页、PVP、配队、收藏、属性、技能与备份。使用 Apple 原生导航、动态字体、语义背景；真实游戏内容成为层级。没有加入渐变、阴影或动画。

## 实际复查方式

Xcode 27 / iPhone 18 Pro / iOS 27，实际 build、install、launch、simctl screenshot，读取截图。桌面 Simulator CUA 接口两次 timeout；Debug 的 `--visual-review <route>` 入口运行真实 feature View，使用隔离内存数据库，不改个人数据、不进入 Release 导航。不是 XCUITest。截图脚本位于 scripts/ios-ui/capture-review.py。真实完整分辨率截图与构建日志在 /tmp/roco-p3-shots 和 /tmp/roco-p3；最终缩略证据另存本目录。

## 页面日志

- 首页 r1：默认探索／收藏／战斗 List 改为图片图鉴主入口、真实内容配置数、属性／技能工具入口、收藏进度与最近队伍。截图首屏主体是精灵，主要操作清晰。自评：不再是默认 SwiftUI 拼装；战斗与底部入口留待全局滚动审查。
- PVP r1：我方／VS／对方 selection cards，真实头像与属性，六维双向比较，分析入口及空状态步骤。实际空态与有双方构筑截图复查。自评：不再像 Form；默认蓝色保存队伍按钮降为中性。Debug 示例使用真实 canonical 两只精灵与 TeamRules.assign，不写队伍。

## 资产审计

| Web 使用证据 | iOS 策略 | 原因 |
| --- | --- | --- |
| src/lib/typeIcons.ts、TypeIcon.vue，Species.png | 18 个 typeID 精确裁剪 PNG；GameIconCatalog + TypeBadge | 完整映射；沿用 Web 防串色裁剪，52×54，原比例渲染 |
| SkillIcon.vue、skills/SkillResultCard.vue、pets/[id].vue | canonical skill.iconAssetId → 现有 AssetResolver → 原比例小图 | 不猜文件名；包内已有高质量图标 |
| pets/[id].vue 的 trait SkillIcon | canonical trait.iconAssetId，同上 | canonical 映射可靠 |
| encyclopedia.vue、TeamSlotCard.vue 的 leader-crown | 小型首领语义图标 | 仅在真实 isLeader 状态使用 |
| handbook-progress.vue、pets/[id].vue 的 collected-check | 已收集／获得语义图标 | 未收集保持文字，避免不完整状态映射 |
| 物理／魔法／变化／防御类别 | 统一 SkillCategoryPill 文字 | Web 实际没有独立、可靠的四类游戏类别图标，不以独立技能图冒充类别图 |
| active-tab-background、primary-action-button | 不恢复 | 控件底板与原生交互不一致；不是信息内容 |
| 其他散落 effect／medal 图片 | 暂不猜映射 | 没有完整且实际使用的 effectID 映射；保留 canonical 描述 |

资源接入不修改 canonical 包；脚本只生成独立 GameIcons 目录，provenance.json 保存来源、hash 与 typeID 对应关系。技能与特性继续复用严格校验的既有资产包。

- 配队 r1 → r2：r1 草稿槽位过高，首屏无法看完整队；空槽像缺图，且保存列表缺属性。r2 紧凑六槽、原生道具菜单有明确标签、空槽显示真实序号、每个已有伙伴展示属性与技能数；实际空态、草稿、保存示例队伍复查。自评：不再是六个 Settings 入口，六槽呈现为一支队；辅助字号下允许单列。示例记录仅在 `--visual-fixture` 的隔离内存数据库中，由真实 domain API 创建。
- 异色 r1：真实异色 portrait、属性、赛季、收藏状态与范围进度；已收藏状态使用 Web 小勾。实际 5 / 81 测试记录截图复查，两个来源缺图不猜普通形态代替。自评：是 collection tracker，不是表格；搜索沿用原生控件。
