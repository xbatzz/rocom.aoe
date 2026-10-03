import Foundation
import Testing
import RocoDomain
@testable import RocoContent

struct BattleCoreTests {
    struct Fixtures: Decodable {
        let cases: [Case]
        let speeds: [Speed]
        let switchCases: [Switch]
        let threatCases: [Threat]
        struct Threat: Decodable { let pet_id: Int; let weak_count: Int; let neutral_count: Int; let resist_count: Int; let has_safe_switch: Bool; let pierce_risk: Bool; let score: Double }
        struct Case: Decodable {
            let attackerID: Int; let defenderID: Int; let skillID: Int
            let attackerPersonalityID: Int; let defenderPersonalityID: Int; let individuals: [Int]
            let hpPercent: Int; let settings: Settings
            let displayPower: Int; let singleHit: Int; let total: Int; let defenderHP: Int
            let typeMultiplier: Double; let stabMultiplier: Double; let oneHit: Int?
        }
        struct Settings: Decodable { let choiceIndex: Int; let swarmPowerCount: Int; let swarmHitCount: Int; let blazingStage: Int }
        struct Speed: Decodable { let ball: MeteorBall; let speed: Int }
        struct Switch: Decodable { let attackerID: Int; let defenderID: Int; let multiplier: Double }
    }
    private func content() throws -> ContentStore {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try ContentStore.load(bundle: #require(Bundle(url: root.appendingPathComponent("build/ios-content/store/ContentResources.bundle"))))
    }
    @Test func webDamageConditionsOneHitMeteorAndSwitchFixtures() throws {
        let c = try content()
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/WebBattleFixtures.json")
        let fixture = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
        for f in fixture.cases {
            var attacker = BattleProfile(), defender = BattleProfile()
            attacker.slot.petID = f.attackerID; defender.slot.petID = f.defenderID
            attacker.slot.personalityID = f.attackerPersonalityID; defender.slot.personalityID = f.defenderPersonalityID
            attacker.slot.individualValues = f.individuals; defender.slot.individualValues = f.individuals
            attacker.hpPercent = f.hpPercent; defender.hpPercent = f.hpPercent
            var settings = DamageSettings()
            settings.choiceIndex = f.settings.choiceIndex; settings.swarmPowerCount = f.settings.swarmPowerCount
            settings.swarmHitCount = f.settings.swarmHitCount; settings.blazingStage = f.settings.blazingStage
            let skill = try #require(c.skills[SkillID(rawValue: f.skillID)])
            let result = try BattleCore.damage(attacker: attacker, defender: defender, skill: skill, settings: settings, content: c)
            #expect(result.displayPower == f.displayPower)
            #expect(result.singleHit == f.singleHit && result.total == f.total)
            #expect(result.defenderHP == f.defenderHP)
            #expect(result.typeMultiplier == f.typeMultiplier && result.stabMultiplier == f.stabMultiplier)
            let type = try #require(skill.typeId)
            #expect(try BattleCore.oneHitPower(attacker: attacker, defender: defender, type: type, category: skill.category, content: c) == f.oneHit)
        }
        for f in fixture.speeds {
            #expect(f.ball.speed(321, petID: 3400) == f.speed)
            #expect(f.ball.speed(321, petID: 3001) == 321)
        }
        for f in fixture.threatCases {
            let attacker = try #require(c.pets[PetID(rawValue: f.pet_id)])
            let defender = try #require(c.pets[PetID(rawValue: 3004)])
            let analysis = try TeamDefense.analyze(attacker: attacker, candidates: [defender, defender], content: c)
            #expect(analysis.weakCount == f.weak_count && analysis.neutralCount == f.neutral_count && analysis.resistCount == f.resist_count)
            #expect(analysis.hasSafeSwitch == f.has_safe_switch && analysis.pierceRisk == f.pierce_risk)
            #expect(abs(analysis.score - f.score) < 0.0000001)
            #expect(analysis.slots.map(\.index) == [0, 1])
        }
        for f in fixture.switchCases {
            let attacker = try #require(c.pets[PetID(rawValue: f.attackerID)])
            let defender = try #require(c.pets[PetID(rawValue: f.defenderID)])
            #expect(try BattleCore.switchMultipliers(attacker: attacker, candidates: [defender], content: c).first?.1 == f.multiplier)
        }
    }
    @Test func unresolvedAndNonAttackFail() throws {
        let c = try content()
        let skill = try #require(c.skills.values.first { $0.category == .status })
        #expect(throws: ContentError.self) { try BattleCore.damage(attacker: BattleProfile(), defender: BattleProfile(), skill: skill, content: c) }
        #expect(throws: ContentError.self) { try BattleCore.stats(BattleProfile(), content: c) }
    }
}
