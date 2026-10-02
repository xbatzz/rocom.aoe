import SwiftUI
import RocoContent
import RocoDomain

private let skillCategories: [SkillCategory] = [.physicalAttack, .magicAttack, .status, .defense, .unknown]
private func categoryName(_ category: SkillCategory) -> String {
    switch category {
    case .physicalAttack: "物理攻击"
    case .magicAttack: "魔法攻击"
    case .status: "变化"
    case .defense: "防御"
    case .unknown: "未分类"
    }
}
private func sourceName(_ source: PetSkillSource) -> String {
    switch source {
    case .pool: "技能池"
    case .stone: "技能石"
    case .bloodline: "血脉技能"
    }
}

struct SkillsView: View {
    let content: ContentStore
    let portraits: PortraitStore
    let index: SkillSearchIndex
    @State private var query = ""
    @State private var type: TypeID?
    @State private var category: SkillCategory?

    var body: some View {
        List {
            Section("筛选") {
                Picker("属性", selection: $type) {
                    Text("全部").tag(nil as TypeID?)
                    ForEach(content.types.values.sorted { $0.typeId.rawValue < $1.typeId.rawValue }, id: \.typeId) {
                        Text($0.nameZh).tag(Optional($0.typeId))
                    }
                }
                Picker("类别", selection: $category) {
                    Text("全部").tag(nil as SkillCategory?)
                    ForEach(skillCategories, id: \.rawValue) { Text(categoryName($0)).tag(Optional($0)) }
                }
            }
            let ids = index.search(query, type: type, category: category)
            Section("\(ids.count) 个技能 · ID 排序") {
                ForEach(ids, id: \.self) { id in
                    if let skill = content.skills[id] {
                        NavigationLink {
                            SkillDetailView(skill: skill, content: content, portraits: portraits, index: index)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(skill.nameZh)
                                Text("#\(id.rawValue) · \(categoryName(skill.category))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }.searchable(text: $query, prompt: "中文名、ID 或描述")
            .navigationTitle("技能查询")
    }
}

struct SkillDetailView: View {
    let skill: Skill
    let content: ContentStore
    let portraits: PortraitStore
    let index: SkillSearchIndex

    var body: some View {
        List {
            Section("技能") {
                LabeledContent("名称", value: skill.nameZh)
                LabeledContent("ID", value: String(skill.skillId.rawValue))
                if let id = skill.typeId, let type = content.types[id] { LabeledContent("属性", value: type.nameZh) }
                LabeledContent("类别", value: categoryName(skill.category))
                if let power = skill.power { LabeledContent("威力", value: power.formatted()) }
                if let cost = skill.energyCost { LabeledContent("能耗", value: cost.formatted()) }
                if !skill.description.isEmpty { Text(skill.description) }
            }
            if let group = index.groupsBySkill[skill.skillId] {
                Section("同名技能组") {
                    Text("展示 ID：\(group.displayId.rawValue)")
                    Text("别名 ID：\(group.aliasIds.map { String($0.rawValue) }.joined(separator: "、"))")
                    Text("以下关系仅对应当前技能配置 ID。").font(.footnote).foregroundStyle(.secondary)
                }
            }
            ForEach([PetSkillSource.pool, .stone, .bloodline], id: \.rawValue) { source in
                let relations = (index.directBySkill[skill.skillId] ?? []).filter { $0.source == source }
                if !relations.isEmpty {
                    Section("直接配置 · \(sourceName(source))") {
                        ForEach(relations.indices, id: \.self) { i in
                            if let pet = content.pets[relations[i].petId] {
                                petLink(pet)
                                if let legacy = relations[i].legacyTypeId, let type = content.types[legacy] {
                                    Text("血脉条件：\(type.nameZh)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            let families = index.familiesBySkill[skill.skillId] ?? []
            if !families.isEmpty {
                Section("家族聚合能力") {
                    Text("某成员有该技能，不表示代表形态直接会。直接关系请查看上方来源。").font(.footnote).foregroundStyle(.secondary)
                    ForEach(families, id: \.familyKey) { family in
                        if let pet = content.pets[family.representativePetId] { petLink(pet) }
                    }
                }
            }
        }.navigationTitle(skill.nameZh)
    }
    private func petLink(_ pet: Pet) -> some View {
        NavigationLink(pet.nameZh) { ExistingPetDestination(pet: pet, content: content, portraits: portraits) }
    }
}

/// Reuses the existing detail; lazy decode only when a specific pet is opened.
struct ExistingPetDestination: View {
    let pet: Pet
    let content: ContentStore
    let portraits: PortraitStore
    @State private var result: Result<UIImage, Error>?
    var body: some View {
        Group {
            switch result {
            case .success(let image): PetDetail(pet: pet, content: content, image: image, portraits: portraits)
            case .failure(let error): ContentUnavailableView("图片未能加载", systemImage: "photo", description: Text(String(describing: error)))
            case nil: ProgressView()
            }
        }.task { result = Result { try portraits.image(for: pet) } }
    }
}
