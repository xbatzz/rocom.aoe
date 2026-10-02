# Autonomous backlog

## Now
P3 数据安全：验证队伍数值 ID 与复合记录键。

## Next
- 审计技能 alias 与家族来源。
- 审计空/错误状态。
- 核查备份 ID 命名空间与 SwiftData 记录一致性。

## Verified
- PVP 可交换双方完整临时 profile（含生命/球类型），不写保存队伍。
- 三个收藏页每次 body 仅建立一次状态索引；草系家族行不再逐足迹全表扫描，代码复杂度由 O(足迹×记录) 降至 O(足迹+记录)。
- 配队/临时构筑→精灵详情和已选技能详情、PVP伤害→技能详情复用现有 NavigationLink，device build通过，frozen文件未动。
- Legacy importer 拒绝数字布尔状态、布尔版本和非 JS-safe 数字 ID；十进制字符串 ID 精确读取，备份测试通过。
- 本机编辑时间至少递增 1ms，四类数据的未来时间导入/旧备份合并回归测试通过。
P2-J 队伍复制/删除/超限保留；P2-K 联防与Web威胁fixture；P2-L完整预检/事务回滚/12队/原Web归档测试和device build通过。

## Deferred
合并旧备份是否恢复已删除队伍需要产品决定（目前合并为并集）；真机交互、Dynamic Type/VoiceOver；任何要求改变 frozen 转场的跳转。

## Blocked
无游戏规则 blocker。Web未激活字段已原样归档并报告。
