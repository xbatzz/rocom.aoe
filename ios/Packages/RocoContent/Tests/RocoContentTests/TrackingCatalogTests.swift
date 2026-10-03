import Foundation
import Testing
import RocoDomain
@testable import RocoContent

struct TrackingCatalogTests {
    @Test func canonicalSlotsAndFootprintsStayDistinct() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let c = try ContentStore.load(bundle: #require(Bundle(url: root.appendingPathComponent("build/ios-content/store/ContentResources.bundle"))))
        let index = TrackingCatalogIndex(content: c)
        #expect(index.slotSearch.count == c.shinySlots.count)
        #expect(index.badgeFamilies.count == 192)
        #expect(index.footprintsByFamily.values.flatMap { $0 }.count == c.badgeFootprints.count)
        #expect(index.orderedBadgeFootprints == c.badgeFootprints.values.sorted {
            ($0.stageDepth, $0.petId.rawValue) < ($1.stageDepth, $1.petId.rawValue)
        })
        let families = Set(index.badgeFamilies.map(\.familyKey))
        #expect(Set(index.footprintsByFamily.keys).isSubset(of: families))
        for slot in c.shinySlots.values {
            #expect(c.shinySlotsBySeason[slot.seasonId]?.contains(slot) == true)
            for id in slot.memberPetIds {
                let pet = try #require(c.pets[id])
                #expect(index.slotSearch[slot.slotId]?.localizedStandardContains(pet.nameZh) == true)
                #expect(c.shinySlotsByPet[id]?.contains(slot) == true)
            }
        }
    }

    @Test func preparedSearchPreservesExactIdentifiersFormsAndAliases() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let c = try ContentStore.load(bundle: #require(Bundle(url: root.appendingPathComponent("build/ios-content/store/ContentResources.bundle"))), assetValidation: .onDemand)
        let index = TrackingCatalogIndex(content: c)
        // Freeze the original matching semantics across every real pet, family and slot.
        func original(_ pet: Pet, query: String) -> Bool {
            let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
                .applyingTransform(.fullwidthToHalfwidth, reverse: false)?.lowercased() ?? query.lowercased()
            if text.isEmpty { return true }
            let numberText = text.hasPrefix("#") ? String(text.dropFirst()) : text
            if let number = Int(numberText), numberText.allSatisfy(\.isNumber) {
                return pet.petId.rawValue == number || pet.handbookId?.rawValue == number || pet.speciesId.rawValue == number
            }
            return ([pet.nameZh, pet.form, pet.resourceKey] + pet.searchAliases).contains { $0.localizedStandardContains(text) }
        }
        let queries = ["", "  \n", "喵", "#３００１", "＃１", "30", "3001", "leader", "DEFAULT", "首领", "不存在的精灵技能"]
            + c.pets.values.flatMap(\.searchAliases)
        for query in queries {
            let prepared = PetSearch.Query(query)
            for pet in c.pets.values { #expect(prepared.matches(pet) == original(pet, query: query)) }
            for family in index.badgeFamilies {
                #expect(index.matches(family, query: prepared, content: c) == family.memberPetIds.contains { original(c.pets[$0]!, query: query) })
            }
            for slot in c.shinySlots.values {
                #expect(index.matches(slot, query: prepared, content: c) == slot.memberPetIds.contains { original(c.pets[$0]!, query: query) })
            }
        }
    }
}
