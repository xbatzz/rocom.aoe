import Foundation
import Testing
@testable import RocoDomain

private func repository() -> URL {
    var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: url.appendingPathComponent("public/data/Pets.json").path) {
        precondition(url.path != "/", "Repository fixture root missing")
        url.deleteLastPathComponent()
    }
    return url
}

@Test func scalarIDsRoundTripAndRejectInvalidInput() throws {
    let id = PetID(rawValue: 3001)
    #expect(String(data: try JSONEncoder().encode(id), encoding: .utf8) == "3001")
    #expect(try JSONDecoder().decode(PetID.self, from: Data("3001".utf8)) == id)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(PetID.self, from: Data("0".utf8)) }
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(PetID.self, from: Data("\"3001\"".utf8)) }
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(TeamID.self, from: Data("\"\"".utf8)) }
}

@Test func sameSpeciesAndRepeatedPetHaveDistinctOrigins() {
    let first = PortraitOrigin(petID: PetID(rawValue: 3020), instance: "grid")
    let form = PortraitOrigin(petID: PetID(rawValue: 3454), instance: "grid")
    let slot = PortraitOrigin(petID: PetID(rawValue: 3020), instance: "team:anonymous:slot:2")
    #expect(Set([first, form, slot]).count == 3)
    #expect(TeamID(rawValue: "web-id-not-a-uuid").rawValue == "web-id-not-a-uuid")
}

@Test func sampleUsesRealIDsAndExplicitMissingPortraits() throws {
    let url = repository().appendingPathComponent("ios/RocoNative/Resources/PrototypeContent/pets.json")
    let catalog = try JSONDecoder().decode(PrototypeCatalog.self, from: Data(contentsOf: url))
    #expect(catalog.schemaVersion == 1)
    #expect(catalog.pets.count == 29)
    #expect(Set(catalog.pets.map(\.petId)).count == catalog.pets.count)
    #expect(catalog.pets.allSatisfy { $0.baseStats.count == 6 })
    #expect(catalog.pets.filter { $0.portraitFile == nil }.map(\.petId.rawValue) == [3784, 3785])
    let pet = try #require(catalog.pets.first)
    #expect(pet.petId.rawValue == 3001)
    #expect(pet.speciesId.rawValue == 2)
    #expect(pet.handbookId?.rawValue == 2)
    #expect(pet.nameZh == "喵喵")
    #expect(pet.baseStats == [65, 66, 66, 49, 91, 33])
}

@Test func frozenFixtureProvenanceIsExplicit() throws {
    let url = repository().appendingPathComponent("shared/fixtures/ios/p0.json")
    let records = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
    #expect(records.count == 42)
    #expect(records.allSatisfy { ($0["sourceRevision"] as? String)?.count == 40 })
    for id in ["PVP-D1", "PVP-D2", "PVP-D3", "PVP-D4"] {
        let record = try #require(records.first { $0["id"] as? String == id })
        #expect(record["evidence"] as? String == "manual-page-spec-example")
    }
}
