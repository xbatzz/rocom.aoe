import SwiftUI
import RocoContent
import RocoDomain

struct AdvancedPetFilterView: View {
    let content: ContentStore
    let portraits: PortraitStore
    @State private var query = PetQuery()
    @State private var skillSearch = ""
    @State private var page = 1
    var body: some View {
        let pets = query.results(content: content)
        let window = CatalogPage(totalCount: pets.count, requestedPage: page)
        List {
            Section("组合筛选") {
                TextField("精灵名称、图鉴编号或配置 ID", text: $query.keyword)
                Picker("属性", selection: $query.type) {
                    Text("全部").tag(nil as TypeID?)
                    ForEach(TypeMatchup(types: content.types).selectable, id: \.typeId) { Text($0.nameZh).tag(Optional($0.typeId)) }
                }
                DisclosureGroup("指定技能") {
                    TextField("搜索技能名称或 ID", text: $skillSearch)
                    Picker("技能", selection: $query.skill) {
                        Text("任意").tag(nil as SkillID?)
                        ForEach(content.skills.values.filter { $0.skillId == query.skill || skillSearch.isEmpty || "\($0.nameZh) \($0.skillId.rawValue)".localizedStandardContains(skillSearch) }.sorted { $0.skillId.rawValue < $1.skillId.rawValue }, id: \.skillId) {
                            Text("\($0.nameZh) #\($0.skillId.rawValue)").tag(Optional($0.skillId))
                        }
                    }
                }
                Picker("技能来源", selection: $query.source) {
                    Text("全部").tag(nil as PetSkillSource?)
                    ForEach([PetSkillSource.pool, .stone, .bloodline], id: \.self) { Text(sourceName($0)).tag(Optional($0)) }
                }
                Picker("攻击倾向", selection: $query.style) {
                    Text("全部").tag(nil as PetAttackStyle?)
                    Text("物理").tag(Optional(PetAttackStyle.physical)); Text("魔法").tag(Optional(PetAttackStyle.magic))
                    Text("双攻").tag(Optional(PetAttackStyle.both)); Text("未分类").tag(Optional(PetAttackStyle.unknown))
                }
                Picker("阶段", selection: $query.stage) { ForEach(PetQuery.Stage.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Picker("实装", selection: $query.implementation) { ForEach(PetQuery.Implementation.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Picker("排序", selection: $query.sort) { ForEach(PetQuery.Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Toggle("降序", isOn: $query.descending)
                Button("重置全部条件") { query = PetQuery(); skillSearch = "" }
            }
            Section("结果 · \(pets.count) 个配置") {
                CatalogPagination(window: window, page: $page).id("catalog-results-top")
                ForEach(pets[window.range], id: \.petId) { pet in
                    NavigationLink { ExistingPetDestination(pet: pet, content: content, portraits: portraits) } label: {
                        HStack {
                            CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 48)
                            VStack(alignment: .leading) {
                                Text(pet.nameZh).font(.headline)
                                Text("#\(String(pet.handbookId?.rawValue ?? pet.speciesId.rawValue)) · \(pet.form) · \(pet.implemented ? "已实装" : "未实装")").font(.caption).foregroundStyle(.secondary)
                                Text("总种族值 \(pet.baseStats.hp + pet.baseStats.physicalAttack + pet.baseStats.magicalAttack + pet.baseStats.physicalDefense + pet.baseStats.magicalDefense + pet.baseStats.speed)").font(.caption)
                            }
                        }
                    }
                }
                if window.pageCount > 1 { CatalogPagination(window: window, page: $page) }
                if pets.isEmpty { Text("没有符合条件的精灵").foregroundStyle(.secondary) }
            }
        }.catalogPagination(page: $page, totalCount: pets.count, resetKey: [query.keyword, query.type as AnyHashable, query.skill as AnyHashable, query.source as AnyHashable, query.style as AnyHashable, query.stage, query.implementation, query.sort, query.descending])
            .navigationTitle("高级筛选")
    }
}
