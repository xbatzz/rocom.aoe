import Foundation
import Testing
import RocoDomain
@testable import RocoContent

struct PetCatalogPresentationTests {
    private struct Fixtures: Decodable {
        let cases: [Fixture]
        struct Fixture: Decodable {
            let name: String
            let inputPetIDs: [Int]
            let expectedPetIDs: [Int]
        }
    }

    private func content() throws -> ContentStore {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bundle = try #require(Bundle(url: root.appendingPathComponent("build/ios-content/store/ContentResources.bundle")))
        return try ContentStore.load(bundle: bundle)
    }

    @Test func matchesWebCatalogFixtures() throws {
        let content = try content()
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/WebCatalogFixtures.json")
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
        for fixture in fixtures.cases {
            let input = try fixture.inputPetIDs.map { try #require(content.pet(PetID(rawValue: $0))) }
            let expected = fixture.expectedPetIDs
            for entries in [input, Array(input.reversed())] {
                let actual = PetCatalogPresentation.collapseDuplicateLeaderConfigurations(entries)
                    .sorted(by: PetCatalogPresentation.handbookOrder).map(\.petId.rawValue)
                #expect(actual == expected, "Web parity: \(fixture.name)")
            }
            if fixture.name == "default" {
                #expect(Set(input.map(\.petId)) == Set(content.pets.values.filter { $0.implemented && $0.publicVisible }.map(\.petId)))
                #expect(expected.first == 3004)
            }
        }
    }

    @Test func missingHandbookAndOrdinalDoNotChangeNumberOrder() throws {
        let content = try content()
        let original = try #require(content.pet(PetID(rawValue: 3001)))
        var fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        fields["speciesId"] = 1
        fields["handbookId"] = NSNull()
        fields["ordinal"] = 9999
        let unlinked = try JSONDecoder().decode(Pet.self, from: JSONSerialization.data(withJSONObject: fields))
        let dimo = try #require(content.pet(PetID(rawValue: 3004)))
        let actual = [original, dimo, unlinked].sorted(by: PetCatalogPresentation.handbookOrder)
        #expect(actual.map(\.petId.rawValue) == [3001, 3004, 3001])
        #expect(actual.map(\.speciesId.rawValue) == [1, 1, 2])
        #expect(actual.first?.handbookId == nil)
    }

    @Test func leaderRepresentativePrefersImplementationThenStatsThenID() throws {
        let content = try content()
        let first = try #require(content.pet(PetID(rawValue: 5001)))
        let alternate = try #require(content.pet(PetID(rawValue: 5047)))
        func edited(_ pet: Pet, _ changes: [String: Any]) throws -> Pet {
            var fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(pet)) as? [String: Any])
            fields.merge(changes) { _, new in new }
            return try JSONDecoder().decode(Pet.self, from: JSONSerialization.data(withJSONObject: fields))
        }
        let noStats = try edited(first, ["baseStats": ["hp": 0, "physicalAttack": 0, "magicalAttack": 0,
            "physicalDefense": 0, "magicalDefense": 0, "speed": 0]])
        let unreleased = try edited(alternate, ["implemented": false])
        #expect(PetCatalogPresentation.collapseDuplicateLeaderConfigurations([alternate, first]).map(\.petId) == [first.petId])
        #expect(PetCatalogPresentation.collapseDuplicateLeaderConfigurations([noStats, alternate]).map(\.petId) == [alternate.petId])
        #expect(PetCatalogPresentation.collapseDuplicateLeaderConfigurations([unreleased, noStats]).map(\.petId) == [first.petId])
    }
    @Test func catalogLeaderFilterSelectsFormsRatherThanPotential() async throws {
        let content = try content()
        var query = PetCatalogQuery()
        let all = await query.results(content: content)
        #expect(all.count == content.catalogPetCount)
        #expect(all.allSatisfy { $0.implemented && $0.publicVisible })
        query.leader = .leader
        let leaders = await query.results(content: content)
        #expect(!leaders.isEmpty)
        #expect(leaders.allSatisfy { $0.isLeader })
        let ordinaryWithPotential = try #require(all.first { !$0.isLeader && $0.leaderPotential })
        #expect(!leaders.contains { $0.petId == ordinaryWithPotential.petId })
        query.leader = .ordinary
        let ordinary = await query.results(content: content)
        #expect(ordinary.contains { $0.petId == ordinaryWithPotential.petId })
        #expect(ordinary.allSatisfy { !$0.isLeader })
    }

    @Test func catalogSkillSourceMustMatchTheSelectedSkillRecord() async throws {
        let content = try content()
        let pet = try #require(content.catalogPets.first { pet in
            let records = content.petSkills(for: pet.petId)
            return records.contains { record in
                records.contains { $0.source != record.source }
                    && !records.contains { $0.skillId == record.skillId && $0.source != record.source }
            }
        })
        let records = content.petSkills(for: pet.petId)
        let record = try #require(records.first { record in
            records.contains { $0.source != record.source }
                && !records.contains { $0.skillId == record.skillId && $0.source != record.source }
        })
        let otherSource = try #require(records.first { $0.source != record.source }?.source)
        var query = PetCatalogQuery()
        query.skill = record.skillId
        query.source = record.source
        let matching = await query.results(content: content)
        #expect(matching.contains { $0.petId == pet.petId })
        query.source = otherSource
        let mismatched = await query.results(content: content)
        #expect(!mismatched.contains { $0.petId == pet.petId })
        query.skill = nil
        let sourceOnly = await query.results(content: content)
        #expect(sourceOnly.contains { $0.petId == pet.petId })
    }

    @Test func clearingCatalogFiltersPreservesSearchAndSort() {
        var query = PetCatalogQuery()
        query.keyword = "喵喵"
        query.sort = .speed
        query.firstType = TypeID(rawValue: 2)
        query.secondType = TypeID(rawValue: 2)
        query.leader = .leader
        query.source = .stone
        #expect(query.filterCount == 3)
        query.clearFilters()
        #expect(!query.hasFilters)
        #expect(query.keyword == "喵喵")
        #expect(query.sort == .speed)
    }

}
