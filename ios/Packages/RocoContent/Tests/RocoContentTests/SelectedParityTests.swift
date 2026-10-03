import Foundation
import Testing
import RocoDomain
@testable import RocoContent

struct SelectedParityTests {
    private func content() throws -> ContentStore {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try ContentStore.load(bundle: #require(Bundle(url: root.appendingPathComponent("build/ios-content/store/ContentResources.bundle"))))
    }
    @Test func exactMemberIdentifiersCombinedFiltersAndAllStatsSort() throws {
        let c = try content(), tracking = TrackingCatalogIndex(content: c)
        for family in tracking.badgeFamilies {
            for id in family.memberPetIds {
                let pet = try #require(c.pets[id])
                #expect(tracking.matches(family, query: String(id.rawValue), content: c))
                #expect(tracking.matches(family, query: String(pet.handbookId?.rawValue ?? pet.speciesId.rawValue), content: c))
            }
        }
        for slot in c.shinySlots.values {
            #expect(tracking.matches(slot, query: String(slot.targetPetId.rawValue), content: c))
        }
        let relation = try #require(c.petSkillsByPet.values.flatMap { $0 }.first { c.pets[$0.petId]?.publicVisible == true && c.pets[$0.petId]?.implemented == true })
        let pet = try #require(c.pets[relation.petId])
        var query = PetQuery(); query.keyword = String(pet.petId.rawValue); query.skill = relation.skillId; query.source = relation.source; query.type = pet.typeIds.first; query.style = pet.attackStyle
        #expect(query.results(content: c).contains { $0.petId == pet.petId })
        query.source = relation.source == .pool ? .stone : .pool
        #expect(query.results(content: c).allSatisfy { c.petSkills(for: $0.petId).contains { $0.skillId == relation.skillId && $0.source == query.source } })
        query = PetQuery(); query.implementation = .unimplemented
        #expect(!query.results(content: c).isEmpty)
        #expect(query.results(content: c).allSatisfy { !$0.implemented })
        for sort in PetQuery.Sort.allCases { query.sort = sort; let ascending = query.results(content: c); query.descending = true; let descending = query.results(content: c); #expect(Set(ascending.map(\.petId)) == Set(descending.map(\.petId))); query.descending = false }
        let unrelated = try #require(c.orderedPets.first { $0.petId != pet.petId && $0.speciesId != pet.speciesId && $0.handbookId != pet.handbookId })
        #expect(!PetSearch.matches(unrelated, query: "#\(pet.petId.rawValue)"))
    }
    @Test func concreteSkillFamilySourceAndMemberExpansion() throws {
        let c = try content(), index = SkillSearchIndex(content: c)
        for id in c.skills.keys {
            var query = SkillAcquisitionQuery()
            let families = query.results(skill: id, index: index, content: c)
            #expect(families.allSatisfy { $0.representative.implemented && !$0.representative.isLeader && !$0.acquired.isEmpty && $0.acquired.allSatisfy { $0.skillId == id } })
            query.source = .bloodline
            #expect(query.results(skill: id, index: index, content: c).allSatisfy { $0.acquired.allSatisfy { $0.source == .bloodline } })
            query.highest = false; query.implementation = .all; query.source = nil
            #expect(query.results(skill: id, index: index, content: c).allSatisfy { row in row.acquired.allSatisfy { $0.petId == row.representative.petId } })
        }
    }
    @Test func presetsKeepMovesAndLegacyAndSelectedDefense() throws {
        let c = try content()
        for pet in c.orderedPets.filter({ $0.implemented && $0.publicVisible && !$0.isLeader }).prefix(40) {
            let original = try TeamRules.assign(pet, content: c)
            for preset in BuildPreset.allCases {
                let slot = preset.apply(to: original, pet: pet, content: c)
                try TeamRules.validateIndividuals(slot.individualValues)
                #expect(slot.petID == original.petID && slot.skillIDs == original.skillIDs && slot.legacyTypeID == original.legacyTypeID)
                if preset == .none { #expect(slot.personalityID == nil && slot.individualValues.allSatisfy { $0 == 0 }) }
                else {
                    let stat = preset == .maxHp ? 0 : preset == .maxSpeed ? 5 : pet.attackStyle == .magic ? 2 : pet.attackStyle == .physical ? 1 : pet.baseStats.physicalAttack >= pet.baseStats.magicalAttack ? 1 : 2
                    let personality = try #require(slot.personalityID.flatMap { c.personalities[PersonalityID(rawValue: $0)] })
                    let p = personality.modifiers
                    #expect([p.hp.rawValue, p.physicalAttack.rawValue, p.magicalAttack.rawValue, p.physicalDefense.rawValue, p.magicalDefense.rawValue, p.speed.rawValue][stat] > 0)
                }
            }
        }
        let pets = Array(c.orderedPets.filter { $0.implemented && $0.publicVisible && !$0.isLeader }.prefix(6))
        let type = try #require(TypeMatchup(types: c.types).selectable.last?.typeId)
        let analysis = try TeamDefense.analyze(attacker: #require(pets.first), candidates: pets, content: c, attackType: type)
        #expect(analysis.slots.allSatisfy { $0.attackTypeID == type })
        #expect(analysis.slots.map(\.multiplier) == analysis.slots.map(\.multiplier).sorted())
    }
}
