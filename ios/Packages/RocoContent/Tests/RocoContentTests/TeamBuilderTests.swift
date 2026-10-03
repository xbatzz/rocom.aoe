import Foundation
import Testing
import RocoDomain
@testable import RocoContent

struct TeamBuilderTests {
    private func content() throws -> ContentStore {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try ContentStore.load(bundle: #require(Bundle(url: root.appendingPathComponent("build/ios-content/store/ContentResources.bundle"))))
    }
    private struct Fixtures: Decodable {
        let cases: [Fixture]
        struct Fixture: Decodable {
            let petID: Int; let legacyTypeID: Int; let personalityID: Int
            let individuals: [Int]; let skills: [Int]; let stats: [Int]
            let scores: [Score]
        }
        struct Score: Decodable { let id: Int; let score: Double }
    }
    @Test func webRecommendationAndStatFixtures() throws {
        let content = try content()
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/WebTeamFixtures.json")
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
        for f in fixtures.cases {
            let pet = try #require(content.pets[PetID(rawValue: f.petID)])
            var slot = try TeamRules.assign(pet, content: content)
            slot.legacyTypeID = f.legacyTypeID
            #expect(try TeamRules.recommended(slot, content: content) == f.skills)
            let options = try TeamRules.options(slot, content: content)
            #expect(options.count == f.scores.count)
            for (option, expected) in zip(options, f.scores) {
                #expect(option.skill.skillId.rawValue == expected.id)
                #expect(option.score == expected.score)
            }
            let personality = try #require(content.personalities[PersonalityID(rawValue: f.personalityID)])
            #expect(try BattleStatsCalculator.calculate(pet: pet, individuals: f.individuals, personality: personality) == f.stats)
        }
    }
    @Test func duplicatePetsExchangeIndividualsAndLegacySafety() throws {
        let c = try content()
        let pet = try #require(c.orderedPets.first { $0.implemented && $0.publicVisible && !$0.isLeader && TeamRules.legacyOptions($0, content: c).count > 1 })
        let slot = try TeamRules.assign(pet, content: c)
        var team = TeamBuild()
        team.slots[0] = slot; team.slots[1] = slot
        team.slots[2].petID = 999999
        try team.validate() // Repeated pets and unresolved IDs are preserved.
        try team.swapSlots(0, 2)
        #expect(team.slots[0].petID == 999999 && team.slots[2] == slot && team.slots[1] == slot)
        #expect(throws: ContentError.self) { try TeamRules.validateIndividuals([1,1,1,1,0,0]) }
        var unresolved = slot; unresolved.skillIDs = [999999]
        let legacy = try #require(TeamRules.legacyOptions(pet, content: c).first { $0.rawValue != slot.legacyTypeID })
        let changed = try TeamRules.changeLegacy(unresolved, to: legacy.rawValue, content: c)
        #expect(changed.skillIDs == [999999])
        var empty = slot; empty.skillIDs = []
        #expect(try TeamRules.changeLegacy(empty, to: legacy.rawValue, content: c).skillIDs.isEmpty)
        let legal = try TeamRules.options(changed, content: c)
        let knownChanged = try TeamRules.changeLegacy(slot, to: legacy.rawValue, content: c)
        #expect(knownChanged.skillIDs.allSatisfy { id in legal.contains { $0.skill.skillId.rawValue == id } })
        if let first = legal.first {
            let once = try TeamRules.toggleSkill(first.skill.skillId.rawValue, slot: empty, content: c)
            #expect(once.skillIDs.count == 1)
            #expect(try TeamRules.toggleSkill(first.skill.skillId.rawValue, slot: once, content: c).skillIDs.isEmpty)
        }
    }
}
