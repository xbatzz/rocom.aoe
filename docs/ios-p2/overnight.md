# P2 无人值守实施记录 · 2026-10-03

从干净、已同步的 main 开始，新建 codex/p2-overnight；按顺序完成 P2-C 至 P2-L，随后继续 P3 自主迭代。各阶段记录见 p2-c.md 至 p2-l.md。每阶段独立提交/推送；P2-F 编译失败有额外修复提交，记录已纠正。未改 frozen encyclopedia/PortraitSurface/shared animator，未改 public/data、canonical schema 或 ContentStore。

## 已完成

| 阶段 | 内容 |
| --- | --- |
| P2-C | canonical 属性纯计算、单/双防御、双进攻并集 |
| P2-D | 技能索引搜索与详情，直接来源/家族聚合区分 |
| P2-E | 原生功能首页，图鉴独立 frozen 导航 |
| P2-F | canonical 异色槽、赛季/成员搜索、SwiftData 收藏 |
| P2-G | canonical 家族/足迹、地点独立三态草系记录 |
| P2-H | 与草系隔离的命定勇者状态 |
| P2-I | 三类 entity 版本/保存事务边界，磁盘恢复验证 |
| P2-J | 6槽多队、完整必需构筑编辑、草稿/交换/推荐 |
| P2-K | 纯 battle core、双方临时构筑、纸面伤害与一击线、已保存队伍联防 |
| P2-L | 四类统一 JSON 备份、文件/分享、完整预检、合并/替换事务、原 Web 归档迁移 |

## 验证与边界

新功能各阶段 focused Swift tests 通过；推荐/六维15 fixture，战斗80 fixture+14捕捉球+3属性切换fixture；持久层磁盘恢复和未知版本拒绝。各阶段device无签名编译成功，F/K只有真实编译失败才做修复重建；未运行UI/XCUITest/完整矩阵。Web type-check/build通过。日志、DerivedData放/tmp，未入库。

前次停在P2-K的记录已由本轮连续任务续接。本轮完成J/K补齐、L及多轮P3后进入收尾；下一轮明确工作见 autonomous-backlog.md。真机尚未验收。需要检查首页与图鉴退出、搜索/筛选/详情跳转、三类收藏重启恢复、配队草稿保护和交换、PVP方向/条件/一击线、Dark Mode/Dynamic Type。

已有问题仍保留：canonical 缺图；P0 既有末段handoff/立即触控/辅助字号审计等记录；Web大chunk警告；battleEffects结构化解析待完成。新功能不含CloudKit或完整战斗模拟。Web备份 versions1–4可迁移支持字段；主题、图鉴课题、草系家族奖牌、角色等未激活字段完整保留在原始JSON归档并报告。草系地点目标不等于已知出没目录；PVP非生命选择触发条件沿用Web显式满足假设。

## 本轮 P3

- 本机编辑更新时间递增至少1ms，保护未来时间导入后的显式更改。
- Web JSON 严格区分布尔/数字、拒绝不安全数值 ID，字符串整数精确保留。
- 替换前校验全部已有数据版本和草系复合键；未支持版本不能被删除。
- 配队/PVP复用精灵/技能详情；PVP复制已保存槽位与交换双方，均不写回原队伍。
- 收藏页状态索引每次body一次；草系足迹去除逐行全表扫描。
- 技能/收藏的筛选空状态；离线内容版本、规则版本与来源页。
- 技能真实配置 ID / alias、family 与具体形态审计无新增偏差。

最终本地 Package 29项业务/内容测试通过（11项用户数据、18项内容），未运行UI Test。Web type-check/build通过（既有大chunk/OpenCV externalization警告）。device build通过；修复两项本轮Swift源码warning，最终复核日志在/tmp，未提交构建产物。AppIntents无依赖的metadata extraction skipped工具提示保留，不为消除提示引入无用依赖。

Deferred：合并旧备份按并集可能重新带回已删除队伍；是否引入删除墓碑会改变备份语义，留待产品决定。未知内容ID完整保留。文件导入/ShareLink、草稿保护、Dark Mode/Dynamic Type仍需真机验收。frozen转场文件及public/data保持不变。
