import SwiftUI
import SwiftData
import RocoContent
import RocoDomain
import RocoUserData

struct GrassBadgeView: View {
    let content: ContentStore
    let index: TrackingCatalogIndex
    @Query private var records: [GrassRecord]
    @Query private var medals: [GrassFamilyMedalRecord]
    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var location: BadgeLocationLocationId = .somia
    @State private var state: BadgeState?
    @State private var mode = 0
    @State private var medalFilter = 0
    @State private var recordedOnly = false
    @State private var type: TypeID?
    @State private var leader = 0
    @State private var page = 1
    @State private var suggestionPage = 1
    @State private var error: String?
    private var statuses: [String: BadgeState] {
        Dictionary(uniqueKeysWithValues: records.filter { $0.locationID == location.rawValue }.map { ($0.footprintID, $0.status) })
    }
    private var footprints: [BadgeFootprint] {
        let statuses = statuses
        return content.badgeFootprints.values.filter { footprint in
            guard let pet = content.pets[footprint.petId] else { return false }
            let status = statuses[footprint.footprintKey.rawValue] ?? .unrecorded
            return PetSearch.matches(pet, query: query) && (type == nil || pet.typeIds.contains(type!))
                && (leader == 0 || footprint.isLeader == (leader == 2))
                && (state == nil || status == state) && (!recordedOnly || status != .unrecorded)
        }.sorted { ($0.stageDepth, $0.petId.rawValue) < ($1.stageDepth, $1.petId.rawValue) }
    }
    var body: some View {
        let obtained = Set(medals.filter(\.obtained).map(\.familyID))
        let families = index.badgeFamilies.filter { index.matches($0, query: query, content: content) && (medalFilter == 0 || obtained.contains($0.familyKey.rawValue) == (medalFilter == 1)) }
        let footprints = footprints
        let window = CatalogPage(totalCount: mode == 1 ? families.count : footprints.count, requestedPage: page)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("记录目录", selection: $mode) { Text("地点足迹").tag(0); Text("家族奖牌").tag(1) }.pickerStyle(.segmented)
                if mode == 1 {
                    CollectionProgress(title: "家族奖牌", count: index.badgeFamilies.filter { obtained.contains($0.familyKey.rawValue) }.count, total: index.badgeFamilies.count, tint: .green)
                    Picker("奖牌状态", selection: $medalFilter) { Text("全部").tag(0); Text("已获得").tag(1); Text("未获得").tag(2) }.pickerStyle(.segmented)
                    Text("家族奖牌单独保存，与地点足迹、命定勇者分别统计。").font(.footnote).foregroundStyle(.secondary)
                    CatalogPagination(window: window, page: $page).id("catalog-results-top")
                    ForEach(families[window.range], id: \.familyKey) { family in
                        if let pet = content.pets[family.representativePetId] {
                            Button {
                                do { try UserDatabase.toggleGrassMedal(family.familyKey.rawValue, context: context) } catch { self.error = String(describing: error) }
                            } label: {
                                HStack {
                                    CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 64)
                                    VStack(alignment: .leading) { Text(pet.nameZh).font(.headline); CollectionStatus(selected: obtained.contains(family.familyKey.rawValue), selectedTitle: "已获得", idleTitle: "未获得") }
                                    Spacer()
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(12).companionSurface()
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                    if families.isEmpty { Text("没有符合条件的家族").foregroundStyle(.secondary) }
                } else {
                    BadgeLocationPicker(content: content, selection: $location)
                    CollectionProgress(title: "当前地点目标", count: content.badgeFootprints.values.filter { statuses[$0.footprintKey.rawValue] == .lit }.count, total: content.badgeLocations[location]?.targetCount ?? 0, tint: .green)
                    CompanionMetrics {
                        CompanionMetric(value: String(statuses.values.filter { $0 != .unrecorded }.count), label: "当前地点已录入")
                        CompanionMetric(value: String(statuses.values.filter { $0 == .unlit }.count), label: "未点亮")
                    }
                    DisclosureGroup("足迹筛选") {
                        Toggle("仅当前地点已录入", isOn: $recordedOnly)
                        Picker("状态", selection: $state) { Text("全部").tag(nil as BadgeState?); ForEach(BadgeState.allCases, id: \.self) { Text($0.label).tag(Optional($0)) } }
                        Picker("属性", selection: $type) {
                            Text("全部").tag(nil as TypeID?)
                            ForEach(TypeMatchup(types: content.types).selectable, id: \.typeId) { Text($0.nameZh).tag(Optional($0.typeId)) }
                        }
                        Picker("形态", selection: $leader) { Text("全部").tag(0); Text("普通").tag(1); Text("首领").tag(2) }
                        Button("重置筛选") { recordedOnly = false; state = nil; type = nil; leader = 0; query = "" }
                    }.tint(.primary)
                    if !query.isEmpty {
                        let suggestions = index.badgeFamilies.filter { index.matches($0, query: query, content: content) }
                        if !suggestions.isEmpty {
                            DisclosureGroup("成员匹配的家族 · \(suggestions.count)") {
                                let suggestionWindow = CatalogPage(totalCount: suggestions.count, requestedPage: suggestionPage)
                                CatalogPagination(window: suggestionWindow, page: $suggestionPage)
                                ForEach(suggestions[suggestionWindow.range], id: \.familyKey) { family in
                                    NavigationLink { GrassFamilyView(family: family, content: content, index: index, location: location) } label: {
                                        HStack {
                                            Text(content.pets[family.representativePetId]?.nameZh ?? family.familyKey.rawValue)
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                        }.frame(minHeight: 44).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                }
                            }.tint(.primary)
                        }
                    }
                    Text("\(footprints.count) 条足迹 · 地点独立保存").font(.caption).foregroundStyle(.secondary)
                    CatalogPagination(window: window, page: $page).id("catalog-results-top")
                    ForEach(footprints[window.range], id: \.footprintKey) { footprint in
                        GrassFootprintRow(footprint: footprint, status: statuses[footprint.footprintKey.rawValue] ?? .unrecorded, location: location, content: content)
                    }
                    if footprints.isEmpty { Text("没有符合条件的足迹").foregroundStyle(.secondary) }
                }
                if window.pageCount > 1 { CatalogPagination(window: window, page: $page) }
            }.padding(20)
        }.catalogPagination(page: $page, totalCount: window.totalCount, resetKey: [query, location, state as AnyHashable, mode, medalFilter, recordedOnly, type as AnyHashable, leader])
            .onChange(of: query) { suggestionPage = 1 }
            .reviewScrollPosition().companionBackground().navigationTitle("草系徽章").searchable(text: $query, prompt: "成员名称、图鉴编号、配置 ID 或形态")
            .alert("保存失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") }
    }
}

struct GrassFamilyView: View {
    let family: Family
    let content: ContentStore
    let index: TrackingCatalogIndex
    @State var location: BadgeLocationLocationId
    @Query private var records: [GrassRecord]
    @State private var page = 1
    var body: some View {
        let statuses = Dictionary(uniqueKeysWithValues: records.filter { $0.locationID == location.rawValue }.map { ($0.footprintID, $0.status) })
        let footprints = index.footprintsByFamily[family.familyKey] ?? []
        let window = CatalogPage(totalCount: footprints.count, requestedPage: page)
        List {
            BadgeLocationPicker(content: content, selection: $location)
            CatalogPagination(window: window, page: $page).id("catalog-results-top")
            ForEach(footprints[window.range], id: \.footprintKey) { footprint in
                GrassFootprintRow(footprint: footprint, status: statuses[footprint.footprintKey.rawValue] ?? .unrecorded, location: location, content: content)
            }
            if window.pageCount > 1 { CatalogPagination(window: window, page: $page) }
        }.catalogPagination(page: $page, totalCount: footprints.count, resetKey: [family.familyKey, location])
            .navigationTitle(content.pets[family.representativePetId]?.nameZh ?? family.familyKey.rawValue)
    }
}

private struct GrassFootprintRow: View {
    let footprint: BadgeFootprint
    let status: BadgeState
    let location: BadgeLocationLocationId
    let content: ContentStore
    @Environment(\.modelContext) private var context
    @State private var error: String?
    var body: some View {
        if let pet = content.pets[footprint.petId] {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 52)
                    VStack(alignment: .leading) {
                        Text(pet.nameZh + (footprint.isLeader ? " · 首领" : "")).font(.headline)
                        Text("#\(String(pet.handbookId?.rawValue ?? pet.speciesId.rawValue)) · 配置 \(String(pet.petId.rawValue)) · \(pet.form)").font(.caption).foregroundStyle(.secondary)
                        CollectionStatus(selected: status == .lit, selectedTitle: "已点亮", idleTitle: status.label)
                    }
                }
                Picker("足迹状态", selection: Binding(get: { status }, set: { value in
                    do { try UserDatabase.setGrass(value, footprint: footprint.footprintKey.rawValue, location: location.rawValue, context: context) } catch { self.error = String(describing: error) }
                })) { ForEach(BadgeState.allCases, id: \.self) { Text($0 == .unrecorded ? "移除记录" : $0.label).tag($0) } }.pickerStyle(.menu).tint(.primary)
                if let error { Text(error).foregroundStyle(.red) }
            }.padding(.vertical, 8)
        }
    }
}
