# P2-J 配队

先阅读 team.vue、team-builder 组件/types/leaderBloodline、teamStorage 与 statCalculator。TeamBuild/TeamSlot 为纯 Swift 值，TeamRules 移植默认性格、血脉候选（首领条件）、pool→stone→当前 bloodline 来源覆盖、推荐 power(缺值18)+本系48+默认血脉18+偏好26/14+变化6/防御3，再按能耗降序与 ID 升序。推荐为明确替换操作；改血脉只清理已知非法技能，不自动补满，无法解析技能保留供手动修复。六维按 Web 的每一步 rounding 计算。

原生首版支持最多10队、每队6槽、重复选宠、性格/6项个体值(0–10/最多3项非零)、血脉/4去重技能、canonical魔法道具、明确草稿保存/放弃、交换槽位。队伍为独立 SwiftData TeamRecord 值快照，读取失败保留 payload，未保存草稿不写持久层；sheet关闭保护未保存更改。未实现分享/导入/角色/预设快捷键，不改变必需业务规则。

验证：一次无签名 device build 成功；15组源函数生成 fixture 比较全部候选推荐分、排序、top4和六维；另有去重、血脉清理/不补满、未知ID保留、槽交换、重复宠和草稿隔离/保存 round trip focused tests，7项通过。fixture生成器位于 scripts/ios-tests/generate-team-fixtures.mjs，只读Web/canonical，输出测试数据。未跑UI tests。

真机待验收：草稿取消保护、选宠/血脉切换/技能上限、交换与重启恢复。用户旧Web数据尚未导入，原生未执行自动迁移。后续备份仍须保留未知ID。

## 继续施工 · 队伍管理补齐
本轮增加复制（新 UUID，保留 unresolved 构筑）/删除（确认且至少留一队）/编辑重命名入口。10队只阻止新建/复制，已有12队测试仍可完整读取/编辑，不截断；备份导入将走独立已验证事务而非 UI 数量限制。6项持久业务测试和一次device build通过。仍不运行UI tests。
