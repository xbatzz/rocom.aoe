import Foundation
import RocoDomain

/// Pure values constructed once per application snapshot. No images or JSON decoding.
public struct SkillSearchIndex: Sendable {
    public struct Entry: Sendable {
        public let id: SkillID
        public let text: String
        public let type: TypeID?
        public let category: SkillCategory
    }
    private let configurationEntries: [Entry]
    private let catalogIDBySkill: [SkillID: SkillID]
    private let equipmentSkillIDs: Set<SkillID>
    public let entries: [Entry]
    public let directBySkill: [SkillID: [PetSkill]]
    public let familiesBySkill: [SkillID: [Family]]
    public let groupsBySkill: [SkillID: SkillGroup]
    public let directBySkillAndSource: [SkillID: [PetSkillSource: [PetSkill]]]
    public let sameNameFamilyCount: [SkillID: Int]
    public let sameNameSkillIDs: [SkillID: [SkillID]]

    @concurrent public static func buildInBackground(content: ContentStore) async -> SkillSearchIndex { SkillSearchIndex(content: content) }

    public init(content: ContentStore) {
        configurationEntries = content.skills.values.sorted { $0.skillId.rawValue < $1.skillId.rawValue }.map {
            Entry(id: $0.skillId, text: "\($0.nameZh) \($0.skillId.rawValue) \($0.description)", type: $0.typeId, category: $0.category)
        }
        directBySkill = Dictionary(grouping: content.petSkillsByPet.values.flatMap { $0 }, by: \.skillId)
            .mapValues { $0.sorted { ($0.petId.rawValue, $0.source.rawValue, $0.ordinal) < ($1.petId.rawValue, $1.source.rawValue, $1.ordinal) } }
        var familyIndex: [SkillID: [Family]] = [:]
        for family in content.families.values.filter({ $0.kind == .skillTerminal }).sorted(by: { $0.ordinal < $1.ordinal }) {
            let skills = Set(family.memberPetIds.flatMap { content.petSkills(for: $0).map(\.skillId) })
            for skill in skills { familyIndex[skill, default: []].append(family) }
        }
        familiesBySkill = familyIndex
        var groups: [SkillID: SkillGroup] = [:]
        for group in content.skillGroups.values.sorted(by: { $0.ordinal < $1.ordinal }) {
            for id in Set(group.aliasIds + [group.displayId]) { groups[id] = group }
        }
        groupsBySkill = groups
        var sameNameIndex: [SkillID: [SkillID]] = [:]
        for skills in Dictionary(grouping: content.skills.values, by: \.nameZh).values {
            let ids = skills.map(\.skillId).sorted { $0.rawValue < $1.rawValue }
            for id in ids { sameNameIndex[id] = ids }
        }
        sameNameSkillIDs = sameNameIndex
        directBySkillAndSource = directBySkill.mapValues { Dictionary(grouping: $0, by: \.source) }
        var counts: [SkillID: Int] = [:]
        for ids in Dictionary(grouping: content.skills.values, by: \.nameZh).values.map({ $0.map(\.skillId) }) {
            var families = Set<FamilyKey>()
            for id in ids {
                for family in familyIndex[id] ?? [] {
                    if let pet = content.pets[family.representativePetId], pet.implemented && !pet.isLeader {
                        families.insert(family.familyKey)
                    }
                }
            }
            for id in ids { counts[id] = families.count }
        }
        sameNameFamilyCount = counts
        equipmentSkillIDs = Set(content.skills.values.filter(\.isBattleEquipmentGranted).map(\.skillId))
        var catalogIDs: [SkillID: SkillID] = [:]
        for ids in sameNameIndex.values {
            guard let representative = ids.first,
                counts[representative, default: 0] > 0 || equipmentSkillIDs.contains(representative) else { continue }
            for id in ids { catalogIDs[id] = representative }
        }
        catalogIDBySkill = catalogIDs
        entries = configurationEntries.filter { catalogIDs[$0.id] == $0.id }
    }

    @concurrent public func searchInBackground(_ query: String, type: TypeID?, category: SkillCategory?) async -> [SkillID] {
        search(query, type: type, category: category)
    }

    public func search(_ query: String, type: TypeID?, category: SkillCategory?) -> [SkillID] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var matched = Set<SkillID>()
        for entry in configurationEntries {
            guard let catalogID = catalogIDBySkill[entry.id] else { continue }
            let categoryMatches = if equipmentSkillIDs.contains(entry.id) {
                category == nil || category == .physicalAttack || category == .magicAttack
            } else {
                category == nil || entry.category == category
            }
            if (type == nil || entry.type == type) && categoryMatches
                && (text.isEmpty || entry.text.localizedStandardContains(text)) {
                matched.insert(catalogID)
            }
        }
        return matched.sorted { $0.rawValue < $1.rawValue }
    }
}
