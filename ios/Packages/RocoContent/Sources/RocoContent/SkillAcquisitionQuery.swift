import RocoDomain

/// Concrete configuration queries stay exact; the skill catalog can opt into same-name acquisition.
public struct SkillAcquisitionQuery: Sendable {
    public enum Scope: Sendable { case configuration, sameName }
    public struct Result: Sendable {
        public let key: String
        public let representative: Pet
        public let acquired: [PetSkill]
        public let memberCount: Int
        init(key: String, representative: Pet, acquired: [PetSkill]) {
            self.key = key
            self.representative = representative
            self.acquired = acquired
            memberCount = Set(acquired.map(\.petId)).count
        }
    }
    public var keyword = ""
    public var source: PetSkillSource?
    public var type: TypeID?
    public var implementation = PetQuery.Implementation.implemented
    public var highest = true
    public let scope: Scope
    public init(scope: Scope = .configuration) { self.scope = scope }
    @concurrent public func resultsInBackground(skill: SkillID, index: SkillSearchIndex, content: ContentStore) async -> [Result] {
        results(skill: skill, index: index, content: content)
    }

    public func results(skill: SkillID, index: SkillSearchIndex, content: ContentStore) -> [Result] {
        let search = PetSearch.Query(keyword)
        let ids = scope == .sameName ? index.sameNameSkillIDs[skill] ?? [skill] : [skill]
        let relations = ids.flatMap { id in
            if let source { return index.directBySkillAndSource[id]?[source] ?? [] }
            return index.directBySkill[id] ?? []
        }
        var rows: [Result] = []
        if highest {
            var seen = Set<FamilyKey>()
            for family in ids.flatMap({ index.familiesBySkill[$0] ?? [] }) where seen.insert(family.familyKey).inserted {
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
                && (search.matches(pet) || row.acquired.contains { relation in
                    content.pets[relation.petId].map { search.matches($0) } == true
                })
        }.sorted { ($0.representative.speciesId.rawValue, $0.representative.petId.rawValue) < ($1.representative.speciesId.rawValue, $1.representative.petId.rawValue) }
    }
}
