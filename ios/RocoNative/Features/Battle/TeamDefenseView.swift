import SwiftUI
import SwiftData
import RocoDomain
import RocoContent
import RocoUserData

struct TeamDefenseView: View {
    let opponent: BattleProfile
    let content: ContentStore
    @Query(sort: \TeamRecord.updatedAt, order: .reverse) private var teams: [TeamRecord]
    @State private var selected: UUID?
    @State private var attackType: TypeID?
    @Query private var preferences: [UserPreferences]
    private struct Report {
        let analysis: TeamDefense.Analysis
        let positions: [Int]
        let unresolved: [Int]
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
            Picker("分析队伍", selection: $selected) {
                Text("请选择").tag(nil as UUID?)
                ForEach(teams) { Text($0.name).tag(Optional($0.teamID)) }
            }.pickerStyle(.menu).tint(.primary)
            Picker("攻击属性", selection: $attackType) {
                Text("综合 · 对手本系最强").tag(nil as TypeID?)
                ForEach(TypeMatchup(types: content.types).selectable, id: \.typeId) { Text($0.nameZh).tag(Optional($0.typeId)) }
            }.pickerStyle(.menu).tint(.primary)
            if let selected {
                switch report(selected) {
                case .success(let report):
                    CompanionSection(attackType == nil ? "按对手本系中最强属性判断" : "指定属性抵抗候选") {
                        CompanionMetrics {
                            CompanionMetric(value: String(report.analysis.weakCount), label: "弱点", tint: .orange)
                            CompanionMetric(value: String(report.analysis.neutralCount), label: "中性")
                            CompanionMetric(value: String(report.analysis.resistCount), label: "抵抗", tint: .teal)
                        }.padding(20).companionSurface()
                        Text(report.analysis.hasSafeSwitch ? "存在属性抵抗的换人候选" : "没有属性抵抗的换人候选")
                        if report.analysis.pierceRisk { Text("存在属性穿透风险").foregroundStyle(.orange) }
                        LabeledContent("威胁分", value: report.analysis.score.formatted())
                    }
                    CompanionSection("候选槽位") {
                        ForEach(report.analysis.slots, id: \.index) { slot in
                            if let pet = content.pets[slot.petID], let type = content.types[slot.attackTypeID] {
                                HStack(spacing: 14) {
                                    CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 64)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("槽 \(report.positions[slot.index] + 1) · \(pet.nameZh)").font(.headline)
                                        TypeBadge(type: type)
                                    }
                                    Spacer()
                                    Text("\(slot.multiplier.formatted())×").font(.title2.bold().monospacedDigit())
                                        .foregroundStyle(slot.multiplier > 1 ? .orange : slot.multiplier < 1 ? .teal : .primary)
                                }
                            }
                        }
                    }
                    if !report.unresolved.isEmpty {
                        Text("无法解析的槽位 \(report.unresolved.map { String($0 + 1) }.joined(separator: "、")) 未参与计算，构筑数据完整保留。")
                    }
                    Text("仅属性联防；不证明换入安全，不模拟技能、状态或回合。重复精灵按独立槽位分析。").font(.footnote).foregroundStyle(.secondary)
                case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
                }
            } else if teams.isEmpty {
                ContentUnavailableView("尚无保存队伍", systemImage: "person.3", description: Text("先在配队中保存一支队伍。"))
            }
            }.padding(20)
        }.reviewScrollPosition().companionBackground().navigationTitle("基础联防")
            .task {
                selected = teams.first { $0.teamID == preferences.first?.activeTeamID }?.teamID ?? teams.first?.teamID
                #if DEBUG
                if VisualReview.route == "defense" { selected = teams.first?.teamID }
                #endif
            }
    }
    private func report(_ id: UUID) -> Result<Report, Error> {
        Result {
            guard let record = teams.first(where: { $0.teamID == id }) else { throw ContentError.invalid("队伍不存在") }
            let build = try record.decode()
            var pets: [Pet] = [], positions: [Int] = [], unresolved: [Int] = []
            for (i, slot) in build.slots.enumerated() {
                guard let id = slot.petID else { continue }
                if let pet = content.pets[PetID(rawValue: id)] { pets.append(pet); positions.append(i) }
                else { unresolved.append(i) }
            }
            return Report(analysis: try TeamDefense.analyze(attacker: BattleCore.pet(opponent, content: content), candidates: pets, content: content, attackType: attackType), positions: positions, unresolved: unresolved)
        }
    }
}
