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
    @State private var error: String?

    private var collected: Set<String> { Set(records.filter(\.collected).map(\.slotID)) }
    private var seasonalSlots: [ShinySlot] {
        let slots = season.map { content.shinySlotsBySeason[$0] ?? [] } ?? Array(content.shinySlots.values)
        return slots.sorted { ($0.seasonId.rawValue, $0.slotId.rawValue) < ($1.seasonId.rawValue, $1.slotId.rawValue) }
    }
    private func visible(slots: [ShinySlot], saved: Set<String>) -> [ShinySlot] {
        slots.filter {
            (query.isEmpty || index.slotSearch[$0.slotId]?.localizedStandardContains(query) == true)
                && (filter == 0 || saved.contains($0.slotId.rawValue) == (filter == 1))
        }
    }

    var body: some View {
        let collected = collected
        let seasonalSlots = seasonalSlots
        let visible = visible(slots: seasonalSlots, saved: collected)
        List {
            Section {
                Picker("赛季", selection: $season) {
                    Text("全部").tag(nil as SeasonID?)
                    ForEach(content.seasons.values.sorted { $0.seasonId.rawValue < $1.seasonId.rawValue }, id: \.seasonId) {
                        Text($0.nameZh).tag(Optional($0.seasonId))
                    }
                }
                Picker("收集状态", selection: $filter) {
                    Text("全部").tag(0); Text("已收集").tag(1); Text("未收集").tag(2)
                }
                LabeledContent("本赛季范围", value: "\(seasonalSlots.filter { collected.contains($0.slotId.rawValue) }.count) / \(seasonalSlots.count)")
            }
            Section("\(visible.count) 个异色槽") {
                ForEach(visible, id: \.slotId) { slot in
                    ShinySlotRow(slot: slot, content: content, isCollected: collected.contains(slot.slotId.rawValue)) {
                        do { try UserDatabase.toggleShiny(slot.slotId.rawValue, context: context) }
                        catch { self.error = String(describing: error) }
                    }
                }
            }
        }.navigationTitle("异色收集")
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
        if let pet = content.pets[slot.representativePetId] {
            Button(action: toggle) {
                HStack {
                    CanonicalThumbnail(assetID: slot.portraitAssetId, content: content)
                    VStack(alignment: .leading) {
                        Text(pet.nameZh)
                        if let season = content.seasons[slot.seasonId] {
                            Text(season.nameZh).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: isCollected ? "checkmark.circle.fill" : "circle")
                }
            }.accessibilityLabel("\(pet.nameZh)，\(isCollected ? "已收集" : "未收集")，切换状态")
        }
    }
}
