# P2 无人值守实施记录 · 2026-10-03

从干净、已同步的 main 开始，新建 codex/p2-overnight；按顺序完成 P2-C 至 P2-K。各阶段记录见 p2-c.md 至 p2-k.md。每阶段独立提交/推送；P2-F 编译失败有额外修复提交，记录已纠正。未改 frozen encyclopedia/PortraitSurface/shared animator，未改 public/data、canonical schema 或 ContentStore。

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
| P2-K | 纯 battle core、双方临时构筑、纸面伤害与一击线 |

## 验证与边界

新功能各阶段 focused Swift tests 通过；推荐/六维15 fixture，战斗80 fixture+14捕捉球+3属性切换fixture；持久层磁盘恢复和未知版本拒绝。各阶段device无签名编译成功，F/K只有真实编译失败才做修复重建；未运行UI/XCUITest/完整矩阵。Web type-check/build通过。日志、DerivedData放/tmp，未入库。

停止于P2-K后，原因：计划阶段完成。真机尚未验收。需要检查首页与图鉴退出、搜索/筛选/详情跳转、三类收藏重启恢复、配队草稿保护和交换、PVP方向/条件/一击线、Dark Mode/Dynamic Type。

已有问题仍保留：canonical 缺图；P0 既有末段handoff/立即触控/辅助字号审计等记录；Web大chunk警告；battleEffects结构化解析待完成。新功能不含CloudKit、备份导入、完整战斗模拟，未移植Web既有localStorage数据。草系地点目标不等于已知出没目录；PVP非生命选择触发条件沿用Web显式满足假设。
