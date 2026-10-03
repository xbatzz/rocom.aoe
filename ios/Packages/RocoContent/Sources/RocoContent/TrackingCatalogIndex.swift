import Foundation
import RocoDomain

public struct TrackingCatalogIndex: Sendable {
    public let slotSearch: [ShinySlotID: String]
    public let familySearch: [FamilyKey: String]
    public let badgeFamilies: [Family]
    public let orderedBadgeFootprints: [BadgeFootprint]
    public let footprintsByFamily: [FamilyKey: [BadgeFootprint]]

    public func matches(_ family: Family, query: String, content: ContentStore) -> Bool {
        matches(family, query: PetSearch.Query(query), content: content)
    }
    public func matches(_ slot: ShinySlot, query: String, content: ContentStore) -> Bool {
        matches(slot, query: PetSearch.Query(query), content: content)
    }
    public func matches(_ family: Family, query: PetSearch.Query, content: ContentStore) -> Bool {
        family.memberPetIds.contains { content.pets[$0].map { query.matches($0) } == true }
    }
    public func matches(_ slot: ShinySlot, query: PetSearch.Query, content: ContentStore) -> Bool {
        slot.memberPetIds.contains { content.pets[$0].map { query.matches($0) } == true }
    }

    public init(content: ContentStore) {
        func terms(_ ids: [PetID]) -> String {
            ids.compactMap { content.pets[$0] }.map {
                "\($0.nameZh) \($0.petId.rawValue) \($0.handbookId?.rawValue ?? $0.speciesId.rawValue) \($0.form) \($0.searchAliases.joined(separator: " "))"
            }.joined(separator: " ")
        }
        slotSearch = content.shinySlots.mapValues { terms($0.memberPetIds) }
        badgeFamilies = content.families.values.filter { $0.kind == .badgeRoot }.sorted { $0.ordinal < $1.ordinal }
        familySearch = Dictionary(uniqueKeysWithValues: badgeFamilies.map { ($0.familyKey, terms($0.memberPetIds)) })
        orderedBadgeFootprints = content.badgeFootprints.values.sorted { ($0.stageDepth, $0.petId.rawValue) < ($1.stageDepth, $1.petId.rawValue) }
        var footprints: [FamilyKey: [BadgeFootprint]] = [:]
        for footprint in content.badgeFootprints.values {
            // family keys have distinct tag types; use the canonical string identity.
            let key = FamilyKey(rawValue: footprint.familyKey.rawValue)
            footprints[key, default: []].append(footprint)
        }
        footprintsByFamily = footprints.mapValues { $0.sorted { ($0.stageDepth, $0.petId.rawValue) < ($1.stageDepth, $1.petId.rawValue) } }
    }
}
