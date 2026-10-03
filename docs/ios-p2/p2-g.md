# P2-G 草系徽章

canonical badgeRoot 家族浏览，关联 badgeFootprints 的稳定 footprintKey；不重新推导家族或按 species 折叠地区形态。地点列表/目标来自 badgeLocations，各地点展示全部可手动记录足迹（canonical 未提供出没地点关系，不伪造目录）。家族搜索、地点/三态筛选、统计及家族内逐足迹三态循环已实现。不扩展其他徽章。

独立 GrassRecord 保存 locationID + footprintID 唯一键，unrecorded/lit/unlit 显式状态，和 ShinyRecord 分离；保存错误 rollback。统计区区分目录状态数量与地点目标，目标不是实际目录分母。

验证：两项 SwiftData focused tests 通过，覆盖三态循环、地点隔离和异色隔离；一次无签名 device build 成功。未运行 UI tests。真机待验收地区/首领足迹、跨地点独立记录、重启恢复和搜索。
