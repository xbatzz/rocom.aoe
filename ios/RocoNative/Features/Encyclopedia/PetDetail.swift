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
    private let relatedAnchors = PortraitAnchors()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            // Keep the frozen Hero geometry and its position inside the ScrollView.
            let side = max(0, min(320, geometry.size.width - 48, geometry.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.26 : 0.44)))
            ScrollView {
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
                    detailCard("基础信息") {
                        if let number = pet.handbookId { detailValue("图鉴编号", String(format: "No. %03d", number.rawValue)) }
                        detailValue("配置 ID", String(pet.petId.rawValue))
                        detailValue("形态", pet.form == "default" ? "默认形态" : pet.form)
                        let types = pet.typeIds.compactMap { content.types[$0]?.nameZh }.joined(separator: " · ")
                        if !types.isEmpty { detailValue("属性", types) }
                    }
                    detailCard("种族值") {
                        ForEach(stats, id: \.0) { label, value in
                            detailValue(label, String(value))
                        }
                        Divider()
                        detailValue("总种族值", String(stats.reduce(0) { $0 + $1.1 }))
                    }
                    if let traitId = content.petDetails[pet.petId]?.traitId, let trait = content.traits[traitId] {
                        detailCard("特性") {
                            Text(trait.nameZh).font(.headline)
                            if !trait.description.isEmpty { Text(trait.description).foregroundStyle(.secondary) }
                        }
                    }
                    evolutionSections
                    familySections
                    skillSections
                    profileSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .accessibilityIdentifier("detail-\(pet.petId.rawValue)")
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var stats: [(String, Int)] {
        let s = pet.baseStats
        return [("生命", s.hp), ("物攻", s.physicalAttack), ("魔攻", s.magicalAttack),
                ("物防", s.physicalDefense), ("魔防", s.magicalDefense), ("速度", s.speed)]
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
        let groups = Dictionary(grouping: content.petSkillsByPet[pet.petId] ?? [], by: \.source)
        ForEach([PetSkillSource.pool, .stone, .bloodline], id: \.rawValue) { source in
            if let rows = groups[source], !rows.isEmpty {
                detailCard(sourceTitle(source)) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, relation in
                        if let skill = content.skills[relation.skillId] {
                            if index > 0 { Divider() }
                            skillRow(skill, relation: relation)
                        }
                    }
                }
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
            Text(skill.nameZh).font(.headline)
            let labels = [skill.typeId.flatMap { content.types[$0]?.nameZh }, categoryLabel(skill.category)].compactMap { $0 }
            if !labels.isEmpty { Text(labels.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary) }
            if let legacy = relation.legacyTypeId, let type = content.types[legacy] {
                Text("血脉属性：\(type.nameZh)").font(.subheadline).foregroundStyle(.secondary)
            }
            if let power = skill.power { detailValue("威力", power.formatted(.number)) }
            if let energy = skill.energyCost { detailValue("能耗", energy.formatted(.number)) }
            if !skill.description.isEmpty { Text(skill.description).font(.subheadline).foregroundStyle(.secondary) }
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

    @ViewBuilder private var profileSection: some View {
        if let profile = content.petDetails[pet.petId]?.worldProfile {
            let rows = [("精灵类别", profile["type_desc"]), ("栖息描述", profile["description_habitat"]), ("简介", profile["introduction"])]
                .compactMap { label, value -> (String, String)? in
                    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                    return (label, value)
                }
            if !rows.isEmpty {
                detailCard("精灵资料") {
                    ForEach(rows, id: \.0) { label, value in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(label).font(.subheadline).foregroundStyle(.secondary)
                            Text(value)
                        }
                    }
                }
            }
        }
    }

    private func relatedPets(_ ids: [PetID]) -> [Pet] {
        var seen: Set<PetID> = []
        return ids.compactMap { id in
            guard seen.insert(id).inserted, let related = content.pets[id], related.publicVisible else { return nil }
            return related
        }
    }

    private func relatedRow(_ related: Pet) -> some View {
        RelatedPetRow(pet: related, portraits: portraits, anchors: relatedAnchors, open: openRelated)
    }

    private func detailValue(_ label: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).foregroundStyle(.secondary)
                Spacer(minLength: 16)
                Text(value).monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(label).foregroundStyle(.secondary)
                Text(value).monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
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
        .disabled(open == nil || image == nil)
        .task {
            guard image == nil, let portraits else { return }
            do { image = try portraits.image(for: pet) }
            catch { imageFailed = true }
        }
    }
}
