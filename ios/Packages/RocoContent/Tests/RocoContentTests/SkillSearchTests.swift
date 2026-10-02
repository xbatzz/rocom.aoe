import Foundation
import Testing
import RocoDomain
@testable import RocoContent

struct SkillSearchTests {
    @Test func canonicalSearchAndRelations() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bundle = try #require(Bundle(url: root.appendingPathComponent("build/ios-content/store/ContentResources.bundle")))
        let content = try ContentStore.load(bundle: bundle)
        let index = SkillSearchIndex(content: content)
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
}
