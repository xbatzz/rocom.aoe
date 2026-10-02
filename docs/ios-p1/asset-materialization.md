# P1 deterministic asset materialization

范围固定为 canonical v2 的 assets 引用闭包。只读 `build/ios-content/v2/current`；没有重新生成 canonical、改 schema/scope、写 public、修改 P0、加入 UI/SQLite/PVP。新脚本放在 `scripts/ios-assets/`，与 canonical 生成器分离。

## WebP 决策与证据

Apple 的 [ImageIO WebP Data](https://developer.apple.com/documentation/imageio/webp-data) 文档列出 WebP 支持；[UIImage](https://developer.apple.com/documentation/uikit/uiimage) 支持平台原生图片格式。但文档不是这批素材的全量解码验收。

独立命令行 Swift 探针使用 Xcode 27.0（27A266a）与 iOS 27.0 Simulator（24A434），无 UIApplication/窗口/视图，也不链接 P0 工程。实际全量 1,465 张源 WebP：

- ImageIO 广告支持 `org.webmproject.webp`，实际输入类型/单帧/完整解码状态均验证。
- ImageIO、`UIImage(data:)`、`UIImage(contentsOfFile:)` 均成功。
- 三个入口均强制渲染到原尺寸 sRGB premultiplied RGBA；逐图片尺寸、RGBA hash、透明/半透明/不透明像素统计一致。
- materializer 用 sharp/libwebp 另做完整解码；尺寸及三种 alpha 像素计数与 native 报告逐项相等。1,465 张都有 alpha 与实际透明像素。

因此采用 **copy-webp**，不进行 PNG 转换。所有输出文件与源字节完全相同，sourceSha256=outputSha256；alpha、透明边、颜色配置、EXIF/ICC、画布及裁剪范围不经过编码器。探针 RGBA 是验证数据，不是输出图片。这里没有承诺 SwiftUI Image(name:) / xcassets 自动接受 WebP；后续 ContentStore 可使用显式文件路径或 Data + UIImage 解码。

此证据来自 Simulator，未执行真机内存/性能验收。旧规划中的“默认通用格式”和两档缩图建议不是本轮新增约束，用户本轮优先复用可解码 WebP；没有改变 P0 的样本 PNG 或 Grid/Hero 图片策略。

## 命令

```sh
# 首次需要启动一个 iOS 27 simulator；本命令不修改 P0 app 或真机。
yarn ios:asset:probe
# 可指定已经启动的 iOS 27 simulator UDID：yarn ios:asset:probe <UDID>
yarn ios:asset:generate
yarn ios:asset:validate
yarn ios:asset:determinism
yarn ios:asset:test
```

generate/validate/determinism 支持 `--canonical DIR`、`--evidence FILE`；generate/validate 支持 `--out DIR`。默认素材输出 `build/ios-content/assets/current/`，探针输入/可执行文件/报告在 `build/ios-content/assets-evidence/`。这些目录已经被 `/build/ios-content/` 忽略，不将全量素材或机器探针证据提交为 fixtures。

`probe` 只选择已启动的 iOS 27 simulator，检查源 hash 后逐图解码。缺少 runtime/证据直接失败，不能用猜测填充 native 验证。证据覆盖、源 hash、尺寸/alpha 与当前输入有任何差异，materializer 失败；不会自动改用 PNG 或让坏图进入 missing。

## 验证与写入

读取冻结 canonical manifest/schema 与 17 个实体文件，检查 schemaVersion=2、schema hash、每个文件 bytes/hash、canonical 编码、唯一键、FK、manifest assets/缺失清单。核对每个 assetKey=`purpose:sourcePath`、引用用途、宠物 resourceKey→头像路径、关联 petIds；拒绝没有消费方的素材。不复制 friends/items 整个目录。

存在的图片必须匹配 manifest source hash、是完整可解码的静态 WebP、具有有效尺寸。源路径越界/符号链接、未知缺图、原 known missing 文件突然出现、解码错误或 metadata 不一致直接失败。已知缺图没有输出图片、尺寸/hash 猜测值或假占位。

生成先写 staging，逐文件验证后原子切换。旧目录必须属于本生成器、文件清单完整且每个旧文件 hash 未变；未知文件/手改字节/符号链接直接失败。validate 从相同冻结输入独立重建预期包，比较目录清单与全部实际字节，也检查 manifest/missing/evidence。determinism 连续两次独立读取/解码/写磁盘，核对目录结构及全部文件名、内容、hash。临时 staging 路径不进入产物。

## 目录与 asset manifest

```text
build/ios-content/assets/current/
  asset-manifest.json
  missing-assets.json
  decode-evidence.json
  images/portraitGrid/<sha256(assetKey)>.webp
  images/skill/<sha256(assetKey)>.webp
  images/trait/<sha256(assetKey)>.webp
```

路径由稳定 assetKey 的 SHA-256 决定。无时间戳、随机文件名、机器绝对路径；已保存 native 报告只包含 key/hash/像素数据/OS 版本，不包含输入绝对路径。多个 PetID 共享一张 canonical 图片时记录 `petIds` 数组，不误认作一对一。技能/特性图标的 petIds 来自 petSkills/petDetails，references 同时保留直接 SkillID/TraitID，纯技能查询图标没有宠物关联也能明确表达空数组。

独立 `assetManifestVersion=1`，**不是 canonical schemaVersion 升级**。字段包括：

- canonicalSchemaVersion=2、canonicalContentVersion、canonicalManifestSha256。
- generatorVersion/mode、固定 decoderVersions、工具源码 hash、nativeDecodeEvidenceSha256、counts。
- assets：assetKey、petIds、references、sourcePath/sourceSha256、relativeOutputPath/outputSha256、width/height、format、hasAlpha/alpha、missing/missingReason。
- files：所有图片、missing report 和 native evidence 的 relativePath/bytes/hash；manifest 不自哈希，determinism 单独返回 assetManifestSha256。

available 记录的 output path/hash/尺寸明确；missing 记录这些值为 null、missing=true、原 missingReason。开放字典固定字符串排序、数组保持明确稳定顺序、UTF-8/4 空格/LF；不保存生成时间或绝对 build 目录。

## 实际产物与剩余边界

1,467 个 canonical asset key：**1,465 张真实图片 + 2 个 known missing**。总文件数 1,468（图片 + 三个 JSON）。图片 52,992,058 bytes（约 50.54 MiB）；包含详细引用/native evidence 的素材包约 55.87 MiB。该源尺寸略高于旧规划 50 MiB 图片目标；本轮没有为压缩预算擅自缩图、重编码或变更引用。完整 App 内容包体积/内存需后续独立验收。

缺图 ID：

- `portraitGrid:public/assets/webp/friends/img_Wat_ZhuZhuTun1_001_Res.webp`，petId=3784。
- `portraitGrid:public/assets/webp/friends/img_Wat_ZhuZhuTun2_001_Res.webp`，petId=3785。

没有未知 missing，没有替代图片。真实素材及明确缺图契约足以开始 Swift 只读 ContentStore 的 manifest/JSON/asset key→文件读取；本轮未开始实现它。真机性能、包体预算和缺图展示策略不伪装为已经验收。

验收结果见 [asset verification](asset-verification.md)。
