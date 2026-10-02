# P0 冻结契约

基线 `a1b39c7ea22ccf5b8d35f5e73bb70f7fe47dc428`，schemaVersion=1，rulesVersion=`ios-paper-v1`。`content.schema.json` 是 P1 规范发布中间格式的冻结定义；P0 `PrototypeCatalog` 仅是 29 个配置的技术样本，不能冒充完整发布包。

## ID 与连接

数字 ID 必须为正整数，JSON 直接编码数值。Swift 使用带语义 tag 的包装：PetID、SpeciesID、HandbookID、SkillID、TypeID。HandbookID 可空，必须属于 `handbookIds.json`，不能由配置 ID 推导。示例 3001=喵喵配置、species/handbook=2。同 species 的 3020/3454 保持独立 PetID 和来源。

字符串 ID 原样保留：TeamID 不要求 UUID；SlotID 是队伍内稳定槽身份，不能使用 PetID。SkillGroupID 是检索组，不能作为战斗技能 ID。徽章根家族与技能终点家族分类型，数据库 PK=(kind,key)，即使二者都使用 `species:` 文本也不合并。ShinySlotID 包含赛季和路线，进度 key=`s<season>:<slotId>`；BadgeFootprint 使用 `pet:<id>`；课题 key=(HandbookID,TopicID)。来源 key=(PetID,入口/实例)，同一头像、同一 species 或同一宠不同槽都不能混用。

schema v1 的全部字段 required，缺值明确 null，禁止缺字段自动回退为 0/false。Enum 出现新值需诊断/升级 schema，不能静默映射。数组顺序使用源 ordinal；中文排序的确定性 ordinal 由 P1 生成。skillId 冲突不得 last-write-wins，必须输出来源/上下文变体。typeIds 为 1–2 项且不重复；战斗属性 1–18，19 是首领。JSON Schema 负责结构，跨表 FK、ID 唯一性、真实图鉴资格、环与技能字段冲突属于 P1 语义验证，尚未实现。

普通/地区形态不按 species 合并；只有首领展示使用现有折叠规则。3777 仅隐藏公开图鉴/PVP，不销毁基础配置或旧备份关联。配队候选已实装/公开/非首领，PVP 可含首领；收藏各自使用已有目录规则。未知旧 ID 保留 unresolved payload，不清空用户槽，不计入当前目录统计。

静态目录只读，用户库独立。原生备份 format=`rocom-ios-user-data` v1，保留状态墓碑、unresolved、sourceVersion；兼容 Web format=`rocom-user-data` v4。Web v1–v4/team v1–v2/shiny v1–v2 必须独立迁移，Web 导出不能表示全部取消墓碑。草系/命定勇者使用不同 trial key；异色同时间 false 胜，足迹同时间 lit 胜，队伍同时间保留当前。P0 fixture 不含真实个人备份。42 个样例包含 team v1 本地存储迁移、shiny v1 多路线、坏日期、未知旧 key 保留、课题删除复活和旧足迹数字 key。旧足迹页级迁移为人工契约样例，不作通用映射。

## PVP-D1～D4 决策

接受交接文档建议的原生产品语义修正，冻结 `ios-paper-v1`。本阶段只记录规格及旧/新样例，不实现 PVP 引擎或改 Web。

| ID | 决策 | fixture/证据 |
|---|---|---|
| D1 | 顶部使用真实最大倍率，不设最低 1x | [0.5,0.25]：Web 1，iOS 0.5 |
| D2 | saved 换边时转换成完整 explicit 临时 profile，包含 nature 上升/下降项和六项个体；交换两次数值恢复 | 匿名 saved 输入、双交换期望；保留槽来源清除规则 |
| D3 | 不改伤害；分别给最大 HP 占比和 currentHP KO | damage60/maxHP100/currentHP50：60%，当前可击倒、满血不可 |
| D4 | 推荐答复和选择动作使用同一默认效果快照，显式说明计数归零；原子应用 SessionAction | fixture 记录快照字段及归零动作，不沿用旧 watcher 覆盖结果 |

D1–D4 的 fixture 是人工核对页面规格样例，`evidence=manual-page-spec-example`，没有自动执行 Vue 页级 watcher，也没有声称 Swift 引擎已通过等价测试。332 基准为已有库注释公式。数值取整及备份/shiny/徽章 fixture 则实际执行现有 TS 可导出模块，并注入固定时钟。P5 必须实现新计算/Session，再使这些 fixture 成为执行断言。

## 八项入口审查

沿用规划 9.1：图鉴→精灵详情；查询→属性/技能；对战→PVP→配队；收集→异色/草系/命定勇者。详情内收集/课题不增加顶级入口。P0 只创建图鉴原型，其他入口未实现；没有八 Tab、Web HUD、金框或游戏背景。

## 缺图与包体

3784/3785 缺图在公开已实装核查中确认；`NRC` 与 `NRC_S3_backup` 按 ZhuZhuTun 名称检索无对应文件。P0 明确采用系统 photo bitmap + 精灵名字占位，源与 Hero 使用同一 bitmap。资源维护任务：按原 importer 的完整来源路径补齐真实图，禁止用生成美术替代。`../../build/ios27-p0/docs-evidence/assets-report.json` 逐项列出源 hash/尺寸/alpha/PNG 与 RGBA 字节。

预算仍是结构≤10MiB、图片≤50MiB、内容≤60MiB。已实装公开头像源 WebP 约39.50MiB，不是 PNG 发布预测。P0 样本使用最大512px、不放大、透明 PNG、一档相同 bitmap；P1 再验证两档引用闭包、压缩与包体，P0 不生成 SQLite。不得用本样本推断八项内容已经达标。
