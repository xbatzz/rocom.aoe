import SwiftUI
import RocoContent
import RocoDomain

struct PVPBattleView: View {
    let content: ContentStore
    let portraits: PortraitStore
    let skillIndex: SkillSearchIndex
    @State private var ally = BattleProfile()
    @State private var opponent = BattleProfile()
    var body: some View {
        List {
            Section("临时构筑 · 不改已保存队伍") {
                NavigationLink("我方：\(name(ally))") { BattleProfileEditor(profile: $ally, content: content, portraits: portraits, skillIndex: skillIndex) }
                NavigationLink("对方：\(name(opponent))") { BattleProfileEditor(profile: $opponent, content: content, portraits: portraits, skillIndex: skillIndex) }
            }
            if ally.slot.petID != nil && opponent.slot.petID != nil {
                comparisons
                NavigationLink("对方本系 → 已保存队伍联防") { TeamDefenseView(opponent: opponent, content: content) }
                NavigationLink("我方 → 对方：伤害与一击线") {
                    BattleDirectionView(attacker: ally, defender: opponent, content: content, portraits: portraits, skillIndex: skillIndex).id(ally.slot.petID)
                }
                NavigationLink("对方 → 我方：伤害与一击线") {
                    BattleDirectionView(attacker: opponent, defender: ally, content: content, portraits: portraits, skillIndex: skillIndex).id(opponent.slot.petID)
                }
            } else { Text("选择双方精灵后查看六维、属性关系和双向伤害。") }
        }.navigationTitle("PVP 助手")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("交换双方", systemImage: "arrow.left.arrow.right") {
                        let previous = ally; ally = opponent; opponent = previous
                    }.disabled(ally.slot.petID == nil && opponent.slot.petID == nil)
                }
            }
    }
    private func name(_ profile: BattleProfile) -> String {
        guard let id = profile.slot.petID else { return "未选择" }
        return content.pets[PetID(rawValue: id)]?.nameZh ?? "无法解析 #\(id)"
    }
    @ViewBuilder private var comparisons: some View {
        switch Result(catching: { (try BattleCore.stats(ally, content: content), try BattleCore.stats(opponent, content: content)) }) {
        case .success(let values):
            Section("六维 · 我方 / 对方") {
                ForEach(BattleStat.allCases, id: \.self) {
                    LabeledContent($0.label, value: "\(values.0[$0.rawValue]) / \(values.1[$0.rawValue])")
                }
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
    var body: some View {
        Form {
            NavigationLink("精灵、性格、个体值、血脉与技能") { TeamSlotView(slot: $profile.slot, content: content, portraits: portraits, skillIndex: skillIndex) }
            Stepper("当前生命：\(profile.hpPercent)%", value: $profile.hpPercent, in: 0...100)
            if profile.slot.petID == 3400 {
                Picker("陨星之仔捕捉球", selection: $profile.meteorBall) {
                    ForEach(MeteorBall.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Text("遵循 Web 规则，仅将捕捉球的速度修正计入本工具。棱镜球的随机效果不作确定性推断。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text("此页为临时构筑，离开 PVP 入口后不保存。技能伤害可选当前配置的技能池、技能石和各血脉技能。")
                .font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("临时构筑")
    }
}

private struct BattleDirectionView: View {
    let attacker: BattleProfile
    let defender: BattleProfile
    let content: ContentStore
    let portraits: PortraitStore
    let skillIndex: SkillSearchIndex
    @State private var selected: SkillID?
    @State private var settings = DamageSettings()
    private var skill: Skill? { selected.flatMap { content.skills[$0] } }
    var body: some View {
        List {
            typeRelations
            oneHitLines
            Section("伤害技能") {
                switch Result(catching: { try BattleCore.calculableSkills(attacker, content: content) }) {
                case .success(let skills):
                    Picker("固定威力攻击", selection: $selected) {
                        Text("请选择").tag(nil as SkillID?)
                        ForEach(skills, id: \.skillId) { Text("\($0.nameZh) #\($0.skillId.rawValue)").tag(Optional($0.skillId)) }
                    }
                case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
                }
            }
            if let skill {
                Section("技能资料") {
                    NavigationLink(skill.nameZh) { SkillDetailView(skill: skill, content: content, portraits: portraits, index: skillIndex) }
                }
                effectControls(skill)
                damageResult(skill)
            }
        }.navigationTitle("伤害与一击线")
            .onChange(of: selected) { settings = DamageSettings() }
    }
    @ViewBuilder private var typeRelations: some View {
        Section("攻击方技能属性 → 防守方承伤") {
            switch Result(catching: {
                let attack = try BattleCore.pet(attacker, content: content)
                let target = try BattleCore.pet(defender, content: content)
                let engine = TypeMatchup(types: content.types)
                return try attack.typeIds.map { ($0, try engine.defense(attack: $0, defenders: target.typeIds)) }
            }) {
            case .success(let rows):
                ForEach(rows, id: \.0) { id, multiplier in
                    if let type = content.types[id] { LabeledContent(type.nameZh, value: "\(multiplier.formatted())×") }
                }
            case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
            }
        }
    }
    @ViewBuilder private var oneHitLines: some View {
        Section("基础纸面一击威力线 · 目标生命 \(defender.hpPercent)%") {
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
                Text("按攻击偏好选择物理/魔法，范围 1–5000。此处遵循 Web 基础一击线，不加入所选技能条件、虫群奉献或爆燃层数。")
                    .font(.footnote).foregroundStyle(.secondary)
            case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
            }
        }
    }
    @ViewBuilder private func effectControls(_ skill: Skill) -> some View {
        Section("技能与条件") {
            Text(skill.description)
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
        Section("纸面伤害") {
            switch Result(catching: { try BattleCore.damage(attacker: attacker, defender: defender, skill: skill, settings: settings, content: content) }) {
            case .success(let result):
                LabeledContent("属性倍率", value: "\(result.typeMultiplier.formatted())×")
                LabeledContent("本系倍率", value: "\(result.stabMultiplier.formatted())×")
                LabeledContent("显示威力", value: String(result.displayPower))
                LabeledContent("单击 / 总伤害", value: "\(result.singleHit) / \(result.total)")
                LabeledContent("目标最大生命占比", value: "\(result.hpPercent.formatted())%")
                LabeledContent("按最大生命击倒次数", value: String(result.hitsToKO))
                Text("这是当前 Web 公式的纸面估算，不包含完整回合、减伤、护盾、随机或未建模效果。")
                    .font(.footnote).foregroundStyle(.secondary)
            case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
            }
        }
    }
}
