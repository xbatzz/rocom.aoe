import SwiftUI
import UIKit
import SwiftData
import RocoUserData
import RocoContent
import RocoDomain

struct PVPBattleView: View {
    let content: ContentStore
    let portraits: PortraitStore
    let skillIndex: SkillSearchIndex
    private enum Section: String, CaseIterable {
        case build = "双方构筑"
        case comparison = "能力比较"
        case analysis = "对战分析"
    }
    @State private var section = Section.build
    @State private var choosingTeam = false
    @State private var reset = false
    @State private var initialized = false
    @Query(sort: \TeamRecord.updatedAt, order: .reverse) private var teams: [TeamRecord]
    @Query private var preferences: [UserPreferences]
    @State private var ally = BattleProfile()
    @State private var opponent = BattleProfile()
    init(content: ContentStore, portraits: PortraitStore, skillIndex: SkillSearchIndex) {
        self.content = content; self.portraits = portraits; self.skillIndex = skillIndex
        #if DEBUG
        if VisualReview.route == "pvp-filled" {
            let pets = content.orderedPets.filter { $0.implemented && $0.publicVisible && !$0.isLeader && $0.form == "default" }
            if pets.count >= 2, let firstSlot = try? TeamRules.assign(pets[0], content: content), let secondSlot = try? TeamRules.assign(pets[1], content: content) {
                var first = BattleProfile(); first.slot = firstSlot
                var second = BattleProfile(); second.slot = secondSlot
                _ally = State(initialValue: first); _opponent = State(initialValue: second)
            }
        }
        #endif
    }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        CompanionTabbedPage(title: "PVP 分区", selection: $section, options: Section.allCases, identifier: "pvp-tabs") {
            CompanionPageHeader(title: "PVP 助手", identifier: "pvp")
            if section == .build {
                CompanionHeading(title: "对战构筑", detail: "临时计算")
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) { allyCard; versus; opponentCard }
                } else {
                    HStack(alignment: .top, spacing: 8) { allyCard; versus.padding(.top, 68); opponentCard }
                }
                Button("从已保存队伍选择我方", systemImage: "person.3") { choosingTeam = true }
                    .buttonStyle(.bordered).controlSize(.large).tint(.primary)
                if !isReady {
                    CompanionSection("准备一次对战") {
                        preparationStep("01", title: "选择双方精灵", detail: "点按上方槽位，配置性格、血脉与技能。")
                        Divider()
                        preparationStep("02", title: "比较六维与属性", detail: "切换到能力比较，确认速度优势。")
                        Divider()
                        preparationStep("03", title: "计算伤害与一击线", detail: "切换到对战分析，按实际条件查看纸面结果。")
                    }
                }
            } else if isReady {
                CompanionHeading(title: "\(name(ally)) / \(name(opponent))", detail: "我方 / 对方")
                Button("调整双方构筑", systemImage: "slider.horizontal.3") { section = .build }
                    .buttonStyle(.bordered).tint(.primary)
                if section == .comparison {
                    comparisons
                } else {
                    analysisSection
                }
            } else {
                ContentUnavailableView {
                    Label("先选择双方精灵", systemImage: "person.2")
                } description: {
                    Text("配置我方与对方后，即可比较能力、计算伤害和查看队伍联防。")
                } actions: {
                    Button("选择双方精灵") { section = .build }.companionPrimaryAction()
                }
            }
            Text("临时构筑不会更改已保存队伍。伤害沿用当前规则的纸面估算。")
                .font(.footnote).foregroundStyle(.secondary)
        }.companionPageChrome(identifier: "pvp", makeMenu: makeActionMenu,
            menuLabel: "对战操作", menuSymbol: "ellipsis")
            .task {
                guard !initialized else { return }; initialized = true
                if ally.slot.petID == nil, let team = (teams.first { $0.teamID == preferences.first?.activeTeamID } ?? teams.first),
                    let build = try? team.decode(), let slot = build.slots.first(where: { $0.petID != nil }) { ally.slot = slot }
            }
            .confirmationDialog("重置双方临时构筑？", isPresented: $reset, titleVisibility: .visible) {
                Button("重置全部", role: .destructive) { ally = BattleProfile(); opponent = BattleProfile(); section = .build }
            }
            .sheet(isPresented: $choosingTeam) {
                BattleTeamPicker(content: content) { slot in
                    var profile = BattleProfile(); profile.slot = slot; ally = profile
                }
            }
    }
    private func makeActionMenu() -> UIMenu {
        let ally = $ally
        let opponent = $opponent
        let reset = $reset
        return UIMenu(children: [
            UIAction(title: "交换双方", image: UIImage(systemName: "arrow.left.arrow.right"),
                attributes: ally.wrappedValue.slot.petID == nil && opponent.wrappedValue.slot.petID == nil ? [.disabled] : []) { _ in
                let previous = ally.wrappedValue
                ally.wrappedValue = opponent.wrappedValue
                opponent.wrappedValue = previous
            },
            UIAction(title: "重置", image: UIImage(systemName: "arrow.counterclockwise")) { _ in
                reset.wrappedValue = true
            }
        ])
    }

    private var isReady: Bool { ally.slot.petID != nil && opponent.slot.petID != nil }
    private var analysisSection: some View {
        CompanionSection("对战分析") {
            NavigationLink {
                BattleDirectionView(attacker: ally, defender: opponent, content: content, portraits: portraits, skillIndex: skillIndex).id(ally.slot.petID)
            } label: { analysisLink("我方 → 对方", detail: "伤害与一击线", tint: .orange) }
            NavigationLink {
                BattleDirectionView(attacker: opponent, defender: ally, content: content, portraits: portraits, skillIndex: skillIndex).id(opponent.slot.petID)
            } label: { analysisLink("对方 → 我方", detail: "伤害与一击线", tint: .purple) }
            NavigationLink { TeamDefenseView(opponent: opponent, content: content) } label: {
                analysisLink("已保存队伍联防", detail: "对方本系的进攻覆盖", tint: .primary)
            }
        }.buttonStyle(.plain)
    }
    private var versus: some View { Text("VS").font(.headline.bold()).foregroundStyle(.secondary).accessibilityHidden(true) }
    private var allyCard: some View {
        NavigationLink { BattleProfileEditor(profile: $ally, content: content, portraits: portraits, skillIndex: skillIndex, purpose: .battle) } label: {
            TeamPetTile(slot: ally.slot, content: content, label: "我方")
        }.buttonStyle(.plain)
    }
    private var opponentCard: some View {
        NavigationLink { BattleProfileEditor(profile: $opponent, content: content, portraits: portraits, skillIndex: skillIndex, purpose: .battle) } label: {
            TeamPetTile(slot: opponent.slot, content: content, label: "对方")
        }.buttonStyle(.plain)
    }
    private func analysisLink(_ title: String, detail: String, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline).foregroundStyle(tint)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.right").foregroundStyle(tint)
        }.padding(18).companionSurface()
    }
    private func preparationStep(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number).font(.title2.bold().monospacedDigit()).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }

    private func name(_ profile: BattleProfile) -> String {
        guard let id = profile.slot.petID else { return "未选择" }
        return content.pets[PetID(rawValue: id)]?.nameZh ?? "无法解析 #\(id)"
    }
    private func speedReferences(_ pet: Pet) -> [(String, Int)] {
        let personalities = content.personalities.values.sorted { $0.personalityId.rawValue < $1.personalityId.rawValue }
        let up = personalities.first { $0.modifiers.speed.rawValue > 0 }
        let down = personalities.first { $0.modifiers.speed.rawValue < 0 }
        var full = Array(repeating: 0, count: 6); full[5] = 10
        return [("满速", full, up), ("满个体", full, nil), ("无速", Array(repeating: 0, count: 6), nil), ("减速", Array(repeating: 0, count: 6), down)].compactMap { label, iv, nature in
            (try? BattleStatsCalculator.calculate(pet: pet, individuals: iv, personality: nature)).map { (label, $0[5]) }
        }
    }
    @ViewBuilder private var comparisons: some View {
        switch Result(catching: { (try BattleCore.stats(ally, content: content), try BattleCore.stats(opponent, content: content)) }) {
        case .success(let values):
            CompanionSection("速度比较") {
                LabeledContent("我方 − 对方", value: String(values.0[5] - values.1[5]))
                if let pet = try? BattleCore.pet(opponent, content: content) {
                    ForEach(speedReferences(pet), id: \.0) { label, speed in
                        LabeledContent("对方\(label)", value: "\(speed) · 差 \(values.0[5] - speed)")
                    }
                }
            }
            DisclosureGroup("双方资料与配置") {
                CompanionSection("我方") { BattleProfileFacts(profile: ally, content: content) }
                CompanionSection("对方") { BattleProfileFacts(profile: opponent, content: content) }
            }.tint(.primary)
            CompanionSection("六维比较 · 我方 / 对方") {
                VStack(spacing: 16) {
                    ForEach(BattleStat.allCases, id: \.self) { stat in
                        let left = values.0[stat.rawValue], right = values.1[stat.rawValue]
                        Group {
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(stat.label).font(.headline)
                                    HStack { Text("我方").font(.caption); Spacer(); Text(String(left)).font(.title3.bold().monospacedDigit()).foregroundStyle(.orange) }
                                    HStack { Text("对方").font(.caption); Spacer(); Text(String(right)).font(.title3.bold().monospacedDigit()).foregroundStyle(.purple) }
                                }
                            } else {
                                HStack(spacing: 12) {
                                    Text(String(left)).font(.headline.monospacedDigit()).foregroundStyle(left > right ? .orange : .primary).frame(minWidth: 36)
                                    GeometryReader { g in
                                        HStack(spacing: 2) {
                                            Capsule().fill(Color.orange.opacity(0.7)).frame(width: max(2, g.size.width * CGFloat(left) / CGFloat(max(1, left + right))))
                                            Capsule().fill(Color.purple.opacity(0.5))
                                        }
                                    }.frame(height: 5).accessibilityHidden(true)
                                    Text(stat.label).font(.caption.weight(.medium)).frame(minWidth: 28)
                                    Text(String(right)).font(.headline.monospacedDigit()).foregroundStyle(right > left ? .purple : .primary).frame(minWidth: 36)
                                }.accessibilityElement(children: .ignore).accessibilityLabel("\(stat.label)，我方 \(left)，对方 \(right)")
                            }
                        }.accessibilityElement(children: .ignore).accessibilityLabel("\(stat.label)，我方 \(left)，对方 \(right)")
                    }
                }.padding(20).companionSurface()
            }
        case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
        }
    }
}

private struct BattleProfileEditor: View {
    @Binding var profile: BattleProfile
    let content: ContentStore
    let portraits: PortraitStore
    let skillIndex: SkillSearchIndex
    var purpose: PetPickerPurpose = .battle
    var body: some View {
        Form {
            NavigationLink("精灵、性格、个体值、血脉与技能") { TeamSlotView(slot: $profile.slot, content: content, portraits: portraits, skillIndex: skillIndex, purpose: purpose) }
            Section("生命快捷值") {
                HStack { ForEach([100, 75, 50, 25, 1], id: \.self) { value in Button("\(value)%") { profile.hpPercent = value } } }
                LabeledContent("直接输入百分比") { TextField("0–100", value: $profile.hpPercent, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    .onChange(of: profile.hpPercent) { profile.hpPercent = min(100, max(0, profile.hpPercent)) }
                if let values = try? BattleCore.stats(profile, content: content) {
                    LabeledContent("当前生命 / 最大生命", value: "\(Int((Double(values[0]) * Double(profile.hpPercent) / 100).rounded())) / \(values[0])")
                }
            }
            BattleProfileFacts(profile: profile, content: content)
            Stepper("当前生命：\(profile.hpPercent)%", value: $profile.hpPercent, in: 0...100)
            if profile.slot.petID == 3400 {
                Picker("陨星之仔捕捉球", selection: $profile.meteorBall) {
                    ForEach(MeteorBall.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Text("遵循当前规则，仅将捕捉球的速度修正计入本工具。棱镜球的随机效果不作确定性推断。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text("此页为临时构筑，离开 PVP 入口后不保存。技能伤害可选当前配置的技能池、技能石和各血脉技能。")
                .font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("临时构筑")
    }
}

struct BattleDirectionView: View {
    let attacker: BattleProfile
    let defender: BattleProfile
    let content: ContentStore
    let portraits: PortraitStore
    let skillIndex: SkillSearchIndex
    private enum Section: String, CaseIterable {
        case damage = "伤害计算"
        case types = "属性关系"
        case oneHit = "一击线"
    }
    @State private var section = Section.damage
    @State private var selected: SkillID?
    @State private var settings = DamageSettings()
    @State private var skillSearch = ""
    @State private var skillGroup = 0
    init(attacker: BattleProfile, defender: BattleProfile, content: ContentStore, portraits: PortraitStore, skillIndex: SkillSearchIndex) {
        self.attacker = attacker; self.defender = defender; self.content = content; self.portraits = portraits; self.skillIndex = skillIndex
        #if DEBUG
        if VisualReview.route == "damage", let skills = try? BattleCore.calculableSkills(attacker, content: content) {
            _selected = State(initialValue: skills.first?.skillId)
        }
        #endif
    }
    private var skill: Skill? { selected.flatMap { content.skills[$0] } }
    var body: some View {
        CompanionTabbedPage(title: "对战计算", selection: $section, options: Section.allCases, identifier: "damage-tabs") {
            if section == .damage {
                CompanionSection("伤害技能") {
                    switch Result(catching: { try BattleCore.calculableSkills(attacker, content: content) }) {
                    case .success(let skills):
                        TextField("技能名称、描述或 ID", text: $skillSearch)
                        Picker("选招范围", selection: $skillGroup) {
                            Text("全部攻击").tag(0); Text("已配招").tag(1); Text("推荐").tag(2)
                        }.pickerStyle(.segmented)
                        let recommended = (try? TeamRules.recommended(attacker.slot, content: content)) ?? []
                        let filtered = skills.filter { (skillGroup == 0 || (skillGroup == 1 ? attacker.slot.skillIDs : recommended).contains($0.skillId.rawValue)) && (skillSearch.isEmpty || "\($0.nameZh) \($0.description) \($0.skillId.rawValue)".localizedStandardContains(skillSearch)) }
                        if filtered.isEmpty { Text("没有符合条件的固定威力攻击").foregroundStyle(.secondary) }
                        Menu {
                            Picker("固定威力攻击", selection: $selected) {
                                Text("请选择").tag(nil as SkillID?)
                                ForEach(filtered, id: \.skillId) { Text("\($0.nameZh) #\(String($0.skillId.rawValue))").tag(Optional($0.skillId)) }
                            }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(skill.map { "\($0.nameZh) #\(String($0.skillId.rawValue))" } ?? "选择固定威力攻击")
                                    .font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                            }.frame(minHeight: 44)
                        }.tint(.primary).accessibilityLabel("选择固定威力攻击技能")
                            .accessibilityValue(skill.map { "\($0.nameZh) #\($0.skillId.rawValue)" } ?? "未选择")
                    case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
                    }
                }
                if let skill {
                    CompanionSection("技能资料") {
                        NavigationLink { SkillDetailView(skill: skill, content: content, portraits: portraits, index: skillIndex) } label: {
                            SkillSummary(skill: skill, content: content)
                        }.buttonStyle(.plain)
                    }
                    damageResult(skill)
                    effectControls(skill)
                } else {
                    Text("选择固定威力攻击技能，查看纸面伤害。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } else if section == .types {
                typeRelations
            } else {
                oneHitLines
            }
        }.navigationTitle("伤害与一击线")
            .onChange(of: selected) { settings = DamageSettings() }
    }
    @ViewBuilder private var typeRelations: some View {
        CompanionSection("攻击方技能属性 → 防守方承伤") {
            switch Result(catching: {
                let attack = try BattleCore.pet(attacker, content: content)
                let target = try BattleCore.pet(defender, content: content)
                let engine = TypeMatchup(types: content.types)
                return try attack.typeIds.map { ($0, try engine.defense(attack: $0, defenders: target.typeIds)) }
            }) {
            case .success(let rows):
                ForEach(rows, id: \.0) { id, multiplier in
                    if let type = content.types[id] {
                        HStack { TypeBadge(type: type); Spacer(); Text("\(multiplier.formatted())×").font(.title2.bold().monospacedDigit()) }
                    }
                }
            case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
            }
        }
    }
    @ViewBuilder private var oneHitLines: some View {
        CompanionSection("基础纸面一击威力线 · 目标生命 \(defender.hpPercent)%") {
            switch Result(catching: { try BattleCore.oneHitLines(attacker: attacker, defender: defender, content: content) }) {
            case .success(let lines):
                ForEach(lines.indices, id: \.self) { i in
                    let line = lines[i]
                    LabeledContent(line.label) {
                        if let power = line.requiredPower, let id = line.typeID, let type = content.types[id] {
                            Text("\(type.nameZh) · \(power)")
                        } else { Text("无可用一击线").foregroundStyle(.secondary) }
                    }
                }
                Text("按攻击偏好选择物理/魔法，范围 1–5000。此处遵循基础一击线，不加入所选技能条件、虫群奉献或爆燃层数。")
                    .font(.footnote).foregroundStyle(.secondary)
            case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
            }
        }
    }
    @ViewBuilder private func effectControls(_ skill: Skill) -> some View {
        CompanionSection("技能与条件") {
            if !skill.description.isEmpty {
                DisclosureGroup("技能说明") {
                    Text(skill.description).font(.subheadline).foregroundStyle(.secondary)
                }.tint(.primary)
            }
            let choices = BattleCore.choices(skill)
            if !choices.isEmpty {
                Picker("技能选项", selection: $settings.choiceIndex) {
                    ForEach(choices.indices, id: \.self) { Text(choices[$0].label).tag($0) }
                }
                if choices.indices.contains(settings.choiceIndex) {
                    let choice = choices[settings.choiceIndex]
                    Text(choice.description)
                    if choice.threshold != nil { Text(choice.enabled(hpPercent: attacker.hpPercent) ? "生命条件已满足" : "生命条件未满足") }
                    else if choice.assumesTrigger { Text("按该选项触发条件已满足估算。请确认所述条件成立。").foregroundStyle(.secondary) }
                }
            }
            if BattleCore.isSwarm(skill) {
                Stepper("威力奉献：\(settings.swarmPowerCount)（每次 +20）", value: $settings.swarmPowerCount, in: 0...20)
                Stepper("连击奉献：\(settings.swarmHitCount)（每次 +1 击）", value: $settings.swarmHitCount, in: 0...20)
            }
            if attacker.slot.petID == 5017 {
                Stepper("爆燃：\(settings.blazingStage) 层 · 双攻 +\(settings.blazingStage * 10)%", onIncrement: {
                    settings.blazingStage += 3
                }, onDecrement: { settings.blazingStage = max(0, settings.blazingStage - 3) })
            }
        }
    }
    @ViewBuilder private func damageResult(_ skill: Skill) -> some View {
        CompanionSection("纸面伤害") {
            switch Result(catching: { try BattleCore.damage(attacker: attacker, defender: defender, skill: skill, settings: settings, content: content) }) {
            case .success(let result):
                CompanionMetrics {
                    CompanionMetric(value: String(result.total), label: "总伤害", tint: .orange)
                    CompanionMetric(value: "\(result.hpPercent.formatted())%", label: "目标最大生命占比")
                }.padding(20).companionAccentSurface(tint: .orange)
                DisclosureGroup("计算明细") {
                    VStack(spacing: 12) {
                        LabeledContent("属性倍率") { Text("\(result.typeMultiplier.formatted())×").font(.headline.monospacedDigit()).foregroundStyle(.primary) }
                        LabeledContent("本系倍率") { Text("\(result.stabMultiplier.formatted())×").font(.headline.monospacedDigit()).foregroundStyle(.primary) }
                        LabeledContent("显示威力") { Text(String(result.displayPower)).font(.headline.monospacedDigit()).foregroundStyle(.primary) }
                        LabeledContent("单击 / 总伤害") { Text("\(result.singleHit) / \(result.total)").font(.headline.monospacedDigit()).foregroundStyle(.primary) }
                        LabeledContent("目标最大生命占比") { Text("\(result.hpPercent.formatted())%").font(.headline.monospacedDigit()).foregroundStyle(.primary) }
                        LabeledContent("按最大生命击倒次数") { Text(String(result.hitsToKO)).font(.headline.monospacedDigit()).foregroundStyle(.primary) }
                    }.padding(.top, 12)
                }.tint(.primary)
                Text("这是当前规则的纸面估算，不包含完整回合、减伤、护盾、随机或未建模效果。")
                    .font(.footnote).foregroundStyle(.secondary)
            case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
            }
        }
    }
}

/// Copy a saved slot into the temporary profile. Never normalize or write the source record.
private struct BattleTeamPicker: View {
    let content: ContentStore
    let select: (TeamSlot) -> Void
    @Query(sort: \TeamRecord.updatedAt, order: .reverse) private var teams: [TeamRecord]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if teams.isEmpty {
                    ContentUnavailableView("暂无已保存队伍", systemImage: "person.3", description: Text("先在配队中保存队伍，或使用 PVP 的临时构筑。"))
                }
                ForEach(teams) { record in
                    Section(record.name) {
                        switch Result(catching: { try record.decode() }) {
                        case .success(let build):
                            ForEach(build.slots.indices, id: \.self) { i in
                                let slot = build.slots[i]
                                if let id = slot.petID {
                                    Button {
                                        select(slot); dismiss()
                                    } label: {
                                        LabeledContent("槽位 \(i + 1)") { Text(content.pets[PetID(rawValue: id)]?.nameZh ?? "无法解析 #\(id)").font(.headline.monospacedDigit()).foregroundStyle(.primary) }
                                    }
                                } else { Text("槽位 \(i + 1) · 空槽").foregroundStyle(.secondary) }
                            }
                        case .failure(let error): Text("队伍读取失败，原数据保留：\(String(describing: error))").foregroundStyle(.red)
                        }
                    }
                }
            }.navigationTitle("选择已保存构筑")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}

struct BattleProfileFacts: View {
    let profile: BattleProfile
    let content: ContentStore
    var body: some View {
        if let pet = try? BattleCore.pet(profile, content: content) {
            VStack(alignment: .leading, spacing: 8) {
                Text(pet.nameZh + (pet.isLeader ? " · 首领" : "")).font(.headline)
                PetTypes(pet: pet, content: content)
                Text("种族值 HP \(pet.baseStats.hp) / 物攻 \(pet.baseStats.physicalAttack) / 魔攻 \(pet.baseStats.magicalAttack) / 物防 \(pet.baseStats.physicalDefense) / 魔防 \(pet.baseStats.magicalDefense) / 速度 \(pet.baseStats.speed)").font(.subheadline)
                Text("性格：" + (profile.slot.personalityID.flatMap { content.personalities[PersonalityID(rawValue: $0)]?.nameZh } ?? "无修正"))
                Text("个体值：" + profile.slot.individualValues.map(String.init).joined(separator: " / "))
                Text("血脉：" + (profile.slot.legacyTypeID.flatMap { content.types[TypeID(rawValue: $0)]?.nameZh } ?? "无"))
                Text("技能：" + profile.slot.skillIDs.map { content.skills[SkillID(rawValue: $0)]?.nameZh ?? "#\($0)" }.joined(separator: "、"))
                if let traitID = content.petDetails[pet.petId]?.traitId, let trait = content.traits[traitID] {
                    Text(trait.nameZh).font(.headline); Text(trait.description).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }
}
