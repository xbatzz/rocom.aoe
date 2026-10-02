import Foundation
import RocoDomain

private struct PetSkillIdentity: Hashable {
    let pet: PetID
    let skill: SkillID
    let source: PetSkillSource
    let legacy: TypeID?
}

extension ContentStore {
    func validateRelations(petSkillsRows: [PetSkill]) throws {
        func fk<ID, Row>(_ table: [ID: Row], _ id: ID?, _ context: String) throws {
            if let id { try require(table[id] != nil, "Unresolved FK \(context): \(id)") }
        }
        func refs<ID, Row>(_ table: [ID: Row], _ ids: [ID], _ context: String) throws {
            try require(Set(ids).count == ids.count, "Duplicate reference: \(context)")
            for id in ids { try fk(table, id, context) }
        }
        for p in pets.values {
            try require((1...2).contains(p.typeIds.count) && p.typeIds.allSatisfy { $0.rawValue <= 18 }, "Invalid pet battle types: \(p.petId.rawValue)")
            try refs(types, p.typeIds, "pets.typeIds")
            try fk(types, p.defaultLegacyTypeId, "pets.defaultLegacyTypeId")
            try fk(pets, p.parentPetId, "pets.parentPetId")
            try fk(petDetails, p.petId, "pets.detail")
            if let handbook = p.handbookId { try require(handbook.rawValue == p.speciesId.rawValue, "Handbook/species mismatch") }
            var visited = Set<PetID>(), current: Pet? = p
            while let node = current {
                try require(visited.insert(node.petId).inserted, "Parent cycle: \(node.petId.rawValue)")
                current = node.parentPetId.flatMap { pets[$0] }
            }
        }
        for d in petDetails.values {
            try fk(pets, d.petId, "petDetails.petId")
            try fk(traits, d.traitId, "petDetails.traitId")
        }
        for t in types.values {
            try require(t.typeId.rawValue <= 19 && t.normalBattleType == (t.typeId.rawValue <= 18), "Invalid battle type")
            try refs(types, t.weakToTypeIds, "types.weak")
            try refs(types, t.resistToTypeIds, "types.resist")
        }
        for s in skills.values { try fk(types, s.typeId, "skills.typeId") }
        for g in skillGroups.values {
            try refs(skills, g.aliasIds, "skillGroups.aliasIds")
            try fk(skills, g.displayId, "skillGroups.displayId")
            try require(g.aliasIds.contains(g.displayId), "Skill group display ID absent from aliases")
        }
        var identities = Set<PetSkillIdentity>()
        for r in petSkillsRows {
            try require(identities.insert(PetSkillIdentity(pet: r.petId, skill: r.skillId, source: r.source, legacy: r.legacyTypeId)).inserted, "Duplicate petSkills composite key")
            try fk(pets, r.petId, "petSkills.petId")
            try fk(skills, r.skillId, "petSkills.skillId")
            try fk(types, r.legacyTypeId, "petSkills.legacyTypeId")
            try require((r.source == .bloodline) == (r.legacyTypeId != nil), "Invalid petSkill source/legacy")
        }
        for e in evolutions.values {
            try fk(pets, e.sourcePetId, "evolutions.source")
            try fk(pets, e.targetPetId, "evolutions.target")
        }
        var done = Set<PetID>(), active = Set<PetID>()
        func visit(_ pet: PetID) throws {
            try require(!active.contains(pet), "Evolution cycle: \(pet.rawValue)")
            if done.contains(pet) { return }
            active.insert(pet)
            for edge in evolutionsByPet[pet] ?? [] { try visit(edge.targetPetId) }
            active.remove(pet)
            done.insert(pet)
        }
        for id in pets.keys { try visit(id) }
        for f in families.values {
            try require(matches(f.familyKey.rawValue, "^species:[1-9][0-9]*$"), "Invalid family key")
            try fk(pets, f.representativePetId, "families.representative")
            try refs(pets, f.memberPetIds, "families.members")
            try refs(types, f.typeIds, "families.types")
            try require(f.memberPetIds.contains(f.representativePetId), "Family representative absent")
        }
        let species = Set(pets.values.map { $0.speciesId.rawValue })
        for s in shinySlots.values {
            try require(species.contains(s.familyId.rawValue), "Unresolved shiny family/species")
            try fk(seasons, s.seasonId, "shinySlots.season")
            try refs(pets, s.memberPetIds, "shinySlots.members")
            try require(s.memberPetIds.contains(s.targetPetId) && s.memberPetIds.contains(s.representativePetId), "Shiny target/representative absent")
            try require(s.slotId.rawValue.hasPrefix("s\(s.seasonId.rawValue)-f\(s.familyId.rawValue)-"), "Shiny ID mismatch")
        }
        for b in badgeFootprints.values {
            try fk(pets, b.petId, "badgeFootprints.pet")
            try require(families[FamilyIdentity(kind: .badgeRoot, key: FamilyKey(rawValue: b.familyKey.rawValue))] != nil, "Unresolved badge family")
            try require(b.footprintKey.rawValue == "pet:\(b.petId.rawValue)", "Footprint ID mismatch")
        }
        for e in battleEffects.values {
            try fk(pets, e.petId, "battleEffects.pet")
            try fk(skills, e.skillId, "battleEffects.skill")
        }
        let selected = manifest.scope.rootPetIds + manifest.scope.dependencyPetIds
        let all = selected + manifest.scope.excludedPetIds
        try require(Set(all).count == all.count && Set(selected) == Set(pets.keys), "Scope duplicate/coverage mismatch")
        try fk(seasons, manifest.defaultSeason, "manifest.defaultSeason")
        try validateAssetReferences(petSkillsRows: petSkillsRows)
    }

    private func validateAssetReferences(petSkillsRows: [PetSkill]) throws {
        // Build reverse FK sets once; no skill × petSkills scans.
        let skillsToPets = Dictionary(grouping: petSkillsRows, by: \.skillId).mapValues { Set($0.map(\.petId)) }
        let traitsToPets = optionalIndex(Array(petDetails.values), id: { $0.traitId }).mapValues { Set($0.map(\.petId)) }
        var expected: [AssetID: [String: Set<PetID>]] = [:]
        func add(_ id: AssetID?, _ purpose: AssetPurpose, _ entity: String, _ rowID: String, _ field: String, _ petIDs: Set<PetID>) throws {
            guard let id else { return }
            try require(assets[id]?.purpose == purpose, "Asset FK/purpose mismatch: \(entity)/\(rowID)")
            expected[id, default: [:]][entity + "/" + rowID + "/" + field] = petIDs
        }
        for p in pets.values {
            if let id = p.portraitAssetId {
                try require(id.rawValue == "portraitGrid:public/assets/webp/friends/\(p.resourceKey).webp", "Pet portrait/resource mismatch")
            }
            try add(p.portraitAssetId, .portraitGrid, "pets", String(p.petId.rawValue), "portraitAssetId", [p.petId])
        }
        for s in skills.values { try add(s.iconAssetId, .skill, "skills", String(s.skillId.rawValue), "iconAssetId", skillsToPets[s.skillId] ?? []) }
        for t in traits.values { try add(t.iconAssetId, .trait, "traits", String(t.traitId.rawValue), "iconAssetId", traitsToPets[t.traitId] ?? []) }
        for s in shinySlots.values { try add(s.portraitAssetId, .portraitGrid, "shinySlots", s.slotId.rawValue, "portraitAssetId", Set(s.memberPetIds + [s.targetPetId, s.representativePetId])) }
        try require(Set(expected.keys) == Set(assets.keys), "Unreferenced canonical asset")
        for (id, record) in assetResolver.records {
            var actual: [String: Set<PetID>] = [:]
            for ref in record.references {
                let rowID: String
                switch ref.id {
                case .number(let number):
                    try require(number.isFinite && number.rounded() == number && number >= 1 && number < Double(Int.max), "Invalid numeric asset reference")
                    rowID = String(Int(number))
                case .string(let text): rowID = text
                default: throw ContentError.invalid("Invalid asset reference ID")
                }
                let key = ref.entity + "/" + rowID + "/" + ref.field
                try require(Set(ref.petIds).count == ref.petIds.count && actual.updateValue(Set(ref.petIds), forKey: key) == nil, "Duplicate asset reference")
            }
            try require(actual == expected[id], "Asset reference mismatch: \(id.rawValue)")
            let petIDs = actual.values.reduce(into: Set<PetID>()) { $0.formUnion($1) }
            try require(Set(record.petIds) == petIDs && record.petIds.count == petIDs.count, "Asset petIds mismatch: \(id.rawValue)")
        }
    }
}
