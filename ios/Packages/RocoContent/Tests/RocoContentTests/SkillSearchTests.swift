import Foundation
import Testing
import RocoDomain
@testable import RocoContent

struct SkillSearchTests {
    private func content() throws -> ContentStore {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bundle = try #require(Bundle(url: root.appendingPathComponent("build/ios-content/store/ContentResources.bundle")))
        return try ContentStore.load(bundle: bundle)
    }

    @Test func canonicalSearchAndRelations() throws {
        let content = try content()
        let index = SkillSearchIndex(content: content)
        let control = try #require(content.skill(SkillID(rawValue: 3)))
        let petControl = try #require(content.skill(SkillID(rawValue: 7020720)))
        #expect(control.iconAssetId == nil)
        #expect(content.skillIcon(for: control) == petControl.iconAssetId)
        #expect(content.skillIcon(for: control) != nil)
        let wish = try #require(content.skill(SkillID(rawValue: 2)))
        let firstWish = try #require(content.skill(SkillID(rawValue: 7700001)))
        #expect(content.skillIcon(for: wish) == firstWish.iconAssetId)
        for skill in content.skills.values where skill.iconAssetId != nil {
            #expect(content.skillIcon(for: skill) == skill.iconAssetId)
        }
        let charge = try #require(content.skill(SkillID(rawValue: 1)))
        #expect(content.skillIcon(for: charge) == nil)
        #expect(index.entries.count == content.skills.count)
        #expect(index.search("", type: nil, category: nil).map(\.rawValue) == content.skills.keys.map(\.rawValue).sorted())
        let skill = try #require(content.skills.values.first { !$0.description.isEmpty && $0.typeId != nil })
        #expect(index.search(skill.nameZh, type: skill.typeId, category: skill.category).contains(skill.skillId))
        #expect(index.search(String(skill.skillId.rawValue), type: nil, category: nil).contains(skill.skillId))
        #expect(index.search(skill.description, type: nil, category: nil).contains(skill.skillId))
        for (id, relations) in index.directBySkill {
            #expect(relations.allSatisfy { $0.skillId == id && content.petSkills(for: $0.petId).contains($0) })
        }
        for (id, families) in index.familiesBySkill {
            #expect(families.allSatisfy { $0.kind == .skillTerminal && $0.memberPetIds.contains { content.petSkills(for: $0).contains { $0.skillId == id } } })
        }
    }

    @Test(arguments: [2, 3, 14, 16])
    func catalogAcquisitionIncludesSameNameConfigurations(rawID: Int) throws {
        let content = try content()
        let index = SkillSearchIndex(content: content)
        let id = SkillID(rawValue: rawID)
        let skill = try #require(content.skill(id))
        let ids = try #require(index.sameNameSkillIDs[id])
        #expect(ids.contains(id))
        #expect(ids.count > 1)
        #expect(ids.allSatisfy { content.skill($0)?.nameZh == skill.nameZh })
        #expect(SkillAcquisitionQuery().results(skill: id, index: index, content: content).isEmpty)
        let catalogRows = SkillAcquisitionQuery(scope: .sameName).results(skill: id, index: index, content: content)
        #expect(!catalogRows.isEmpty)
        #expect(catalogRows.allSatisfy { $0.acquired.allSatisfy { $0.skillId != id && ids.contains($0.skillId) } })

        for highest in [true, false] {
            for source: PetSkillSource? in [nil, .pool, .stone, .bloodline] {
                for implementation in PetQuery.Implementation.allCases {
                    var query = SkillAcquisitionQuery(scope: .sameName)
                    query.highest = highest
                    query.source = source
                    query.implementation = implementation
                    let rows = query.results(skill: id, index: index, content: content)
                    var exact = SkillAcquisitionQuery()
                    exact.highest = highest
                    exact.source = source
                    exact.implementation = implementation
                    let expected = ids.flatMap { exact.results(skill: $0, index: index, content: content) }
                    #expect(Set(rows.map(\.key)) == Set(expected.map(\.key)))
                    #expect(Set(rows.map(\.key)).count == rows.count)
                    for row in rows {
                        let relations = expected.filter { $0.key == row.key }.flatMap(\.acquired)
                        #expect(row.acquired.count == relations.count)
                        #expect(row.acquired.allSatisfy { relations.contains($0) })
                    }
                }
            }
        }
    }

    @Test func skillWithoutAcquisitionStaysEmpty() throws {
        let content = try content()
        let index = SkillSearchIndex(content: content)
        #expect(SkillAcquisitionQuery(scope: .sameName).results(skill: SkillID(rawValue: 1), index: index, content: content).isEmpty)
        #expect(SkillAcquisitionQuery(scope: .sameName).results(skill: SkillID(rawValue: -1), index: index, content: content).isEmpty)
    }
}
