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
        let catalogIDs = index.search("", type: nil, category: nil)
        let names = catalogIDs.compactMap { content.skill($0)?.nameZh }
        #expect(Set(names).count == names.count)
        #expect(index.entries.map(\.id) == catalogIDs)
        #expect(catalogIDs.allSatisfy {
            content.skill($0)?.isBattleEquipmentGranted == true || index.sameNameFamilyCount[$0, default: 0] > 0
        })
        let skill = try #require(content.skills.values.first { !$0.description.isEmpty && $0.typeId != nil && !$0.isBattleEquipmentGranted && index.sameNameFamilyCount[$0.skillId, default: 0] > 0 })
        let representative = try #require(index.sameNameSkillIDs[skill.skillId]?.first)
        #expect(index.search(skill.nameZh, type: skill.typeId, category: skill.category).contains(representative))
        #expect(index.search(String(skill.skillId.rawValue), type: nil, category: nil).contains(representative))
        #expect(index.search(skill.description, type: nil, category: nil).contains(representative))
        for (id, relations) in index.directBySkill {
            #expect(relations.allSatisfy { $0.skillId == id && content.petSkills(for: $0.petId).contains($0) })
        }
        for (id, families) in index.familiesBySkill {
            #expect(families.allSatisfy { $0.kind == .skillTerminal && $0.memberPetIds.contains { content.petSkills(for: $0).contains { $0.skillId == id } } })
        }
    }

    @Test func catalogCountsAndSourceIndexesMatchQueries() throws {
        let content = try content()
        let index = SkillSearchIndex(content: content)
        let query = SkillAcquisitionQuery(scope: .sameName)
        for skill in content.skills.values where skill.skillId.rawValue < 30 || [7020780, 7020720, 7700001].contains(skill.skillId.rawValue) {
            #expect(index.sameNameFamilyCount[skill.skillId] == query.results(skill: skill.skillId, index: index, content: content).count)
        }
        for (id, sources) in index.directBySkillAndSource {
            for (source, rows) in sources {
                #expect(rows == index.directBySkill[id]?.filter { $0.source == source })
                #expect(Set(rows.map(\.id)).count == rows.count)
            }
        }
        for (pet, sources) in content.petSkillsByPetAndSource {
            for (source, rows) in sources {
                #expect(rows == content.petSkillsByPet[pet]?.filter { $0.source == source })
            }
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

    @Test func equipmentSkillCatalogAndUnimplementedVisibility() throws {
        let content = try content()
        let index = SkillSearchIndex(content: content)
        let wish = SkillID(rawValue: 2)
        #expect(index.search("愿力冲击", type: nil, category: nil) == [wish])
        #expect(index.search("7700001", type: nil, category: nil) == [wish])
        #expect(index.search("愿力冲击", type: nil, category: .physicalAttack) == [wish])
        #expect(index.search("愿力冲击", type: nil, category: .magicAttack) == [wish])
        #expect(index.search("愿力冲击", type: nil, category: .status).isEmpty)
        #expect(content.skill(wish)?.acquisitionDescription == "战斗中装备愿力冲击后，可赋予任意精灵。")
        #expect(index.search("聚能", type: nil, category: nil).isEmpty)
        #expect(index.search("1", type: nil, category: nil).allSatisfy { $0.rawValue != 1 })
    }

    @Test func skillWithoutAcquisitionStaysEmpty() throws {
        let content = try content()
        let index = SkillSearchIndex(content: content)
        #expect(SkillAcquisitionQuery(scope: .sameName).results(skill: SkillID(rawValue: 1), index: index, content: content).isEmpty)
        #expect(SkillAcquisitionQuery(scope: .sameName).results(skill: SkillID(rawValue: -1), index: index, content: content).isEmpty)
    }
}
