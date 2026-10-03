import SwiftUI
import SwiftData
import RocoContent
import RocoDomain
import RocoUserData

struct ShinyCollectionView: View {
    let content: ContentStore
    let index: TrackingCatalogIndex
    @Query private var records: [ShinyRecord]
    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var season: SeasonID?
    @State private var filter = 0
    @State private var page = 1
    @State private var error: String?
    @State private var undo: (id: String, old: Bool)?
    init(content: ContentStore, index: TrackingCatalogIndex) {
        self.content = content; self.index = index; _season = State(initialValue: content.manifest.defaultSeason)
    }

    private var collected: Set<String> { Set(records.filter(\.collected).map(\.slotID)) }
    private var seasonalSlots: [ShinySlot] {
        let slots = season.map { content.shinySlotsBySeason[$0] ?? [] } ?? Array(content.shinySlots.values)
        return slots.sorted { ($0.seasonId.rawValue, $0.slotId.rawValue) < ($1.seasonId.rawValue, $1.slotId.rawValue) }
    }
    private func visible(slots: [ShinySlot], saved: Set<String>) -> [ShinySlot] {
        slots.filter {
            index.matches($0, query: query, content: content)
                && (filter == 0 || saved.contains($0.slotId.rawValue) == (filter == 1))
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        let collected = collected
        let seasonalSlots = seasonalSlots
        let visible = visible(slots: seasonalSlots, saved: collected).sorted {
            ($0.familyId.rawValue, $0.seasonId.rawValue, $0.slotId.rawValue) < ($1.familyId.rawValue, $1.seasonId.rawValue, $1.slotId.rawValue)
        }
        let window = CatalogPage(totalCount: visible.count, requestedPage: page)
        let pageSlots = visible[window.range]
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DisclosureGroup("各赛季进度") {
                    ForEach(content.seasons.values.sorted { $0.seasonId.rawValue < $1.seasonId.rawValue }, id: \.seasonId) { season in
                        let slots = content.shinySlotsBySeason[season.seasonId] ?? []
                        CollectionProgress(title: season.nameZh, count: slots.filter { collected.contains($0.slotId.rawValue) }.count, total: slots.count, tint: .purple)
                    }
                }.tint(.primary)
                if let undo {
                    Button("撤销上次切换", systemImage: "arrow.uturn.backward") {
                        do { try UserDatabase.setShiny(undo.old, slot: undo.id, context: context); self.undo = nil }
                        catch { self.error = String(describing: error) }
                    }.buttonStyle(.bordered)
                }
                CollectionProgress(title: "异色收集", count: seasonalSlots.filter { collected.contains($0.slotId.rawValue) }.count,
                    total: seasonalSlots.count, tint: .purple)
                VStack(alignment: .leading, spacing: 8) {
                    Menu {
                        Picker("赛季", selection: $season) {
                            Text("全部赛季").tag(nil as SeasonID?)
                            ForEach(content.seasons.values.sorted { $0.seasonId.rawValue < $1.seasonId.rawValue }, id: \.seasonId) { Text($0.nameZh).tag(Optional($0.seasonId)) }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(season.flatMap { content.seasons[$0]?.nameZh } ?? "全部赛季").font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                        }.frame(minHeight: 44)
                    }.tint(.primary).accessibilityIdentifier("shiny-season")
                    Text("\(visible.count) 个异色槽").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Picker("收集状态", selection: $filter) {
                    Text("全部").tag(0); Text("已收集").tag(1); Text("未收集").tag(2)
                }.pickerStyle(.segmented)
                if visible.isEmpty { ContentUnavailableView("没有符合条件的异色槽", systemImage: "star", description: Text("尝试其他关键词、赛季或收集状态。")) }
                CatalogPagination(window: window, page: $page).id("catalog-results-top")
                let keys = Set(pageSlots.map(\.familyId)).sorted { $0.rawValue < $1.rawValue }
                ForEach(keys, id: \.self) { family in
                    let familySlots = seasonalSlots.filter { $0.familyId == family }
                    let shown = pageSlots.filter { $0.familyId == family }
                    CompanionHeading(title: familySlots.first.flatMap { content.pets[$0.representativePetId]?.nameZh } ?? "家族 #\(family.rawValue)", detail: "\(familySlots.filter { collected.contains($0.slotId.rawValue) }.count) / \(familySlots.count) 已收集")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 150), spacing: 12)], spacing: 12) {
                        ForEach(shown, id: \.slotId) { slot in
                            ShinySlotRow(slot: slot, content: content, isCollected: collected.contains(slot.slotId.rawValue)) {
                                do {
                                    let old = collected.contains(slot.slotId.rawValue)
                                    try UserDatabase.toggleShiny(slot.slotId.rawValue, context: context); undo = (slot.slotId.rawValue, old)
                                } catch { self.error = String(describing: error) }
                            }
                        }
                    }
                }
                if window.pageCount > 1 { CatalogPagination(window: window, page: $page) }
            }.padding(20)
        }.catalogPagination(page: $page, totalCount: visible.count, resetKey: [query, season as AnyHashable, filter])
            .reviewScrollPosition().companionBackground().navigationTitle("异色收集")
            .searchable(text: $query, prompt: "任一成员名称或 ID")
            .alert("保存失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
}

private struct ShinySlotRow: View {
    let slot: ShinySlot
    let content: ContentStore
    let isCollected: Bool
    let toggle: () -> Void
    var body: some View {
        if let pet = content.pets[slot.targetPetId] {
            Button(action: toggle) {
                VStack(alignment: .leading, spacing: 10) {
                    CanonicalThumbnail(assetID: slot.portraitAssetId, content: content, size: 96).frame(maxWidth: .infinity)
                    Text(pet.nameZh).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text("\(pet.form == "default" ? "默认形态" : pet.form) · 路线 \(slot.slotId.rawValue)").font(.caption).foregroundStyle(.secondary)
                    Text(slot.memberPetIds.compactMap { content.pets[$0]?.nameZh }.joined(separator: " → ")).font(.caption).foregroundStyle(.secondary)
                    PetTypes(pet: pet, content: content)
                    if let season = content.seasons[slot.seasonId] {
                        Text(season.nameZh).font(.caption).foregroundStyle(.secondary)
                    }
                    CollectionStatus(selected: isCollected, tint: .purple)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16).companionSurface()
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(isCollected ? Color.purple.opacity(0.5) : .clear, lineWidth: 1.5))
            }.buttonStyle(.plain).accessibilityLabel("\(pet.nameZh)，\(isCollected ? "已收集" : "未收集")，切换状态")
        }
    }
}
