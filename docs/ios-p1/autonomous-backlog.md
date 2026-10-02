# Autonomous backlog

## Now
本轮收尾；29项 Package 测试与 Web type-check/build通过。下一轮从单队分享协议迁移继续，需保留足够预算完整读取/实现/验证 codec。

## Next
- 按现有分享链接协议补齐单队伍导入/导出（先读 Web codec，不猜格式）。
- 技能反查增加最终形态/全部形态筛选，直接关系与家族聚合继续隔离。
- 评估草系家族奖牌与图鉴课题的 canonical/持久化迁移边界。

## Verified
- Release hygiene：frozen/ContentStore/public数据未改；无日志/DerivedData/xcresult/secret产物入库。本轮Swift源码warning已修正。
- 数据版本页只读当前 canonical manifest，显示内容/规则版本、赛季、来源 revision 和用户数据格式。
- PVP 可从已保存队伍复制槽位作为临时我方，所有构筑字段完整保留，读取失败不清空现有 profile，也不写回队伍。
- 技能 alias 审计：SkillSearchIndex 与 TeamRules 使用真实 SkillID，家族聚合按 skillTerminal 单独展示，没有用 displayId 替代装备 ID。
- 技能和三个收藏页补上筛选无结果的系统空状态。
- 备份预检拒绝非正数构筑 ID/含分隔符键；替换前验证全部存量版本，不能删除未来版本记录；7项相关测试通过。
- PVP 可交换双方完整临时 profile（含生命/球类型），不写保存队伍。
- 三个收藏页每次 body 仅建立一次状态索引；草系家族行不再逐足迹全表扫描，代码复杂度由 O(足迹×记录) 降至 O(足迹+记录)。
- 配队/临时构筑→精灵详情和已选技能详情、PVP伤害→技能详情复用现有 NavigationLink，device build通过，frozen文件未动。
- Legacy importer 拒绝数字布尔状态、布尔版本和非 JS-safe 数字 ID；十进制字符串 ID 精确读取，备份测试通过。
- 本机编辑时间至少递增 1ms，四类数据的未来时间导入/旧备份合并回归测试通过。
P2-J 队伍复制/删除/超限保留；P2-K 联防与Web威胁fixture；P2-L完整预检/事务回滚/12队/原Web归档测试和device build通过。

## Deferred
合并旧备份是否恢复已删除队伍需要产品决定（目前合并为并集）；备份文件/分享/导入真机往返、Dynamic Type/VoiceOver；任何要求改变 frozen 转场的跳转。

## Blocked
无游戏规则 blocker。Web未激活字段已原样归档并报告。
