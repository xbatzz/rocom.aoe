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
}
