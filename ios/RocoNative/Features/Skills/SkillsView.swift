import SwiftUI
import RocoContent
import RocoDomain

private let skillCategories: [SkillCategory] = [.physicalAttack, .magicAttack, .status, .defense]
func categoryName(_ category: SkillCategory) -> String {
    category.displayName
}
func sourceName(_ source: PetSkillSource) -> String {
    switch source {
    case .pool: "技能池"
    case .stone: "技能石"
    case .bloodline: "血脉技能"
    }
}

struct SkillsView: View {
    let content: ContentStore
    let portraits: PortraitStore
    let index: SkillSearchIndex
    @Environment(\.dismiss) private var dismiss
    @State private var chromeVisible = true
    @State private var query = ""
    @State private var type: TypeID?
    @State private var category: SkillCategory?
    @State private var skills: [Skill] = []
    @State private var prefetchBySkill: [SkillID: [AssetID]] = [:]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CompanionPageHeader(title: "技能查询", subtitle: "\(skills.count) 个技能", identifier: "skills")
                    CompanionHeading(title: "技能目录", detail: "\(skills.count) 个 · ID 排序")
                    if skills.isEmpty { ContentUnavailableView("没有符合条件的技能", systemImage: "sparkle.magnifyingglass", description: Text("尝试其他关键词，或更改属性与类别筛选。")) }
                    Color.clear.frame(height: 0).id("catalog-results-top")
                    LazyVStack(spacing: 0) {
                        ForEach(skills, id: \.skillId) { skill in
                            SkillCatalogRow(skill: skill, content: content, portraits: portraits, index: index,
                                prefetch: prefetchBySkill[skill.skillId] ?? [])
                        }
                    }
                }.padding(20)
            }
            .task(id: [query as AnyHashable, type as AnyHashable, category as AnyHashable]) {
                let updated = await index.searchInBackground(query, type: type, category: category)
                guard !Task.isCancelled else { return }
                var ahead: [SkillID: [AssetID]] = [:]
                for offset in stride(from: 0, to: updated.count, by: 4) {
                    ahead[updated[offset]] = updated.dropFirst(offset + 1).prefix(4)
                        .compactMap { content.skills[$0].flatMap { content.skillIcon(for: $0) } }
                }
                prefetchBySkill = ahead
                skills = updated.compactMap { content.skills[$0] }
            }
            .onChange(of: [query as AnyHashable, type as AnyHashable, category as AnyHashable]) {
                proxy.scrollTo("catalog-results-top", anchor: .top)
            }
            .onScrollPhaseChange { _, phase, _ in
                chromeVisible = phase == .idle
            }
            .reviewScrollPosition()
            .scrollDismissesKeyboard(.interactively)
            .companionBackground()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .background {
                CompanionScrollChrome(query: $query, visible: chromeVisible,
                    prompt: "中文名、ID 或描述", searchLabel: "搜索技能", identifier: "skills",
                    returnToParent: { dismiss() }, makeMenu: makeFilterMenu,
                    filterValue: "\(type.flatMap { content.types[$0]?.nameZh } ?? "全部属性")，\(category.map(categoryName) ?? "全部类别")")
                    .frame(width: 0, height: 0)
            }
        }
    }
    private func makeFilterMenu() -> UIMenu {
        let typeBinding = $type
        let categoryBinding = $category
        let types = [UIAction(title: "全部属性", state: type == nil ? .on : .off) { _ in
            typeBinding.wrappedValue = nil
        }] + content.orderedTypes.filter(\.normalBattleType).map { value in
            UIAction(title: value.nameZh, image: GameIconCatalog.type(value.typeId), state: type == value.typeId ? .on : .off) { _ in
                typeBinding.wrappedValue = value.typeId
            }
        }
        let categories = [UIAction(title: "全部类别", state: category == nil ? .on : .off) { _ in
            categoryBinding.wrappedValue = nil
        }] + skillCategories.map { value in
            UIAction(title: categoryName(value), image: UIImage(systemName: value.symbolName), state: category == value ? .on : .off) { _ in
                categoryBinding.wrappedValue = value
            }
        }
        let clear = UIAction(title: "清除筛选", image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            attributes: type == nil && category == nil ? [.disabled] : []) { _ in
                typeBinding.wrappedValue = nil
                categoryBinding.wrappedValue = nil
            }
        return UIMenu(children: [
            UIMenu(title: "属性", options: .singleSelection, children: types),
            UIMenu(title: "类别", options: .singleSelection, children: categories),
            UIMenu(options: .displayInline, children: [clear])
        ])
    }

}

struct SkillDetailView: View {
    let skill: Skill
    let content: ContentStore
    let portraits: PortraitStore
    let index: SkillSearchIndex

    private enum Section: String, CaseIterable {
        case details = "技能资料"
        case acquisition = "获得方式"
    }
    @State private var section = Section.details
    @State private var acquisitionQuery = SkillAcquisitionQuery(scope: .sameName)

    var body: some View {
        CompanionTabbedPage(title: "技能分区", selection: $section, options: Section.allCases, identifier: "skill-detail-tabs") {
            if section == .details {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        CanonicalThumbnail(assetID: content.skillIcon(for: skill), content: content, size: 72)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(skill.nameZh).font(.title2.bold())
                            Text("技能 #\(String(skill.skillId.rawValue))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack { skillBadges }
                        VStack(alignment: .leading, spacing: 8) { skillBadges }
                    }
                    CompanionMetrics {
                        if let power = skill.power { CompanionMetric(value: power.formatted(), label: "威力") }
                        if let cost = skill.energyCost { CompanionMetric(value: cost.formatted(), label: "能耗") }
                    }
                }.padding(20).companionAccentSurface(tint: skill.typeId.map(GameIconCatalog.color) ?? skill.category.tint)
                if !skill.description.isEmpty {
                    CompanionSection("技能效果") { Text(skill.description).font(.body).textSelection(.enabled) }
                }
            } else {
                if let description = skill.acquisitionDescription {
                    CompanionSection("获得方式") { Text(description).font(.body) }
                } else {
                    SkillAcquisitionResultsView(skill: skill.skillId, content: content, portraits: portraits, index: index, query: $acquisitionQuery)
                }
            }
        }.navigationTitle(skill.nameZh)
    }
    @ViewBuilder private var skillBadges: some View {
        if let id = skill.typeId, let type = content.types[id] { TypeBadge(type: type) }
        if skill.isBattleEquipmentGranted {
            SkillCategoryPill(category: .physicalAttack, title: "物理/魔法")
        } else {
            SkillCategoryPill(category: skill.category)
        }
    }
    private func petLink(_ pet: Pet) -> some View {
        NavigationLink { ExistingPetDestination(pet: pet, content: content, portraits: portraits) } label: {
            HStack(spacing: 14) {
                CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 56)
                VStack(alignment: .leading, spacing: 8) {
                    Text(pet.nameZh).font(.headline)
                    PetTypes(pet: pet, content: content)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }.padding(.vertical, 6)
        }.buttonStyle(.plain)
    }
}

/// Reuses the existing detail; lazy decode only when a specific pet is opened.
struct ExistingPetDestination: View {
    let pet: Pet
    let content: ContentStore
    let portraits: PortraitStore
    @State private var result: Result<UIImage, Error>?
    var body: some View {
        Group {
            switch result {
            case .success(let image): PetDetail(pet: pet, content: content, image: image, portraits: portraits)
            case .failure:
                PetDetail(pet: pet, content: content, image: UIImage(systemName: "photo") ?? UIImage(), portraits: portraits)
                    .overlay(alignment: .bottom) { Text("图片未能加载，精灵资料仍可查看").font(.caption).padding().background(.regularMaterial) }
            case nil: ProgressView()
            }
        }.task(id: pet.petId) {
            do {
                let image = try await portraits.image(for: pet)
                try Task.checkCancellation()
                result = .success(image)
            } catch is CancellationError {
            } catch { result = .failure(error) }
        }
    }
}
