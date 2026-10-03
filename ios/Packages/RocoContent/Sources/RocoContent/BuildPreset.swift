import RocoDomain

public enum BuildPreset: String, CaseIterable, Sendable {
    case none = "无配置", maxAttack = "极限攻击", maxSpeed = "极速", maxHp = "极限生命"
    public func apply(to slot: TeamSlot, pet: Pet, content: ContentStore) -> TeamSlot {
        var result = slot
        result.individualValues = Array(repeating: 0, count: 6)
        if self == .none { result.personalityID = nil; return result }
        let physical = pet.attackStyle == .physical || (pet.attackStyle != .magic && pet.baseStats.physicalAttack >= pet.baseStats.magicalAttack)
        let preferred = physical ? 1 : 2, dump = physical ? 2 : 1
        let positive = self == .maxAttack ? preferred : self == .maxSpeed ? 5 : 0
        for i in self == .maxHp ? [0, 3, 4] : [0, 5, preferred] { result.individualValues[i] = 10 }
        let ordered = content.personalities.values.sorted { $0.personalityId.rawValue < $1.personalityId.rawValue }
        func modifiers(_ p: Personality) -> [Double] { [p.modifiers.hp.rawValue, p.modifiers.physicalAttack.rawValue, p.modifiers.magicalAttack.rawValue, p.modifiers.physicalDefense.rawValue, p.modifiers.magicalDefense.rawValue, p.modifiers.speed.rawValue] }
        result.personalityID = (ordered.first { modifiers($0)[positive] > 0 && modifiers($0)[dump] < 0 }
            ?? ordered.first { modifiers($0)[positive] > 0 })?.personalityId.rawValue ?? slot.personalityID
        return result
    }
}
