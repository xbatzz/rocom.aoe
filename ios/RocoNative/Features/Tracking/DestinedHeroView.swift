import SwiftUI
import SwiftData
import RocoContent
import RocoUserData

struct DestinedHeroView: View {
    let content: ContentStore
    let index: TrackingCatalogIndex
    @Query private var records: [HeroRecord]
    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var filter = 0
    @State private var error: String?
    private var obtained: Set<String> { Set(records.filter(\.obtained).map(\.familyID)) }
    private var visible: [Family] {
        let saved = obtained
        return index.badgeFamilies.filter {
            (query.isEmpty || index.familySearch[$0.familyKey]?.localizedStandardContains(query) == true)
                && (filter == 0 || saved.contains($0.familyKey.rawValue) == (filter == 1))
        }
    }
    var body: some View {
        List {
            Section {
                Picker("状态", selection: $filter) {
                    Text("全部").tag(0); Text("已获得").tag(1); Text("未获得").tag(2)
                }
                LabeledContent("已获得", value: "\(index.badgeFamilies.filter { obtained.contains($0.familyKey.rawValue) }.count) / \(index.badgeFamilies.count)")
            }
            Section("\(visible.count) 个家族") {
                ForEach(visible, id: \.familyKey) { family in
                    if let pet = content.pets[family.representativePetId] {
                        Button {
                            do { try UserDatabase.toggleHero(family.familyKey.rawValue, context: context) }
                            catch { self.error = String(describing: error) }
                        } label: {
                            HStack {
                                Text(pet.nameZh)
                                Spacer()
                                Text(obtained.contains(family.familyKey.rawValue) ? "已获得" : "未获得").foregroundStyle(.secondary)
                                Image(systemName: obtained.contains(family.familyKey.rawValue) ? "medal.fill" : "medal")
                            }
                        }
                    }
                }
            }
        }.navigationTitle("命定勇者").searchable(text: $query, prompt: "家族任一成员名称或 ID")
            .alert("保存失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
}
