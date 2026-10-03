import RocoDomain

/// Query a concrete SkillID. Deliberately does not merge aliases or change the skill directory.
public struct SkillAcquisitionQuery: Sendable {
    public struct Result: Sendable {
        public let key: String
        public let representative: Pet
        public let acquired: [PetSkill]
    }
    public var keyword = ""
    public var source: PetSkillSource?
    public var type: TypeID?
    public var implementation = PetQuery.Implementation.implemented
    public var highest = true
    public init() {}
    public func results(skill: SkillID, index: SkillSearchIndex, content: ContentStore) -> [Result] {
        let relations = (index.directBySkill[skill] ?? []).filter { source == nil || $0.source == source }
        var rows: [Result] = []
        if highest {
            for family in index.familiesBySkill[skill] ?? [] {
                guard let pet = content.pets[family.representativePetId], !pet.isLeader else { continue }
                let members = Set(family.memberPetIds)
                let acquired = relations.filter { members.contains($0.petId) }
                if !acquired.isEmpty { rows.append(Result(key: family.familyKey.rawValue, representative: pet, acquired: acquired)) }
            }
        } else {
            for pet in content.orderedPets where pet.publicVisible {
                let acquired = relations.filter { $0.petId == pet.petId }
                if !acquired.isEmpty { rows.append(Result(key: "pet:\(pet.petId.rawValue)", representative: pet, acquired: acquired)) }
            }
        }
        return rows.filter { row in
            let pet = row.representative
            return (implementation == .all || pet.implemented == (implementation == .implemented))
                && (type == nil || pet.typeIds.contains(type!))
                && (PetSearch.matches(pet, query: keyword) || row.acquired.contains { relation in
                    content.pets[relation.petId].map { PetSearch.matches($0, query: keyword) } == true
                })
        }.sorted { ($0.representative.speciesId.rawValue, $0.representative.petId.rawValue) < ($1.representative.speciesId.rawValue, $1.representative.petId.rawValue) }
    }
}
