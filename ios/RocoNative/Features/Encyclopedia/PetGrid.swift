import SwiftUI
import RocoDomain
import RocoContent

extension Pet {
    var numberLabel: String {
        if let handbookId { return String(format: "No. %03d", handbookId.rawValue) }
        return "配置 \(petId.rawValue)"
    }
}

/// Catalog queries operate only on canonical values; images remain owned by lazy cells.
private struct PetListQuery {
    enum Sort: String, CaseIterable {
        case ordinal = "图鉴顺序", total = "总种族值", speed = "速度", name = "中文名"
    }
    enum Leader: String, CaseIterable {
        case all = "全部", leader = "首领", ordinary = "非首领"
    }
    enum Stage: String, CaseIterable {
        case all = "全部", initial = "初始", evolved = "已进化", canEvolve = "可进化"
    }

    var keyword = ""
    var firstType: TypeID?
    var secondType: TypeID?
    var attackStyle: PetAttackStyle?
    var leader = Leader.all
    var stage = Stage.all
    var sort = Sort.ordinal

    var hasFilters: Bool {
        firstType != nil || secondType != nil || attackStyle != nil || leader != .all || stage != .all
    }

    func results(pets: [Pet], content: ContentStore) -> [Pet] {
        let query = Self.normalize(keyword)
        let numeric = !query.isEmpty && query.utf8.allSatisfy { (48...57).contains($0) }
        // parentPetId preserves Web's reverse-parent rule, including links absent
        // from the narrower evolution edge table. Branch edges are included too.
        let evolutionSources = Set(content.pets.values.compactMap(\.parentPetId))
            .union(content.evolutions.values.map(\.sourcePetId))
        let matches = pets.filter { pet in
            let typesMatch = [firstType, secondType].compactMap { $0 }.allSatisfy { pet.typeIds.contains($0) }
            let leaderMatch = leader == .all || (leader == .leader ? pet.isLeader : !pet.isLeader)
            let stageMatch: Bool = switch stage {
            case .all: true
            case .initial: pet.parentPetId == nil
            case .evolved: pet.parentPetId != nil
            case .canEvolve: evolutionSources.contains(pet.petId)
            }
            guard typesMatch, leaderMatch, stageMatch,
                attackStyle == nil || pet.attackStyle == attackStyle else { return false }
            if query.isEmpty { return true }
            if numeric {
                // Configuration ID is an independent exact match. Never substitute
                // speciesId for a missing real handbook number.
                let unpadded = Self.unpadded(query)
                if unpadded == String(pet.petId.rawValue) { return true }
                guard let number = pet.handbookId?.rawValue else { return false }
                let text = String(number)
                let padded = String(format: "%03d", number)
                return text.hasPrefix(unpadded) || padded.hasPrefix(query) || padded.hasSuffix(query)
            }
            let typeNames = (pet.typeIds + [pet.defaultLegacyTypeId].compactMap { $0 })
                .compactMap { content.type($0)?.nameZh }
            let fields = [pet.nameZh, pet.resourceKey, pet.form] + pet.searchAliases + typeNames
            return fields.contains { Self.normalize($0).contains(query) }
        }
        return matches.sorted { left, right in
            switch sort {
            case .ordinal:
                if left.ordinal != right.ordinal { return left.ordinal < right.ordinal }
            case .total:
                let l = Self.total(left), r = Self.total(right)
                if l != r { return l > r }
            case .speed:
                if left.baseStats.speed != right.baseStats.speed { return left.baseStats.speed > right.baseStats.speed }
            case .name:
                let order = left.nameZh.compare(right.nameZh, locale: Locale(identifier: "zh_CN"))
                if order != .orderedSame { return order == .orderedAscending }
            }
            return left.petId.rawValue < right.petId.rawValue
        }
    }

    private static func total(_ pet: Pet) -> Int {
        let s = pet.baseStats
        return s.hp + s.physicalAttack + s.magicalAttack + s.physicalDefense + s.magicalDefense + s.speed
    }

    private static func unpadded(_ value: String) -> String {
        let stripped = value.drop(while: { $0 == "0" })
        return stripped.isEmpty ? "0" : String(stripped)
    }

    private static func normalize(_ value: String) -> String {
        let scalars = value.unicodeScalars.map { scalar -> String in
            if (0xFF10...0xFF19).contains(scalar.value), let digit = UnicodeScalar(scalar.value - 0xFEE0) {
                return String(digit)
            }
            return String(scalar)
        }
        return scalars.joined().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct AlignedPetGrid: View {
    /// Passed from ContentStore.orderedPets; never Dictionary iteration order.
    let pets: [Pet]
    let content: ContentStore
    let portraits: PortraitStore
    let anchors: PortraitAnchors
    let open: (Pet, PortraitOrigin) -> Void
    @State private var query = PetListQuery()
    @State private var showingFilters = false
    @FocusState private var searchFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Match Web default eligibility using canonical flags, without guessing from assets or egg groups.
    private var catalogPets: [Pet] {
        pets.filter { $0.implemented && $0.publicVisible }
    }

    private var typeOptions: [BattleType] {
        let used = Set(catalogPets.flatMap(\.typeIds))
        return content.types.values.filter { used.contains($0.typeId) }
            .sorted { $0.typeId.rawValue < $1.typeId.rawValue }
    }

    var body: some View {
        let results = query.results(pets: catalogPets, content: content)
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                listControls(resultCount: results.count)
                if results.isEmpty {
                    ContentUnavailableView {
                        Label("没有符合条件的精灵", systemImage: "magnifyingglass")
                    } description: {
                        Text("试试其他关键词，或清除筛选条件。")
                    } actions: {
                        Button("重置搜索与筛选") { query = PetListQuery() }
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 150), spacing: 20)], spacing: 28) {
                    ForEach(results, id: \.petId) { pet in
                        PetGridCell(pet: pet, content: content, portraits: portraits, anchors: anchors) { pet, origin in
                            searchFocused = false
                            open(pet, origin)
                        }
                    }
                }
            }.padding(24)
        }
        .reviewScrollPosition()
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemBackground))
        .sheet(isPresented: $showingFilters) { filterSheet }
    }

    private func listControls(resultCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Inline SwiftUI search keeps the frozen UIKit navigation item untouched.
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("名称、图鉴编号或配置 ID", text: $query.keyword)
                    .focused($searchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { searchFocused = false }
                    .accessibilityLabel("搜索精灵")
                if !query.keyword.isEmpty {
                    Button { query.keyword = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("清除搜索")
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            ViewThatFits(in: .horizontal) {
                HStack {
                    filterButton
                    Spacer()
                    sortMenu
                }
                VStack(alignment: .leading, spacing: 8) {
                    filterButton
                    sortMenu
                }
            }
            Text("\(resultCount) / \(catalogPets.count) 只已实装精灵")
                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private var filterButton: some View {
        Button {
            searchFocused = false
            showingFilters = true
        } label: {
            Label(query.hasFilters ? "筛选 · 已启用" : "筛选", systemImage: "line.3.horizontal.decrease")
        }
        .frame(minHeight: 44)
    }

    private var sortMenu: some View {
        Menu {
            Picker("排序", selection: $query.sort) {
                ForEach(PetListQuery.Sort.allCases, id: \.self) { sort in
                    Text(sort.rawValue).tag(sort)
                }
            }
        } label: {
            Label(query.sort.rawValue, systemImage: "arrow.up.arrow.down")
        }
        .frame(minHeight: 44)
        .accessibilityLabel("排序，\(query.sort.rawValue)")
    }

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section {
                    typePicker("属性一", selection: $query.firstType)
                    typePicker("属性二", selection: $query.secondType)
                } footer: {
                    Text("属性匹配任意属性位；选择两项时需同时满足。")
                }
                Section("战斗特征") {
                    Picker("攻击倾向", selection: $query.attackStyle) {
                        Text("全部").tag(Optional<PetAttackStyle>.none)
                        Text("物攻").tag(Optional(PetAttackStyle.physical))
                        Text("魔攻").tag(Optional(PetAttackStyle.magic))
                        Text("双攻").tag(Optional(PetAttackStyle.both))
                        if catalogPets.contains(where: { $0.attackStyle == .unknown }) {
                            Text("未知").tag(Optional(PetAttackStyle.unknown))
                        }
                    }
                    Picker("首领", selection: $query.leader) {
                        ForEach(PetListQuery.Leader.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                Section {
                    Picker("进化状态", selection: $query.stage) {
                        ForEach(PetListQuery.Stage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } footer: {
                    Text("初始与已进化按已有父配置区分；可进化表示目录中有后续形态，不代表当前已满足进化条件。")
                }
                Section {
                    Button("清除筛选") {
                        query.firstType = nil
                        query.secondType = nil
                        query.attackStyle = nil
                        query.leader = .all
                        query.stage = .all
                    }
                    .disabled(!query.hasFilters)
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showingFilters = false }
                }
            }
        }
    }

    private func typePicker(_ title: String, selection: Binding<TypeID?>) -> some View {
        Picker(title, selection: selection) {
            Text("全部").tag(Optional<TypeID>.none)
            ForEach(typeOptions, id: \.typeId) { type in
                Text(type.nameZh).tag(Optional(type.typeId))
            }
        }
    }
}

/// Decoding lives in the lazy cell body, never in the catalog/ForEach input construction.
/// The mounted UIImageView and bounded PortraitStore cache own the bitmap; there is no
/// 721-element UIImage array or per-pet @State bitmap retained after scrolling away.
private struct PetGridCell: View {
    let pet: Pet
    let content: ContentStore
    let portraits: PortraitStore
    let anchors: PortraitAnchors
    let open: (Pet, PortraitOrigin) -> Void

    var body: some View {
        let origin = PortraitOrigin(petID: pet.petId, instance: "encyclopedia-grid")
        let portrait = Result { try portraits.image(for: pet) }
        Button { open(pet, origin) } label: {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    switch portrait {
                    case .success(let image):
                        AnchoredPortrait(image: image, origin: origin, anchors: anchors)
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                            Text("图片加载失败").font(.caption)
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .allowsHitTesting(false)
                Text(pet.nameZh).font(.headline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(pet.numberLabel).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                PetTypes(pet: pet, content: content)
                if case .failure(let error) = portrait {
                    Text(String(describing: error)).font(.caption2).foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.interaction, Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(portrait.isFailure)
        .accessibilityIdentifier("pet-\(pet.petId.rawValue)")
        .accessibilityLabel("\(pet.nameZh)，\(pet.numberLabel)")
        .accessibilityHint(portrait.isFailure ? "图片加载失败" : "查看精灵详情")
    }
}

private extension Result {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}
