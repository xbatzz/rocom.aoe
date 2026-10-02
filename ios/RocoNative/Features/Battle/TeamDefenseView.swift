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
    private struct Report {
        let analysis: TeamDefense.Analysis
        let positions: [Int]
        let unresolved: [Int]
    }
    var body: some View {
        List {
            Picker("分析队伍", selection: $selected) {
                Text("请选择").tag(nil as UUID?)
                ForEach(teams) { Text($0.name).tag(Optional($0.teamID)) }
            }
            if let selected {
                switch report(selected) {
                case .success(let report):
                    Section("按对手本系中最强属性判断") {
                        LabeledContent("弱点 / 中性 / 抵抗", value: "\(report.analysis.weakCount) / \(report.analysis.neutralCount) / \(report.analysis.resistCount)")
                        Text(report.analysis.hasSafeSwitch ? "存在属性抵抗的换人候选" : "没有属性抵抗的换人候选")
                        if report.analysis.pierceRisk { Text("按 Web 规则存在穿透风险").foregroundStyle(.orange) }
                        LabeledContent("Web 威胁分", value: report.analysis.score.formatted())
                    }
                    Section("候选槽位") {
                        ForEach(report.analysis.slots, id: \.index) { slot in
                            if let pet = content.pets[slot.petID], let type = content.types[slot.attackTypeID] {
                                LabeledContent("槽 \(report.positions[slot.index] + 1) · \(pet.nameZh)", value: "\(type.nameZh) \(slot.multiplier.formatted())×")
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
        }.navigationTitle("基础联防")
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
            return Report(analysis: try TeamDefense.analyze(attacker: BattleCore.pet(opponent, content: content), candidates: pets, content: content), positions: positions, unresolved: unresolved)
        }
    }
}
