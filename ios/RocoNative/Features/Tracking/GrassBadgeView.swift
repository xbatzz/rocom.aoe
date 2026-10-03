import SwiftUI
import UIKit
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
    private func footprints(statuses: [String: BadgeState], search: PetSearch.Query) -> [BadgeFootprint] {
        return index.orderedBadgeFootprints.filter { footprint in
            guard let pet = content.pets[footprint.petId] else { return false }
            let status = statuses[footprint.footprintKey.rawValue] ?? .unrecorded
            return search.matches(pet) && (type == nil || pet.typeIds.contains(type!))
                && (leader == 0 || footprint.isLeader == (leader == 2))
                && (state == nil || status == state) && (!recordedOnly || status != .unrecorded)
        }
    }
    var body: some View {
        let search = PetSearch.Query(query)
        let statuses = statuses
        let obtained = Set(medals.filter(\.obtained).map(\.familyID))
        let families = mode == 1 ? index.badgeFamilies.filter { index.matches($0, query: search, content: content) && (medalFilter == 0 || obtained.contains($0.familyKey.rawValue) == (medalFilter == 1)) } : []
        let footprints = mode == 0 ? footprints(statuses: statuses, search: search) : []
        let window = CatalogPage(totalCount: mode == 1 ? families.count : footprints.count, requestedPage: page)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                CompanionPageHeader(title: "草系徽章", subtitle: "\(window.totalCount) 条记录", identifier: "grass")
                Picker("记录目录", selection: $mode) { Text("地点足迹").tag(0); Text("家族奖牌").tag(1) }.pickerStyle(.segmented)
                if mode == 1 {
                    CollectionProgress(title: "家族奖牌", count: index.badgeFamilies.filter { obtained.contains($0.familyKey.rawValue) }.count, total: index.badgeFamilies.count, tint: .green)
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
                    BadgeLocationPicker(content: content, selection: $location).accessibilityIdentifier("grass-location")
                    CollectionProgress(title: "当前地点目标", count: statuses.filter { $0.value == .lit && content.badgeFootprints[FootprintKey(rawValue: $0.key)] != nil }.count, total: content.badgeLocations[location]?.targetCount ?? 0, tint: .green)
                    CompanionMetrics {
                        CompanionMetric(value: String(statuses.values.filter { $0 != .unrecorded }.count), label: "当前地点已录入")
                        CompanionMetric(value: String(statuses.values.filter { $0 == .unlit }.count), label: "未点亮")
                    }
                    if !query.isEmpty {
                        let suggestions = index.badgeFamilies.filter { index.matches($0, query: search, content: content) }
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
            .reviewScrollPosition().companionBackground().companionPageChrome(identifier: "grass", query: $query, prompt: "成员名称、图鉴编号、配置 ID 或形态", searchLabel: "搜索草系徽章", makeMenu: makeFilterMenu)
            .alert("保存失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") }
    }
    private func makeFilterMenu() -> UIMenu {
        if mode == 1 {
            let selection = $medalFilter
            return UIMenu(children: ["全部", "已获得", "未获得"].enumerated().map { value, label in
                UIAction(title: label, state: medalFilter == value ? .on : .off) { _ in
                    selection.wrappedValue = value
                }
            })
        }
        let query = $query
        let state = $state
        let type = $type
        let leader = $leader
        let recordedOnly = $recordedOnly
        let states = [UIAction(title: "全部", state: state.wrappedValue == nil ? .on : .off) { _ in
            state.wrappedValue = nil
        }] + BadgeState.allCases.map { value in
            UIAction(title: value.label, state: state.wrappedValue == value ? .on : .off) { _ in
                state.wrappedValue = value
            }
        }
        let types = [UIAction(title: "全部", state: type.wrappedValue == nil ? .on : .off) { _ in
            type.wrappedValue = nil
        }] + content.normalTypes.map { value in
            UIAction(title: value.nameZh, image: GameIconCatalog.type(value.typeId), state: type.wrappedValue == value.typeId ? .on : .off) { _ in
                type.wrappedValue = value.typeId
            }
        }
        let forms = ["全部", "普通", "首领"].enumerated().map { value, label in
            UIAction(title: label, state: leader.wrappedValue == value ? .on : .off) { _ in
                leader.wrappedValue = value
            }
        }
        return UIMenu(children: [
            UIAction(title: "仅当前地点已录入", state: recordedOnly.wrappedValue ? .on : .off) { _ in
                recordedOnly.wrappedValue.toggle()
            },
            UIMenu(title: "状态", options: .singleSelection, children: states),
            UIMenu(title: "属性", options: .singleSelection, children: types),
            UIMenu(title: "形态", options: .singleSelection, children: forms),
            UIAction(title: "重置筛选") { _ in
                recordedOnly.wrappedValue = false
                state.wrappedValue = nil
                type.wrappedValue = nil
                leader.wrappedValue = 0
                query.wrappedValue = ""
            }
        ])
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
                    .accessibilityIdentifier("grass-status-\(footprint.footprintKey.rawValue)")
                if let error { Text(error).foregroundStyle(.red) }
            }.padding(.vertical, 8)
        }
    }
}
