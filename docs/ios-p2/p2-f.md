# P2-F 异色收集

81 个 canonical slot 为收藏单位，稳定 slotId 原样持久化，不按进化成员合并。TrackingCatalogIndex 一次建立成员名称/别名/ID 搜索；赛季源为 seasons/shinySlotsBySeason；代表名称来自 pets，缩略图使用 slot.portraitAssetId，缺图显示系统占位，不猜文件名。按季、搜索、已/未收集及范围统计已接正式首页。

用户状态在独立 RocoUserData target 的 SwiftData ShinyRecord；禁用自动保存，每次显式 save，失败 rollback 并提示，不写 canonical，不开 CloudKit。

验证：UserDatabaseTests 跨赛季/跨路线稳定 ID 和切换通过。前两次 device 编译暴露 SwiftUI 类型推断超时；最终定位 catch 隐式 error 遮蔽页面状态，改为 self.error，拆行组件。首份记录提前标为成功已在此更正；最终修复编译结果见后续记录。无 UI tests；真机待验收收藏、重新启动恢复、赛季/成员搜索和缩略图。

最终修复：self.error 后无签名 device build 成功（/tmp/rocom-p2-f-final-build.log）。额外重建仅用于排查实际编译错误，无重复成功 build。
