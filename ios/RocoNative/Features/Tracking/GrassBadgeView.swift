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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    BadgeLocationPicker(content: content, selection: $location)
                    Text("地点独立记录").font(.caption).foregroundStyle(.secondary)
                }
                CollectionProgress(title: "当前地点目标", count: counts[.lit, default: 0],
                    total: content.badgeLocations[location]?.targetCount ?? 0, tint: .green)
                CompanionMetrics {
                    CompanionMetric(value: String(counts[.unrecorded, default: 0]), label: "未记录")
                    CompanionMetric(value: String(counts[.unlit, default: 0]), label: "未点亮")
                    CompanionMetric(value: String(visible.count), label: "筛选家族")
                }
                Picker("状态", selection: $state) {
                    Text("全部").tag(nil as BadgeState?)
                    ForEach(BadgeState.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                }.pickerStyle(.menu).tint(.primary)
                Text("地点目标不等于已知出没目录；点亮记录仅统计当前选择地点。").font(.footnote).foregroundStyle(.secondary)
                CompanionHeading(title: "家族足迹")
                if visible.isEmpty { ContentUnavailableView("没有符合条件的家族", systemImage: "leaf", description: Text("尝试其他关键词、地点或足迹状态。")) }
                LazyVStack(spacing: 0) {
                    ForEach(visible, id: \.familyKey) { family in
                        if let pet = content.pets[family.representativePetId] {
                            NavigationLink {
                                GrassFamilyView(family: family, content: content, index: index, location: location)
                            } label: {
                                HStack(spacing: 14) {
                                    CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 64)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(pet.nameZh).font(.headline)
                                        let footprints = index.footprintsByFamily[family.familyKey] ?? []
                                        let lit = footprints.filter { statuses[$0.footprintKey.rawValue] == .lit }.count
                                        Text("\(lit) / \(footprints.count) 足迹点亮").font(.caption.monospacedDigit()).foregroundStyle(lit > 0 ? .green : .secondary)
                                        ProgressView(value: Double(lit), total: Double(max(1, footprints.count))).tint(.green)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                                }.padding(.vertical, 14)
                            }.buttonStyle(.plain)
                            Divider().padding(.leading, 78)
                        }
                    }
                }
            }.padding(20)
        }.reviewScrollPosition().companionBackground().navigationTitle("草系徽章").searchable(text: $query, prompt: "家族成员名称或 ID")
    }

}

struct GrassFamilyView: View {
    let family: Family
    let content: ContentStore
    let index: TrackingCatalogIndex
    @State var location: BadgeLocationLocationId
    @Query private var records: [GrassRecord]
    @Environment(\.modelContext) private var context
    @State private var error: String?

    var body: some View {
        let statuses = Dictionary(uniqueKeysWithValues: records.filter { $0.locationID == location.rawValue }.map { ($0.footprintID, $0.status) })
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let pet = content.pets[family.representativePetId] {
                    HStack(spacing: 16) {
                        CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 88)
                        VStack(alignment: .leading, spacing: 10) {
                            Text(pet.nameZh).font(.title2.bold())
                            PetTypes(pet: pet, content: content)
                        }
                    }
                }
                BadgeLocationPicker(content: content, selection: $location)
                Text("点按足迹切换：未记录 → 已点亮 → 未点亮").font(.footnote).foregroundStyle(.secondary)
                ForEach(index.footprintsByFamily[family.familyKey] ?? [], id: \.footprintKey) { footprint in
                    if let pet = content.pets[footprint.petId] {
                        let status = statuses[footprint.footprintKey.rawValue] ?? .unrecorded
                        Button {
                            do { try UserDatabase.cycleGrass(footprint: footprint.footprintKey.rawValue, location: location.rawValue, context: context) }
                            catch { self.error = String(describing: error) }
                        } label: {
                            HStack(spacing: 12) {
                                CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 64)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(pet.nameZh).font(.headline)
                                        if footprint.isLeader, let image = GameIconCatalog.leader {
                                            Image(uiImage: image).resizable().scaledToFit().frame(width: 20, height: 20).accessibilityLabel("首领")
                                        }
                                    }
                                    Text("\(pet.form == "default" ? "默认形态" : pet.form) · #\(String(pet.petId.rawValue))")
                                        .font(.caption).foregroundStyle(.secondary)
                                    CollectionStatus(selected: status == .lit, selectedTitle: "已点亮", idleTitle: status.label)
                                }
                                Spacer(minLength: 0)
                            }.padding(.vertical, 8)
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }
            }.padding(20)
        }.reviewScrollPosition().companionBackground().navigationTitle(content.pets[family.representativePetId]?.nameZh ?? family.familyKey.rawValue)
            .alert("保存失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
}
