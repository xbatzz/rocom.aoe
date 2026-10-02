# P1 素材验收记录

真实源，未使用 fixture、PNG 转换或替代图片。

| 检查 | 结果 |
| --- | --- |
| `yarn ios:asset:probe` | Xcode 27.0 / iOS 27.0 (24A434) Simulator；1,465 张 ImageIO + UIImage(Data) + UIImage(file) 全部成功；尺寸、渲染 RGBA、alpha 统计逐图片一致 |
| `yarn ios:asset:test` | 14 个针对性检查通过；未知缺图、hash 漂移、引用错配、越界路径、canonical 篡改、失效 native evidence、输出篡改均拒绝 |
| `yarn ios:asset:generate` | 1,465 张真实源 WebP 原样写入，2 个 missing；1,468 个文件 |
| `yarn ios:asset:validate` | canonical/schema/FK、真实源 hash/完整解码、native evidence、输出所有文件逐字节核对通过 |
| `yarn ios:asset:determinism` | 两次独立构建/磁盘写入；目录、文件名、全部 1,468 个文件内容及 hash 一致 |

```json
{
    "status": "passed",
    "runs": 2,
    "files": 1468,
    "counts": {
        "assets": 1467,
        "materialized": 1465,
        "missing": 2
    },
    "assetManifestSha256": "973e6f1cf8665f13e3a596cbfbc19afaa026e1b8fe845cab13d96c71df441015",
    "canonicalManifestSha256": "b132e121ac385d4fe9a17ae7d7160257588a3252d49f887625c2f92264ceb78e"
}
```

两次的 asset manifest SHA-256 均为以上值。输出 `build/ios-content/assets/current/`；完整 asset manifest、missing report、native decode evidence 同目录。sourceSha256 与 outputSha256 全部相等，没有额外 unknown missing。已知缺图 ID 及其 petId：

- `portraitGrid:public/assets/webp/friends/img_Wat_ZhuZhuTun1_001_Res.webp` → 3784。
- `portraitGrid:public/assets/webp/friends/img_Wat_ZhuZhuTun2_001_Res.webp` → 3785。

冻结 canonical schema 的 SHA-256 始终为 `2d78d6b8ecb68ce8d59f190c5bb239a5bd208787f54c45a4bc6916bc477b5d84`；冻结 canonical manifest hash 始终为上表值。所有 canonical 文件的内容/字节/hash 均核对其原 manifest。未运行 canonical regeneration；新增 package.json asset 命令不改冻结包。未来显式 canonical 重生成会正常更新生产工具 inputHashes，不能把素材阶段改动当成悄悄替换旧内容包的理由。

图片总字节 52,992,058，素材包含审计 JSON 总字节 58,587,182（约 55.87 MiB）。原图约 50.54 MiB，旧 50 MiB 图片目标尚待包体决策；没有自动缩图。未做真机内存/性能、SwiftUI 组件/xcassets 或 App 包体验收。

可以开始 Swift 只读 ContentStore，按 canonical 与 asset manifest 的关联 hash 加载 JSON 和素材路径，保持明确 missing 状态；本轮未实现它。

新增 `scripts/ios-assets/{assets.mjs,probe.mjs,DecodeProbe.swift,test-assets.mjs}`、`docs/ios-p1/{asset-materialization.md,asset-verification.md}`；package.json 增加五条 ios:asset 命令。无新依赖、无 yarn.lock 修改；使用现有 sharp 0.34.5/libwebp 1.6.0。没有修改 Web 源素材/数据、canonical schema/scope、P0 或 SQLite；仅跑本轮必要的素材检查与无界面探针。
