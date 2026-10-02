import SwiftUI
import SwiftData
import RocoContent
import RocoDomain
import RocoUserData

struct GrassBadgeView: View {
    let content: ContentStore
    let index: TrackingCatalogIndex
    @Query private var records: [GrassRecord]
    @State private var query = ""
    @State private var location: BadgeLocationLocationId = .somia
    @State private var state: BadgeState?

    private var statuses: [String: BadgeState] {
        Dictionary(uniqueKeysWithValues: records.filter { $0.locationID == location.rawValue }.map { ($0.footprintID, $0.status) })
    }
    private func visible(statuses: [String: BadgeState]) -> [Family] {
        index.badgeFamilies.filter { family in
            let footprints = index.footprintsByFamily[family.familyKey] ?? []
            let matchesSearch = query.isEmpty || index.familySearch[family.familyKey]?.localizedStandardContains(query) == true
                || footprints.contains { content.pets[$0.petId]?.nameZh.localizedStandardContains(query) == true }
            let matchesState = state == nil || footprints.contains { (statuses[$0.footprintKey.rawValue] ?? .unrecorded) == state }
            return matchesSearch && matchesState
        }
    }
    private func counts(statuses: [String: BadgeState]) -> [BadgeState: Int] {
        var result: [BadgeState: Int] = [:]
        for footprint in content.badgeFootprints.values { result[statuses[footprint.footprintKey.rawValue] ?? .unrecorded, default: 0] += 1 }
        return result
    }
    var body: some View {
        let statuses = statuses
        let visible = visible(statuses: statuses)
        let counts = counts(statuses: statuses)
        List {
            Section("地点记录相互独立") {
                locationPicker
                Picker("状态", selection: $state) {
                    Text("全部").tag(nil as BadgeState?)
                    ForEach(BadgeState.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                }
                ForEach(BadgeState.allCases, id: \.self) { LabeledContent($0.label, value: String(counts[$0, default: 0])) }
                if let target = content.badgeLocations[location] { LabeledContent("地点目标", value: String(target.targetCount)) }
            }
            Section("\(visible.count) 个家族") {
                if visible.isEmpty { ContentUnavailableView("没有符合条件的家族", systemImage: "leaf", description: Text("尝试其他关键词、地点或足迹状态。")) }
                ForEach(visible, id: \.familyKey) { family in
                    if let pet = content.pets[family.representativePetId] {
                        NavigationLink {
                            GrassFamilyView(family: family, content: content, index: index, location: location)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(pet.nameZh)
                                let footprints = index.footprintsByFamily[family.familyKey] ?? []
                                Text("\(footprints.filter { statuses[$0.footprintKey.rawValue] == .lit }.count) / \(footprints.count) 足迹点亮")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }.navigationTitle("草系徽章").searchable(text: $query, prompt: "家族成员名称或 ID")
    }
    private var locationPicker: some View {
        Picker("地点", selection: $location) {
            ForEach(content.badgeLocations.values.sorted { $0.locationId.rawValue < $1.locationId.rawValue }, id: \.locationId) {
                Text($0.nameZh).tag($0.locationId)
            }
        }
    }
}

private struct GrassFamilyView: View {
    let family: Family
    let content: ContentStore
    let index: TrackingCatalogIndex
    @State var location: BadgeLocationLocationId
    @Query private var records: [GrassRecord]
    @Environment(\.modelContext) private var context
    @State private var error: String?

    var body: some View {
        let statuses = Dictionary(uniqueKeysWithValues: records.filter { $0.locationID == location.rawValue }.map { ($0.footprintID, $0.status) })
        List {
            Picker("地点", selection: $location) {
                ForEach(content.badgeLocations.values.sorted { $0.locationId.rawValue < $1.locationId.rawValue }, id: \.locationId) {
                    Text($0.nameZh).tag($0.locationId)
                }
            }
            Section("点按循环：未记录 → 已点亮 → 未点亮") {
                ForEach(index.footprintsByFamily[family.familyKey] ?? [], id: \.footprintKey) { footprint in
                    if let pet = content.pets[footprint.petId] {
                        let status = statuses[footprint.footprintKey.rawValue] ?? .unrecorded
                        Button {
                            do { try UserDatabase.cycleGrass(footprint: footprint.footprintKey.rawValue, location: location.rawValue, context: context) }
                            catch { self.error = String(describing: error) }
                        } label: {
                            LabeledContent { Text(status.label) } label: {
                                VStack(alignment: .leading) {
                                    Text(pet.nameZh)
                                    Text("\(pet.form)\(footprint.isLeader ? " · 首领" : "") · #\(pet.petId.rawValue)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }.navigationTitle(content.pets[family.representativePetId]?.nameZh ?? family.familyKey.rawValue)
            .alert("保存失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
}
