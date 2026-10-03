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
    @State private var page = 1
    @State private var error: String?
    private var obtained: Set<String> { Set(records.filter(\.obtained).map(\.familyID)) }
    private func visible(saved: Set<String>) -> [Family] {
        index.badgeFamilies.filter {
            index.matches($0, query: query, content: content)
                && (filter == 0 || saved.contains($0.familyKey.rawValue) == (filter == 1))
        }
    }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        let obtained = obtained
        let visible = visible(saved: obtained)
        let window = CatalogPage(totalCount: visible.count, requestedPage: page)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CollectionProgress(title: "家族已获得", count: index.badgeFamilies.filter { obtained.contains($0.familyKey.rawValue) }.count,
                    total: index.badgeFamilies.count, tint: .orange)
                Picker("状态", selection: $filter) {
                    Text("全部").tag(0); Text("已获得").tag(1); Text("未获得").tag(2)
                }.pickerStyle(.segmented)
                CompanionHeading(title: "家族收藏", detail: "\(visible.count) 个家族")
                if visible.isEmpty { ContentUnavailableView("没有符合条件的家族", systemImage: "medal", description: Text("尝试其他关键词或获得状态。")) }
                CatalogPagination(window: window, page: $page).id("catalog-results-top")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 150), spacing: 12)], spacing: 12) {
                    ForEach(visible[window.range], id: \.familyKey) { family in
                        if let pet = content.pets[family.representativePetId] {
                            Button {
                                do { try UserDatabase.toggleHero(family.familyKey.rawValue, context: context) }
                                catch { self.error = String(describing: error) }
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 88).frame(maxWidth: .infinity)
                                    Text(pet.nameZh).font(.headline).fixedSize(horizontal: false, vertical: true)
                                    PetTypes(pet: pet, content: content)
                                    Text("\(family.memberPetIds.count) 个家族成员").font(.caption).foregroundStyle(.secondary)
                                    CollectionStatus(selected: obtained.contains(family.familyKey.rawValue), selectedTitle: "已获得", idleTitle: "未获得", tint: .orange)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(16).companionSurface()
                            }.buttonStyle(.plain).accessibilityLabel("\(pet.nameZh)，\(obtained.contains(family.familyKey.rawValue) ? "已获得" : "未获得")，切换状态")
                        }
                    }
                }
                if window.pageCount > 1 { CatalogPagination(window: window, page: $page) }
            }.padding(20)
        }.catalogPagination(page: $page, totalCount: visible.count, resetKey: [query, filter])
            .reviewScrollPosition().companionBackground().navigationTitle("命定勇者").searchable(text: $query, prompt: "家族任一成员名称或 ID")
            .alert("保存失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
}
