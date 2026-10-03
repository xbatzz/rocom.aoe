# P2-L 用户备份 / 恢复

统一 rocom-native-user-data / schemaVersion=1，可读 JSON、ISO 日期，保存四类稳定 ID/更新时间和 Web 原始归档。同一 SwiftData 库，无 CloudKit。系统 fileExporter/FileImporter 与 ShareLink，导入先纯解析/全量验证、预览条数/警告，再由用户选择 merge/replace 并提交一次事务。任何预检/写入错误 rollback，不清空旧数据。导入不受 UI 10队上限影响。

合并：缺少的 ID 保留双方；较新时间胜。相同时间异色/命定取消优先；草系 unrecorded > unlit > lit；队伍保持本机版本（与 Web 同时间规则一致）。全量替换精确替换这四类记录及归档，不改 metadata/canonical。未知 canonical ID 原样保留；格式错误、重复记录 ID、未来版本、原生未知字段拒绝，不静默删字段。

Web versions1–4：可激活队伍（任意原Web ID稳定映射UUID、<6槽按Web补空、额外槽/>4/重复技能拒绝）、异色v2槽及v1成员索引迁移、pet足迹、命定奖牌。旧数字足迹不猜映射，仅归档并报告。主题/图鉴课题与收藏/草系家族奖牌/队伍角色/activeTeamId/其他字段完整原始JSON归档，用SHA256唯一标识，原生再导出时携带。未知旧异色成员同样报告并归档。文件本身原样保留；不声称全部Web字段都已激活。

验证：3项BackupTests通过，覆盖12队导入、未知ID roundtrip、全量替换、同时间取消/草系状态/队伍冲突规则、重复/坏JSON/未知字段拒绝、事务中途故障回滚、Web任意队伍ID稳定与完整归档再导出。首次device编译发现首页NavigationLink重载错误，修正为标准label形式后一次必要修复build成功。未运行UI Test。

真机待验收系统文件权限、保存/分享/文件选择、预览与恢复。保留的Web原始文档可能含个人数据，用户主动分享的是完整备份。
