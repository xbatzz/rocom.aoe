# Expressive · Native iOS Game Companion · 2026-10-03

本轮使用 design-swiftui-interfaces、swiftui-pro、emil-design-eng，并在页面完成后以 review-animations 审查 diff。Emil 的判断用于主次、阅读节奏、反馈频率；没有移植 CSS / Web 动画实现。最低部署保持 iOS 27，Xcode 27.0 / Swift 6.4。

## 体验约定

核心任务：离线识别精灵、属性、技能和特性，记录收藏，准备队伍。expressive 用于少量内容焦点的属性色氛围；NavigationStack、系统菜单、分段选择、sheet、搜索保持既有原生语义。既有 frozen image-only shared portrait transition 是图鉴流唯一 hero transition；本轮没有新增 motion。新增色面板为不透明语义底上的静态渐变，无玻璃叠层、模糊、shader 或时间驱动器。

比较了三种结构：全页等权彩色卡片、单张精灵占满首页、图鉴主入口 + 安静工具/收藏区。选择第三种。首轮实装中次级卡片的彩色描边偏多，第二轮撤除；大字号装饰预览过长，第三轮缩为一只精灵，不缩小文字。状态仍归原 Feature View / domain 所有，未引入业务状态镜像。

## 实际运行与页面迭代

真实 iPhone 18 Pro Simulator / iOS 27.0 (24A434)，UUID 25EE507E-F0E7-4FB8-8484-0D7D216800DA。实际 build、install、launch、simctl screenshot，再读取原始截图。Debug review routes 调用真实 Feature View，并使用原有隔离内存数据库；fixture 记录未写个人数据库。截图为 1206×2622 原始像素，未编辑界面。

| 页面 | 迭代结果 | 证据 |
| --- | --- | --- |
| 首页 | 图鉴为主色场，三只精灵增加真实属性；工具和收藏安静处理。辅助字号仅保留一张装饰预览 | [浅色](screenshots/final-home.png)、[深色](screenshots/final-home-dark.png)、[辅助字号](screenshots/final-home-ax.png) |
| 属性 | 18 枚原图进入大触点选择器；勾选 + 描边表达选中；双属性同时显示两枚图标，结果仍用原 TypeMatchup | [双属性](screenshots/final-types.png)、[高对比度](screenshots/final-contrast-types.png)、[辅助字号](screenshots/final-types-ax.png) |
| 技能查询 / 详情 | 真技能图片速览承担焦点；类别有原生语义符号和文字；二轮将类别文字恢复 primary，避免彩色小字对比不足 | [目录](screenshots/final-skills.png)、[深色](screenshots/final-skills-dark.png)、[详情](screenshots/final-skill.png)、[辅助字号](screenshots/final-skills-ax.png) |
| 图鉴 / 特性 | Hero 几何、注册和图片调用保持原状；种族值为静态比例条，辅助字号省略装饰条；特性原图 56pt，效果描述用可读主色正文 | [列表](screenshots/final-grid.png)、[种族值与特性](screenshots/final-pet-stats.png)、[辅助字号特性](screenshots/final-pet-ax.png) |
| PVP / 队伍编辑 | 已选伙伴根据真实主属性产生轻色场；空槽位不使用属性色；原有构筑与六槽规则保持 | [对战](screenshots/final-pvp.png)、[深色](screenshots/final-pvp-dark.png)、[草稿](screenshots/final-team-draft.png)、[保存队伍](screenshots/final-teams.png) |
| 异色 / 草系 / 勇者 | 共用静态进度焦点；正文、家族、收藏状态沿用现有图片与文字语义 | [异色](screenshots/final-shiny.png)、[草系](screenshots/final-grass.png)、[勇者](screenshots/final-hero.png) |
| 伤害 | 总伤害与目标最大生命占比成为静态结果面板；真实技能图片/类别复用 | [结果](screenshots/final-damage.png) |
| 联防 / 备份 / 数据版本 | 复查原有页面，保留安静结构，没有为了统一装饰而重做 | [联防空态](screenshots/final-defense.png)、[备份](screenshots/final-backup.png)、[版本](screenshots/final-version.png) |

不是每张截图都代表一次实现迭代。首页/技能/属性至少经过首轮实装和收敛复查，首页/空槽/总种族值另经第三轮修正。其他页面主要由共享组件改变并完成截图审查。

## 资产边界

| Before | After | Why |
| --- | --- | --- |
| 属性已在部分标签中恢复，选择器仍是小 pill | 复用同一 18 枚 Species.png 精确裁图，选择器 30×31pt，双属性结果展示完整组合 | 增强内容识别；不修改 canonical 类型或猜映射 |
| 技能类别为文字 | 物理 burst.fill、魔法 sparkles、变化旋转箭头、防御 shield；始终保留文字，未分类有问号 | Web 当前没有完整且可靠的四类别贴图。明确采用 SF Symbols，不能声称它们是游戏素材 |
| canonical 技能 / 特性图已接入但重点不够明确 | 技能速览 / 详情 / 伤害 / 图鉴技能共用原图；特性有独立阅读面板和真实图标 | 保留数据驱动映射，不用零散库存图猜 effectID |
| 色面板与空槽均有色场 | 次级工具保持语义白/深色底，空槽无属性色 | 颜色应表达真实内容身份，避免手游控件皮肤 |

18 枚属性、leader-crown、collected-check 重新 materialize 后无 diff。没有添加整套背景、按钮贴图或无证据的效果图。开始前已有 ContentStore.skillIcon(for:) 和相关测试 / UI 调用的未提交改动完整保留；本轮未改其逻辑。public/data 和 ios/Packages 的 diff 与开始快照逐字相同。

## review-animations

以下是每组主要页面完成截图后对新增呈现代码的 motion 审查。没有新增自定义动画，无新 motion 待整改；表中为落实的审查决策，并非声称发现了原有动画缺陷。

| Before | After | Why |
| --- | --- | --- |
| 首页需要 expressive 焦点 | 静态内容色场，无入场 stagger / 浮动 / 滚动视差 | 高频入口不应延迟操作；FeatureHub.swift:56 |
| 属性选中需要反馈 | 状态当帧更新；保持原生 Button，无自定义弹簧 | 高频筛选不需要动画；TypeMatchupView.swift:40 |
| 技能和特性需加强识别 | 静态图标与 Label，无 sparkle symbolEffect | 图标语义服务阅读；SkillCategoryPill.swift:7、TraitDetailCard.swift:11 |
| 种族值增加比例条 | 直接布局，无宽度动画、数字滚动 | 数值阅读无需运动；PetStatChart.swift:26 |
| 收藏 / 队伍 / 伤害增强重点 | 静态 accent surface；系统导航和控件保持原有 behavior | 避免大量相关行同时运动；CompanionAccentSurface.swift:18 |

Verdict：**Approve 本轮新增 motion 范围（空集）**。无高频动画、延迟状态机、非因果动效或新减弱动态效果问题。未对 frozen transition 重新做设计审查，也不把静态截图当作真实手势验收。

## 验证与限制

- Debug Simulator build 和 Release generic iOS build 通过，CODE_SIGNING_ALLOWED=NO，保留签名与部署设置。
- Swift 包 29 项通过（18 Content / 11 UserData）；yarn type-check、yarn build、git diff --check 通过。
- 原导航宿主测试首轮 2 项通过 / 3 项失败（5 个 assertions），隔离迭代前源码复现完全相同结果。测试取 canonical 首项 16000004（未实装），但图鉴默认只显示 implemented && publicVisible；因此 source 锚点不存在，push 也不会发生。仅修正 HostTests 对可见精灵的选择，未改测试断言、等待、导航实现、canonical 或筛选规则。对照源码在 /tmp/rocom-expressive-before，失败日志在 /tmp/rocom-expressive-before-tests.log。 修正后 5 项全部通过；包含同 UIImage source/hero、详情生命周期、10 次连续程序化立即 pop / reopen。它们不替代真实手势反向验收。

- expressive 静态审计 high=0，medium=36：[完整报告](swiftui-audit.txt)。新增提示是固定小型图标和限定为5pt高的静态比例条，已检查默认/辅助字号；既有 frozen 和数据逻辑提示未扩大修改。
- 浅/深色、最大辅助字号、实际 Increase Contrast 截图已读；--solid-surfaces 只在 Debug 验证同一不透明 fallback 分支，不能算系统 Reduce Transparency / Reduce Motion 开关操作验收：[降级面板](screenshots/final-solid-home.png)。新增视觉没有随时间运动，Reduce Motion 不依赖特殊动画降级。
- AlignedNavigation.swift、PortraitSurface.swift、PortraitStore.swift SHA 校验与开始一致；PetDetail 中 Hero side 公式、位置、AnchoredPortrait 调用未改。
- Simulator CUA 两次 timeoutReached，未绕过输入接口。未执行真实触控反向、快速点击、VoiceOver / 键盘 / Switch Control、iPad / 最小容器矩阵、Instruments 或真机帧率检查。没有声称60/120fps或完整发布验收。

Apple Fidelity **暂评 84/100**：平台14/15、结构14/15、语义14/15、交互14/20、motion14/15、可访问性6/10、实现8/10。采用“缺少 assistive technology 验证最高84”的 evidence cap；不是90分验收通过，交互与辅助技术 gates 仍未全部验证。

构建与测试原日志在 /tmp/rocom-expressive-*.log。原始截图归档及 hash 见 [capture-manifest.json](screenshots/capture-manifest.json)。没有提交或推送。
