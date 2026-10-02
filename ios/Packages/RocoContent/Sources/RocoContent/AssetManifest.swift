import Foundation
import RocoDomain

/// Materialization manifest is separate from the frozen canonical schema.
public struct AssetManifest: Decodable, Sendable {
    public let assetManifestVersion: Int
    public let canonicalSchemaVersion: Int
    public let canonicalContentVersion: String
    public let canonicalManifestSha256: String
    public let counts: [String: Int]
    public let assets: [MaterializedAsset]
    public let files: [AssetFile]
    public let generatorVersion: String
    public let mode: String
    public let decoderVersions: [String: String]
    public let nativeDecodeEvidenceSha256: String
    public let toolInputs: [String: String]
}
public struct AssetFile: Decodable, Sendable {
    public let relativePath: String
    public let bytes: Int
    public let sha256: String
}
public struct MaterializedAsset: Decodable, Sendable {
    public let assetKey: AssetID
    public let sourcePath: String
    public let sourceSha256: String?
    public let relativeOutputPath: String?
    public let outputSha256: String?
    public let format: String?
    public let width: Int?
    public let height: Int?
    public let hasAlpha: Bool?
    public let alpha: AlphaEvidence?
    public let missing: Bool
    public let missingReason: String?
    public let petIds: [PetID]
    public let references: [AssetReference]

    public init(from decoder: any Decoder) throws {
        let c = try StrictObject(decoder, keys: ["assetKey", "sourcePath", "sourceSha256", "relativeOutputPath", "outputSha256", "format", "width", "height", "hasAlpha", "alpha", "missing", "missingReason", "petIds", "references"])
        assetKey = try c.value("assetKey")
        sourcePath = try c.value("sourcePath")
        sourceSha256 = try c.value("sourceSha256")
        relativeOutputPath = try c.value("relativeOutputPath")
        outputSha256 = try c.value("outputSha256")
        format = try c.value("format")
        width = try c.value("width")
        height = try c.value("height")
        hasAlpha = try c.value("hasAlpha")
        alpha = try c.value("alpha")
        missing = try c.value("missing")
        missingReason = try c.value("missingReason")
        petIds = try c.value("petIds")
        references = try c.value("references")
    }
}
public struct AlphaEvidence: Decodable, Sendable {
    public let sha256: String
    public let transparentPixels: Int
    public let partialAlphaPixels: Int
    public let opaquePixels: Int
}
public struct AssetReference: Decodable, Sendable {
    public let entity: String
    public let field: String
    public let id: JSONValue
    public let petIds: [PetID]
}
