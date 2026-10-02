import Foundation

/// P0 sample DTO. It is intentionally not the full P1 release catalog.
public struct PrototypePet: Codable, Identifiable, Sendable {
    public let petId: PetID
    public var id: PetID { petId }
    public let speciesId: SpeciesID
    public let handbookId: HandbookID?
    public let nameZh: String
    public let form: String
    public let typeNames: [String]
    public let baseStats: [Int]
    public let traitName: String?
    public let traitDescription: String?
    public let portraitFile: String?
    public let resourceKey: String

    public var numberLabel: String {
        if let handbookId { return String(format: "No. %03d", handbookId.rawValue) }
        return "配置 \(petId.rawValue)"
    }
}
public struct PrototypeCatalog: Codable, Sendable {
    public let schemaVersion: Int
    public let sourceRevision: String
    public let pets: [PrototypePet]
}
