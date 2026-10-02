import Foundation
import RocoDomain

public enum AssetResolution: Equatable, Sendable {
    case available(URL)
    case missing(KnownMissingAsset)
}
public struct KnownMissingAsset: Equatable, Sendable {
    public let assetId: AssetID
    public let petIds: [PetID]
    public let reason: String
}

/// Resolves metadata/URLs only. Does not decode WebP or allocate placeholder bitmaps.
public struct AssetResolver: Sendable {
    private let resolutions: [AssetID: AssetResolution]
    let records: [AssetID: MaterializedAsset]
    public let materializedCount: Int
    public let missingCount: Int

    static let knownMissing: [AssetID: PetID] = [
        AssetID(rawValue: "portraitGrid:public/assets/webp/friends/img_Wat_ZhuZhuTun1_001_Res.webp"): PetID(rawValue: 3784),
        AssetID(rawValue: "portraitGrid:public/assets/webp/friends/img_Wat_ZhuZhuTun2_001_Res.webp"): PetID(rawValue: 3785)
    ]

    init(bundle: Bundle, directory: String, canonical: [AssetID: Asset], manifest: Manifest, canonicalManifestHash: String) throws {
        let reader = try BundleReader(bundle: bundle, directory: directory)
        let assets = try reader.decode(AssetManifest.self, path: "asset-manifest.json")
        try require(assets.assetManifestVersion == 1 && assets.canonicalSchemaVersion == 2 && assets.mode == "copy-webp", "Unsupported asset manifest version/mode")
        try require(assets.canonicalContentVersion == manifest.contentVersion && assets.canonicalManifestSha256 == canonicalManifestHash, "Asset manifest belongs to different canonical package")
        records = try uniqueIndex(assets.assets, id: { $0.assetKey }, context: "asset manifest")
        let files = try uniqueIndex(assets.files, id: { $0.relativePath }, context: "asset files")
        try require(Set(records.keys) == Set(canonical.keys), "Asset manifest/canonical IDs differ")
        try require(Set(manifest.knownMissingAssets) == Set(Self.knownMissing.keys) && manifest.knownMissingAssets.count == 2, "Unknown/mismatched knownMissingAssets")
        var states: [AssetID: AssetResolution] = [:]
        var paths = Set<String>()
        var materialized = 0, missing = 0
        for (id, source) in canonical {
            guard let output = records[id] else { throw ContentError.invalid("Missing asset record: \(id.rawValue)") }
            try require(id.rawValue == source.purpose.rawValue + ":" + source.sourcePath, "Canonical asset key mismatch: \(id.rawValue)")
            try require(output.sourcePath == source.sourcePath && output.sourceSha256 == source.sourceSha256, "Asset source mismatch: \(id.rawValue)")
            if output.missing {
                guard let pet = Self.knownMissing[id] else { throw ContentError.invalid("Unknown missing asset: \(id.rawValue)") }
                try require(source.availability == .missing && source.sourceSha256 == nil && source.sourceFormat == nil && source.missingReason == "source-file-missing", "Invalid canonical missing descriptor: \(id.rawValue)")
                try require(output.petIds == [pet] && output.missingReason == "source-file-missing" && output.relativeOutputPath == nil && output.outputSha256 == nil && output.format == nil && output.width == nil && output.height == nil && output.hasAlpha == nil && output.alpha == nil, "Invalid missing output: \(id.rawValue)")
                states[id] = .missing(KnownMissingAsset(assetId: id, petIds: [pet], reason: "source-file-missing"))
                missing += 1
            } else {
                try require(Self.knownMissing[id] == nil, "Known missing unexpectedly materialized: \(id.rawValue)")
                guard let path = output.relativeOutputPath, let file = files[path] else { throw ContentError.invalid("Missing output/file entry: \(id.rawValue)") }
                try require(source.availability == .available && source.sourceFormat == .webp && source.sourceSha256 != nil && source.missingReason == nil && output.missingReason == nil && output.format == "webp" && output.outputSha256 == source.sourceSha256 && file.sha256 == source.sourceSha256, "Invalid available output: \(id.rawValue)")
                try require(path.hasPrefix("images/" + source.purpose.rawValue + "/") && path.hasSuffix(".webp") && paths.insert(path).inserted, "Invalid/duplicate output path: \(path)")
                try require((output.width ?? 0) > 0 && (output.height ?? 0) > 0 && output.alpha != nil && output.hasAlpha != nil, "Missing decode metadata: \(id.rawValue)")
                let data = try reader.data(path)
                try require(data.count == file.bytes && sha256(data) == file.sha256, "Missing/corrupt Bundle WebP: \(path)")
                try require(data.count >= 12 && data.prefix(4) == Data("RIFF".utf8) && data[8..<12] == Data("WEBP".utf8), "Invalid WebP header: \(path)")
                states[id] = .available(try BundleReader.containedURL(root: reader.root, path: path))
                materialized += 1
            }
        }
        try require(Set(files.keys) == paths.union(["decode-evidence.json", "missing-assets.json"]), "Unexpected asset file coverage")
        for path in ["decode-evidence.json", "missing-assets.json"] {
            guard let file = files[path] else { throw ContentError.invalid("Missing audit file: \(path)") }
            let bytes = try reader.data(path)
            try require(bytes.count == file.bytes && sha256(bytes) == file.sha256, "Asset audit file mismatch: \(path)")
        }
        try require(files["decode-evidence.json"]?.sha256 == assets.nativeDecodeEvidenceSha256, "Decode evidence hash mismatch")
        try require(assets.counts == ["assets": canonical.count, "materialized": materialized, "missing": missing] && missing == 2, "Asset counts mismatch")
        resolutions = states
        materializedCount = materialized
        missingCount = missing
    }

    public func resolve(_ id: AssetID) throws -> AssetResolution {
        guard let result = resolutions[id] else { throw ContentError.invalid("Unknown asset ID: \(id.rawValue)") }
        return result
    }
}
