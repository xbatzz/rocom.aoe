import RocoDomain

/// Source: src/features/battle-query/typeDefenseMatchup.ts.
/// Canonical relationships are defensive; never maintain a second battle chart.
public struct TypeMatchup: Sendable {
    private let types: [TypeID: BattleType]
    public let selectable: [BattleType]

    public init(types: [TypeID: BattleType]) {
        self.types = types
        selectable = types.values.filter(\.normalBattleType).sorted { $0.typeId.rawValue < $1.typeId.rawValue }
    }

    public func single(attack: TypeID, defense: TypeID) throws -> Double {
        guard let attacker = types[attack], attacker.normalBattleType,
            let defender = types[defense], defender.normalBattleType else {
            throw ContentError.invalid("普通属性不存在: \(attack.rawValue)/\(defense.rawValue)")
        }
        if defender.weakToTypeIds.contains(attack) { return 2 }
        if defender.resistToTypeIds.contains(attack) { return 0.5 }
        return 1
    }

    public func defense(attack: TypeID, defenders: [TypeID]) throws -> Double {
        var unique: [TypeID] = []
        for id in defenders where !unique.contains(id) { unique.append(id) }
        guard !unique.isEmpty else { throw ContentError.invalid("请选择防御属性") }
        let product = try unique.prefix(2).reduce(1.0) { try $0 * single(attack: attack, defense: $1) }
        return product == 4 ? 3 : product
    }

    public func coverage(attackers: [TypeID]) throws -> [BattleType] {
        for id in attackers {
            guard types[id]?.normalBattleType == true else { throw ContentError.invalid("普通攻击属性不存在") }
        }
        let selected = Set(attackers)
        return selectable.filter { !selected.isDisjoint(with: $0.weakToTypeIds) }
    }
}
