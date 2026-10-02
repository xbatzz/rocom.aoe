# P2-F 异色收集

81 个 canonical slot 为收藏单位，稳定 slotId 原样持久化，不按进化成员合并。TrackingCatalogIndex 一次建立成员名称/别名/ID 搜索；赛季源为 seasons/shinySlotsBySeason；代表名称来自 pets，缩略图使用 slot.portraitAssetId，缺图显示系统占位，不猜文件名。按季、搜索、已/未收集及范围统计已接正式首页。

用户状态在独立 RocoUserData target 的 SwiftData ShinyRecord；禁用自动保存，每次显式 save，失败 rollback 并提示，不写 canonical，不开 CloudKit。

验证：UserDatabaseTests 跨赛季/跨路线稳定 ID 和切换通过。首次 device build 暴露大 SwiftUI 表达式推断超时，拆成独立行组件后修复 build 成功（只因编译错误进行一次修复重建）。无 UI tests；真机待验收收藏、重新启动恢复、赛季/成员搜索和缩略图。
