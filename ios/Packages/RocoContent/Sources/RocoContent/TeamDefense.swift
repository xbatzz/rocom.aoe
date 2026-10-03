import RocoDomain

/// Source: teamAnalysis.ts buildThreatEntry/getTypeRelationNet/getTypeMultiplier.
/// Slot identity is its position; duplicate pets must remain independent candidates.
public enum TeamDefense {
    public struct Slot: Sendable {
        public let index: Int
        public let petID: PetID
        public let attackTypeID: TypeID
        public let net: Int
        public let multiplier: Double
    }
    public struct Analysis: Sendable {
        public let slots: [Slot]
        public let weakCount: Int
        public let neutralCount: Int
        public let resistCount: Int
        public let hasSafeSwitch: Bool
        public let pierceRisk: Bool
        public let score: Double
    }
    public static func analyze(attacker: Pet, candidates: [Pet], content: ContentStore, attackType: TypeID? = nil) throws -> Analysis {
        guard !candidates.isEmpty, !attacker.typeIds.isEmpty else { throw ContentError.invalid("请选择对手和非空队伍") }
        if let attackType, content.types[attackType]?.normalBattleType != true { throw ContentError.invalid("请选择普通攻击属性") }
        let slots = try candidates.enumerated().map { index, defender in
            var best: (TypeID, Int)?
            for attack in attackType.map({ [$0] }) ?? attacker.typeIds {
                var net = 0
                for type in defender.typeIds {
                    guard let details = content.types[type], content.types[attack] != nil else { throw ContentError.invalid("联防属性无法解析") }
                    if details.weakToTypeIds.contains(attack) { net += 1 }
                    else if details.resistToTypeIds.contains(attack) { net -= 1 }
                }
                if let previous = best {
                    if net > previous.1 { best = (attack, net) }
                } else { best = (attack, net) }
            }
            guard let (type, net) = best else { throw ContentError.invalid("无攻击属性") }
            let multiplier: Double = net >= 2 ? 3 : net == 1 ? 2 : net == 0 ? 1 : net == -1 ? 0.5 : 0.25
            return Slot(index: index, petID: defender.petId, attackTypeID: type, net: net, multiplier: multiplier)
        }
        let weak = slots.filter { $0.net > 0 }.count
        let neutral = slots.filter { $0.net == 0 }.count
        let resist = slots.filter { $0.net < 0 }.count
        let safe = resist > 0
        let pierce = !safe && (weak >= 2 || neutral == candidates.count)
        let b = attacker.baseStats
        let total = b.hp + b.physicalAttack + b.magicalAttack + b.physicalDefense + b.magicalDefense + b.speed
        let score = Double(weak * 8 + neutral * 3 - resist * 6) + Double(b.speed) * 0.04 + Double(total) * 0.02 + (pierce ? 18 : 0)
        let orderedSlots = attackType == nil ? slots : slots.sorted { $0.multiplier == $1.multiplier ? $0.index < $1.index : $0.multiplier < $1.multiplier }
        return Analysis(slots: orderedSlots, weakCount: weak, neutralCount: neutral, resistCount: resist,
            hasSafeSwitch: safe, pierceRisk: pierce, score: score)
    }
}
