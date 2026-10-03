import Foundation
import Testing
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
}
