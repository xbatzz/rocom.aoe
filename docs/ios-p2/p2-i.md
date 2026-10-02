# P2-I 用户持久化整理

RocoUserData 与 canonical ContentStore 隔离。明确 ShinyRecord(slot)、GrassRecord(location+footprint)、HeroRecord(family) 三类 entity，各自稳定 ID、更新时间和 dataVersion=1。统一显式保存/失败回滚；UserDataMetadata 建立最小格式版本边界，未来备份/导入先 validateVersion，未知版本报错，不重置/删除数据。默认值支持 SwiftData 轻量新增字段；将来改变 ID/语义须增加明确迁移，不以版本字段冒充已有跨版本迁移。未实现 CloudKit/备份 UI。

验证：四项 focused tests 通过，包含真实磁盘保存/重新打开后各 entity 状态、元数据和未知版本拒绝；一次无签名 device build 成功。未改 ContentStore，未跑 UI tests。真实设备存储错误与未来迁移仍需单独验收。
