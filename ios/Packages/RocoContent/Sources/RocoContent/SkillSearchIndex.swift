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
    public let entries: [Entry]
    public let directBySkill: [SkillID: [PetSkill]]
    public let familiesBySkill: [SkillID: [Family]]
    public let groupsBySkill: [SkillID: SkillGroup]
    public let sameNameSkillIDs: [SkillID: [SkillID]]

    public init(content: ContentStore) {
        entries = content.skills.values.sorted { $0.skillId.rawValue < $1.skillId.rawValue }.map {
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
    }

    public func search(_ query: String, type: TypeID?, category: SkillCategory?) -> [SkillID] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter {
            (type == nil || $0.type == type) && (category == nil || $0.category == category)
                && (text.isEmpty || $0.text.localizedStandardContains(text))
        }.map(\.id)
    }
}
