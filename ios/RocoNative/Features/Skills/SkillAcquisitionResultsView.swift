import SwiftUI
import RocoContent
import RocoDomain

struct SkillAcquisitionResultsView: View {
    let skill: SkillID
    let content: ContentStore
    let portraits: PortraitStore
    let index: SkillSearchIndex
    @Binding var query: SkillAcquisitionQuery
    var body: some View {
        let rows = query.results(skill: skill, index: index, content: content)
        CompanionSection("可获得精灵 · \(rows.count) \(query.highest ? "个家族" : "个形态")") {
            DisclosureGroup("筛选获得关系") {
                TextField("成员名称、图鉴编号或配置 ID", text: $query.keyword)
                Picker("来源", selection: $query.source) {
                    Text("全部").tag(nil as PetSkillSource?)
                    ForEach([PetSkillSource.pool, .stone, .bloodline], id: \.self) { Text(sourceName($0)).tag(Optional($0)) }
                }
                Picker("属性", selection: $query.type) {
                    Text("全部").tag(nil as TypeID?)
                    ForEach(TypeMatchup(types: content.types).selectable, id: \.typeId) { Text($0.nameZh).tag(Optional($0.typeId)) }
                }
                Picker("实装", selection: $query.implementation) {
                    ForEach(PetQuery.Implementation.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Toggle("家族最高形态", isOn: $query.highest)
                Button("重置") { query = SkillAcquisitionQuery() }
            }.tint(.primary)
            if rows.isEmpty { Text("没有符合条件的获得关系").foregroundStyle(.secondary) }
            ForEach(rows, id: \.key) { row in
                VStack(alignment: .leading, spacing: 10) {
                    petLink(row.representative)
                    DisclosureGroup("实际获得成员 · \(Set(row.acquired.map(\.petId)).count)") {
                        ForEach(Array(row.acquired.enumerated()), id: \.offset) { _, relation in
                            if let pet = content.pets[relation.petId] {
                                VStack(alignment: .leading, spacing: 4) {
                                    petLink(pet)
                                    Text(sourceName(relation.source) + (relation.legacyTypeId.flatMap { content.types[$0]?.nameZh }.map { " · 需\($0)血脉" } ?? ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                }.padding(.vertical, 6)
                            }
                        }
                    }.tint(.primary)
                }.padding(.vertical, 10)
                Divider()
            }
        }
    }
    private func petLink(_ pet: Pet) -> some View {
        NavigationLink { ExistingPetDestination(pet: pet, content: content, portraits: portraits) } label: {
            HStack(spacing: 12) {
                CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 48)
                VStack(alignment: .leading) {
                    Text(pet.nameZh).font(.headline)
                    Text("#\(String(pet.handbookId?.rawValue ?? pet.speciesId.rawValue)) · \(pet.form == "default" ? "默认形态" : pet.form) · 配置 \(String(pet.petId.rawValue))").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.buttonStyle(.plain)
    }
}
