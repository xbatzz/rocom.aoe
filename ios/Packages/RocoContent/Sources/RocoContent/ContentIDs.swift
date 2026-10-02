import Foundation
import RocoDomain

public enum TraitTag: Sendable {}
public enum PersonalityTag: Sendable {}
public enum MagicItemTag: Sendable {}
public enum AssetTag: Sendable {}
public enum EvolutionEdgeTag: Sendable {}
public enum FamilyTag: Sendable {}
public enum FootprintTag: Sendable {}
public enum EffectTag: Sendable {}
public enum ShinyFamilyTag: Sendable {}
public typealias TraitID = StableID<TraitTag>
public typealias PersonalityID = StableID<PersonalityTag>
public typealias MagicItemID = StableID<MagicItemTag>
public typealias AssetID = StringID<AssetTag>
public typealias EvolutionEdgeID = StringID<EvolutionEdgeTag>
public typealias FamilyKey = StringID<FamilyTag>
public typealias FootprintKey = StringID<FootprintTag>
public typealias EffectID = StringID<EffectTag>
public typealias ShinyFamilyID = StableID<ShinyFamilyTag>

/// S0 is a real season. Positive-only StableID cannot represent it.
public struct SeasonID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(Int.self)
        guard rawValue >= 0 else { throw ContentError.invalid("Negative season ID") }
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
