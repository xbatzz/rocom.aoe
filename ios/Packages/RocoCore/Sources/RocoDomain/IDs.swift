import Foundation

/// The tag is part of the type; equal source numbers never make different domains interchangeable.
public struct StableID<Tag>: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(Int.self)
        guard rawValue > 0 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "ID must be positive"))
        }
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
public enum PetTag: Sendable {}
public enum SpeciesTag: Sendable {}
public enum HandbookTag: Sendable {}
public enum SkillTag: Sendable {}
public enum TypeTag: Sendable {}
public typealias PetID = StableID<PetTag>
public typealias SpeciesID = StableID<SpeciesTag>
public typealias HandbookID = StableID<HandbookTag>
public typealias SkillID = StableID<SkillTag>
public typealias TypeID = StableID<TypeTag>

public struct StringID<Tag>: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
        guard !rawValue.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "ID must not be empty"))
        }
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
public enum SkillGroupTag: Sendable {}
public enum BadgeFamilyTag: Sendable {}
public enum SkillFamilyTag: Sendable {}
public enum ShinySlotTag: Sendable {}
public enum TeamTag: Sendable {}
public enum SlotTag: Sendable {}
public typealias SkillGroupID = StringID<SkillGroupTag>
public typealias BadgeFamilyKey = StringID<BadgeFamilyTag>
public typealias SkillTerminalFamilyKey = StringID<SkillFamilyTag>
public typealias ShinySlotID = StringID<ShinySlotTag>
public typealias TeamID = StringID<TeamTag>
public typealias SlotID = StringID<SlotTag>

public struct PortraitOrigin: Hashable, Sendable {
    public let petID: PetID
    public let instance: String
    public init(petID: PetID, instance: String) { self.petID = petID; self.instance = instance }
}
