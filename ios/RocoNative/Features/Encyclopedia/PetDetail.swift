import SwiftUI
import RocoDomain
import RocoContent

struct PetPortrait: View {
    let image: UIImage
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(0.84)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

struct PetDetail: View {
    let pet: Pet
    let content: ContentStore
    let image: UIImage
    var anchors: PortraitAnchors? = nil
    var transitionOrigin: PortraitOrigin? = nil
    var portraits: PortraitStore? = nil
    var openRelated: ((Pet, PortraitOrigin, PortraitAnchors) -> Void)? = nil
    private enum Section: String, CaseIterable {
        case overview = "概览"
        case skills = "技能"
        case evolution = "进化"
        case profile = "介绍"
    }
    @State private var section = Section.overview
    @State private var moveSource = PetSkillSource.pool
    @State private var selectedSkill: SkillID?
    @State private var index: SkillSearchIndex?
    @State private var moveRows: [PetSkill] = []
    @State private var moveKeyword = ""
    @State private var moveType: TypeID?
    @State private var moveCategory: SkillCategory?
    private let relatedAnchors = PortraitAnchors()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.canonicalThumbnails) private var inheritedThumbnails

    var body: some View {
        GeometryReader { geometry in
            // Keep the frozen Hero sizing and its mounted view inside the
            // ScrollView across section changes for the shared-image return.
            let side = max(0, min(320, geometry.size.width - 48, geometry.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.26 : 0.44)))
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 28) {
                            Group {
                                if let anchors {
                                    AnchoredPortrait(image: image, origin: nil, anchors: anchors)
                                } else {
                                    PetPortrait(image: image)
                                }
                            }
                            .frame(width: side, height: side)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("hero-\(pet.petId.rawValue)")
                            .accessibilityHidden(true)
                            Text(pet.nameZh).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                            if pet.portraitAssetId.flatMap({ content.assets[$0]?.availability }) == .missing {
                                Label("暂无精灵图片", systemImage: "photo").foregroundStyle(.secondary)
                            }
                            PetTypes(pet: pet, content: content)
                            VStack(alignment: .leading, spacing: 6) {
                                if let number = pet.handbookId { Text(String(format: "No. %03d", number.rawValue)).font(.subheadline.monospacedDigit()) }
                                Text("配置 \(String(pet.petId.rawValue)) · \(pet.form == "default" ? "默认形态" : pet.form)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.id("pet-top")
                        VStack(alignment: .leading, spacing: 28) {
                            switch section {
                            case .overview:
                                detailCard("种族值") { PetStatChart(pet: pet) }
                                if let traitId = content.petDetails[pet.petId]?.traitId, let trait = content.traits[traitId] {
                                    TraitDetailCard(trait: trait, content: content, tint: pet.typeIds.first.map(GameIconCatalog.color) ?? .teal)
                                }
                            case .skills:
                                skillSections
                            case .evolution:
                                evolutionSections
                                familySections
                                if !hasEvolutionRelations {
                                    ContentUnavailableView("暂无进化关系", systemImage: "arrow.triangle.branch", description: Text("当前精灵没有可展示的进化或谱系资料。"))
                                }
                            case .profile:
                                profileSection
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Short sections must still be able to align below the
                        // fixed tabs while the shared portrait remains mounted.
                        .frame(minHeight: section == .overview ? nil : geometry.size.height, alignment: .topLeading)
                        .id("pet-section")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                .reviewScrollPosition()
                .accessibilityIdentifier("detail-\(pet.petId.rawValue)")
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        CompanionTabBar(title: "精灵详情", selection: $section, options: Section.allCases, identifier: "pet-detail-tabs")
                            .padding(.horizontal, 24).padding(.vertical, 6)
                        if section == .skills {
                            CompanionTabBar(title: "技能来源", selection: $moveSource, options: [.pool, .stone, .bloodline], identifier: "pet-skill-tabs", label: sourceTitle)
                                .padding(.horizontal, 24).padding(.bottom, 6)
                        }
                        Divider()
                    }.background(Color(uiColor: .systemBackground))
                }
                .onChange(of: section) {
                    proxy.scrollTo(section == .overview ? "pet-top" : "pet-section", anchor: .top)
                }
                .onChange(of: moveSource) { proxy.scrollTo("pet-section", anchor: .top) }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .task {
            guard index == nil else { return }
            let built = await SkillSearchIndex.buildInBackground(content: content)
            guard !Task.isCancelled else { return }
            index = built
        }
        .sheet(isPresented: Binding(get: { selectedSkill != nil }, set: { if !$0 { selectedSkill = nil } })) {
            NavigationStack {
                if let id = selectedSkill, let skill = content.skills[id], let index, let portraits {
                    SkillDetailView(skill: skill, content: content, portraits: portraits, index: index)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { selectedSkill = nil } } }
                }
            }
        }
        // UIKit-created hosting controllers do not inherit the app environment.
        .environment(\.canonicalThumbnails, portraits?.thumbnails ?? inheritedThumbnails)
    }

    @ViewBuilder private var evolutionSections: some View {
        let previous = relatedPets((content.incomingEvolutionsByPet[pet.petId] ?? []).map(\.sourcePetId))
        let next = relatedPets((content.evolutionsByPet[pet.petId] ?? []).map(\.targetPetId))
        if !previous.isEmpty || !next.isEmpty {
            detailCard("进化关系") {
                if !previous.isEmpty {
                    Text("前置形态").font(.subheadline).foregroundStyle(.secondary)
                    ForEach(previous, id: \.petId) { relatedRow($0) }
                }
                if !next.isEmpty {
                    Text("后续形态").font(.subheadline).foregroundStyle(.secondary)
                    ForEach(next, id: \.petId) { relatedRow($0) }
                }
            }
        }
    }

    @ViewBuilder private var familySections: some View {
        // skillTerminal groups non-leader ancestor paths by terminal species.
        // It is lineage information, never a claim about shared learnable skills.
        let families = content.familiesByPet[pet.petId]?[.skillTerminal] ?? []
        ForEach(families, id: \.familyKey) { family in
            let members = relatedPets(family.memberPetIds.filter { $0 != pet.petId })
            if !members.isEmpty, let representative = content.pets[family.representativePetId] {
                detailCard("进化谱系 · \(representative.nameZh)") {
                    Text("按最终形态归组，包含同一谱系的前置与其他形态。").font(.footnote).foregroundStyle(.secondary)
                    ForEach(members, id: \.petId) { relatedRow($0) }
                }
            }
        }
    }

    @ViewBuilder private var skillSections: some View {
        // Only current-pet relations; dictionary lookups resolve exact skill IDs.
        if moveSource != .bloodline {
            DisclosureGroup("筛选自有与学习技能") {
                TextField("技能名称或描述", text: $moveKeyword).textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("属性", selection: $moveType) {
                    Text("全部").tag(nil as TypeID?)
                    ForEach(content.orderedTypes, id: \.typeId) { Text($0.nameZh).tag(Optional($0.typeId)) }
                }
                Picker("类别", selection: $moveCategory) {
                    Text("全部").tag(nil as SkillCategory?)
                    ForEach([SkillCategory.physicalAttack, .magicAttack, .status, .defense, .unknown], id: \.self) { Text(categoryName($0)).tag(Optional($0)) }
                }
                Button("重置筛选") { moveKeyword = ""; moveType = nil; moveCategory = nil }
            }.tint(.primary)
        }
        let allRows = content.petSkillsByPetAndSource[pet.petId]?[moveSource] ?? []
        detailCard(sourceTitle(moveSource)) {
            if allRows.isEmpty {
                Text("当前精灵没有\(sourceTitle(moveSource))资料").foregroundStyle(.secondary)
            } else if moveRows.isEmpty {
                Text("没有符合筛选条件的技能").foregroundStyle(.secondary)
            }
            Color.clear.frame(height: 0).id("catalog-results-top")
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(moveRows) { relation in
                    VStack(alignment: .leading, spacing: 0) {
                        if let skill = content.skills[relation.skillId] {
                            Divider()
                            Button { selectedSkill = skill.skillId } label: { skillRow(skill, relation: relation) }
                                .buttonStyle(.plain).disabled(index == nil || portraits == nil)
                                .accessibilityHint("打开完整技能说明与获得方式")
                        }
                    }
                }
            }
        }
        .task(id: [pet.petId as AnyHashable, moveSource as AnyHashable, moveKeyword as AnyHashable, moveType as AnyHashable, moveCategory as AnyHashable]) {
            moveRows = allRows.filter { relation in
                guard let skill = content.skills[relation.skillId] else { return false }
                return moveSource == .bloodline || ((moveKeyword.isEmpty || "\(skill.nameZh) \(skill.description)".localizedStandardContains(moveKeyword))
                    && (moveType == nil || skill.typeId == moveType) && (moveCategory == nil || skill.category == moveCategory))
            }
        }
    }

    private func sourceTitle(_ source: PetSkillSource) -> String {
        switch source {
        case .pool: "技能池"
        case .stone: "技能石"
        case .bloodline: "血脉技能"
        }
    }

    private func skillRow(_ skill: Skill, relation: PetSkill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SkillSummary(skill: skill, content: content)
            if let legacy = relation.legacyTypeId, let type = content.types[legacy] {
                Text("血脉属性：\(type.nameZh)").font(.subheadline).foregroundStyle(.secondary)
            }
            if !skill.description.isEmpty {
                Text(skill.description).font(.subheadline).foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func categoryLabel(_ category: SkillCategory) -> String? {
        switch category {
        case .physicalAttack: "物理攻击"
        case .magicAttack: "魔法攻击"
        case .status: "变化"
        case .defense: "防御"
        case .unknown: nil
        }
    }

    private var profileRows: [(String, String)] {
        let profile = content.petDetails[pet.petId]?.worldProfile ?? [:]
        return [("精灵类别", profile["type_desc"]), ("栖息描述", profile["description_habitat"]), ("简介", profile["introduction"])]
            .compactMap { label, value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return (label, value)
            }
    }

    @ViewBuilder private var profileSection: some View {
        if profileRows.isEmpty {
            ContentUnavailableView("暂无精灵介绍", systemImage: "text.book.closed", description: Text("当前精灵的类别、栖息描述与简介尚未收录。"))
        } else {
            detailCard("精灵资料") {
                ForEach(profileRows, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(label).font(.subheadline).foregroundStyle(.secondary)
                        Text(value).textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var hasEvolutionRelations: Bool {
        let ids = (content.incomingEvolutionsByPet[pet.petId] ?? []).map(\.sourcePetId)
            + (content.evolutionsByPet[pet.petId] ?? []).map(\.targetPetId)
            + (content.familiesByPet[pet.petId]?[.skillTerminal] ?? []).flatMap(\.memberPetIds).filter { $0 != pet.petId }
        return !relatedPets(ids).isEmpty
    }

    private func relatedPets(_ ids: [PetID]) -> [Pet] {
        var seen: Set<PetID> = []
        return ids.compactMap { id in
            guard seen.insert(id).inserted, let related = content.pets[id], related.publicVisible else { return nil }
            return related
        }
    }

    private func relatedRow(_ related: Pet) -> some View {
        Group {
            if let openRelated {
                RelatedPetRow(pet: related, portraits: portraits, anchors: relatedAnchors, open: openRelated)
            } else if let portraits {
                NavigationLink { ExistingPetDestination(pet: related, content: content, portraits: portraits) } label: {
                    HStack {
                        CanonicalThumbnail(assetID: related.portraitAssetId, content: content, size: 52)
                        VStack(alignment: .leading) { Text(related.nameZh).font(.headline); Text(related.numberLabel).font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                    }.padding(.vertical, 6)
                }.buttonStyle(.plain)
            }
        }
    }

    private func detailCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct RelatedPetRow: View {
    let pet: Pet
    let portraits: PortraitStore?
    let anchors: PortraitAnchors
    let open: ((Pet, PortraitOrigin, PortraitAnchors) -> Void)?

    @State private var image: UIImage?
    @State private var imageFailed = false
    @State private var instance = UUID().uuidString

    var body: some View {
        let origin = PortraitOrigin(petID: pet.petId, instance: instance)
        Button {
            open?(pet, origin, anchors)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                if let image {
                    AnchoredPortrait(image: image, origin: origin, anchors: anchors)
                        .frame(width: 52, height: 52).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.nameZh).font(.headline)
                    Text("\(pet.numberLabel) · \(pet.form == "default" ? "默认形态" : pet.form)")
                        .font(.caption).foregroundStyle(.secondary)
                    if imageFailed { Text("图片加载失败").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(open == nil)
        .task {
            guard image == nil, let portraits else { return }
            do {
                let loaded = try await portraits.image(for: pet)
                try Task.checkCancellation()
                image = loaded
            } catch is CancellationError { }
            catch { imageFailed = true }
        }
    }
}
