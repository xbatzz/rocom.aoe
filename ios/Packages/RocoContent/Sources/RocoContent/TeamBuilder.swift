import Foundation
import RocoDomain

public enum BattleStat: Int, Codable, CaseIterable, Sendable {
    case hp, physicalAttack, magicalAttack, physicalDefense, magicalDefense, speed
    public var label: String {
        switch self {
        case .hp: "HP"; case .physicalAttack: "物攻"; case .magicalAttack: "魔攻"
        case .physicalDefense: "物防"; case .magicalDefense: "魔防"; case .speed: "速度"
        }
    }
}

public struct TeamSlot: Codable, Equatable, Sendable {
    public var petID: Int?
    public var personalityID: Int?
    public var legacyTypeID: Int?
    public var individualValues: [Int] = Array(repeating: 0, count: 6)
    public var skillIDs: [Int] = []
    public init() {}
}

public struct TeamBuild: Codable, Equatable, Identifiable, Sendable {
    public var version: Int = 1
    public var id: UUID = UUID()
    public var name: String = "未命名配队"
    public var magicItemID: Int?
    public var slots: [TeamSlot] = Array(repeating: TeamSlot(), count: 6)
    public init() {}
    public func validate() throws {
        guard version == 1, slots.count == 6 else { throw ContentError.invalid("不支持的队伍格式/槽数量") }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 32 else {
            throw ContentError.invalid("队伍名称须为 1–32 字")
        }
        for slot in slots {
            try TeamRules.validateIndividuals(slot.individualValues)
            guard slot.skillIDs.count <= 4, Set(slot.skillIDs).count == slot.skillIDs.count else {
                throw ContentError.invalid("技能最多 4 个且不能重复")
            }
        }
    }
    public mutating func swapSlots(_ first: Int, _ second: Int) throws {
        guard slots.indices.contains(first), slots.indices.contains(second) else { throw ContentError.invalid("槽位不存在") }
        slots.swapAt(first, second)
    }
}

/// Sources: src/pages/team.vue getMoveRank/getMoveOptions/getLegacyTypeOptions,
/// src/features/team-builder/leaderBloodline.ts, src/lib/statCalculator.ts.
public enum TeamRules {
    public struct MoveOption: Sendable {
        public let skill: Skill
        public let source: PetSkillSource
        public let score: Double
    }
    public static func validateIndividuals(_ values: [Int]) throws {
        guard values.count == 6, values.allSatisfy({ (0...10).contains($0) }), values.filter({ $0 > 0 }).count <= 3 else {
            throw ContentError.invalid("个体值每项 0–10，最多 3 项大于 0")
        }
    }
    public static func assign(_ pet: Pet, content: ContentStore) throws -> TeamSlot {
        guard pet.implemented, pet.publicVisible, !pet.isLeader else { throw ContentError.invalid("该精灵不能用于配队") }
        var slot = TeamSlot()
        slot.petID = pet.petId.rawValue
        let personality = pet.attackStyle == .physical ? 6 : pet.attackStyle == .magic ? 11 : 1
        guard content.personalities[PersonalityID(rawValue: personality)] != nil,
            let legacy = pet.defaultLegacyTypeId else { throw ContentError.invalid("默认构筑 canonical 数据缺失") }
        slot.personalityID = personality
        slot.legacyTypeID = legacy.rawValue
        slot.skillIDs = try recommended(slot, content: content)
        return slot
    }
    public static func legacyOptions(_ pet: Pet, content: ContentStore) -> [TypeID] {
        let relations = content.petSkills(for: pet.petId).filter { $0.source == .bloodline }
        var ids = Set(relations.compactMap(\.legacyTypeId))
        if let id = pet.defaultLegacyTypeId { ids.insert(id) }
        let leader = TypeID(rawValue: 19) // Explicit Web LEADER_BLOODLINE_TYPE_ID.
        if !pet.leaderPotential || !relations.contains(where: { $0.legacyTypeId == leader }) { ids.remove(leader) }
        return ids.sorted { $0.rawValue < $1.rawValue }
    }
    public static func score(_ skill: Skill, pet: Pet) -> Double {
        var score = skill.power ?? 18
        if let type = skill.typeId, pet.typeIds.contains(type) { score += 48 }
        if let type = skill.typeId, type == pet.defaultLegacyTypeId { score += 18 }
        if pet.attackStyle == .physical && skill.category == .physicalAttack { score += 26 }
        if pet.attackStyle == .magic && skill.category == .magicAttack { score += 26 }
        if pet.attackStyle == .both && [.physicalAttack, .magicAttack].contains(skill.category) { score += 14 }
        if skill.category == .status { score += 6 }
        if skill.category == .defense { score += 3 }
        return score
    }
    public static func options(_ slot: TeamSlot, content: ContentStore) throws -> [MoveOption] {
        guard let id = slot.petID, let pet = content.pets[PetID(rawValue: id)] else {
            throw ContentError.invalid("精灵 ID 无法解析，保留原构筑")
        }
        let relations = content.petSkills(for: pet.petId)
        var sourceByID: [SkillID: PetSkillSource] = [:]
        for source in [PetSkillSource.pool, .stone] {
            for relation in relations where relation.source == source { sourceByID[relation.skillId] = source }
        }
        if let legacy = slot.legacyTypeID,
            let relation = relations.first(where: { $0.source == .bloodline && $0.legacyTypeId?.rawValue == legacy }) {
            sourceByID[relation.skillId] = .bloodline
        }
        let options = try sourceByID.map { id, source in
            guard let skill = content.skills[id] else { throw ContentError.invalid("技能 ID \(id.rawValue) 无法解析") }
            return MoveOption(skill: skill, source: source, score: score(skill, pet: pet))
        }
        return options.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if let left = $0.skill.energyCost, let right = $1.skill.energyCost, left != right { return left > right }
            return $0.skill.skillId.rawValue < $1.skill.skillId.rawValue
        }
    }
    public static func recommended(_ slot: TeamSlot, content: ContentStore) throws -> [Int] {
        try options(slot, content: content).prefix(4).map { $0.skill.skillId.rawValue }
    }
    public static func changeLegacy(_ slot: TeamSlot, to legacy: Int, content: ContentStore) throws -> TeamSlot {
        guard let id = slot.petID, let pet = content.pets[PetID(rawValue: id)],
            legacyOptions(pet, content: content).contains(TypeID(rawValue: legacy)) else { throw ContentError.invalid("血脉不可选") }
        var changed = slot
        changed.legacyTypeID = legacy
        let legal = Set(try options(changed, content: content).map { $0.skill.skillId.rawValue })
        // Unresolved IDs cannot be proven illegal: preserve and label them for explicit repair.
        changed.skillIDs = slot.skillIDs.filter { legal.contains($0) || content.skills[SkillID(rawValue: $0)] == nil }
        return changed // Never auto-fill on bloodline change.
    }
    public static func toggleSkill(_ id: Int, slot: TeamSlot, content: ContentStore) throws -> TeamSlot {
        var changed = slot
        if changed.skillIDs.contains(id) { changed.skillIDs.removeAll { $0 == id }; return changed }
        guard changed.skillIDs.count < 4,
            try options(slot, content: content).contains(where: { $0.skill.skillId.rawValue == id }) else {
            throw ContentError.invalid("技能不可选或已达到 4 个")
        }
        changed.skillIDs.append(id)
        return changed
    }
}

/// Exact integer rounding stages from statCalculator.ts (all operands nonnegative).
public enum BattleStatsCalculator {
    public static func calculate(pet: Pet, individuals: [Int], personality: Personality?) throws -> [Int] {
        try TeamRules.validateIndividuals(individuals)
        let base = [pet.baseStats.hp, pet.baseStats.physicalAttack, pet.baseStats.magicalAttack,
            pet.baseStats.physicalDefense, pet.baseStats.magicalDefense, pet.baseStats.speed]
        let modifiers: [Double]
        if let p = personality?.modifiers {
            modifiers = [p.hp.rawValue, p.physicalAttack.rawValue, p.magicalAttack.rawValue,
                p.physicalDefense.rawValue, p.magicalDefense.rawValue, p.speed.rawValue]
        } else { modifiers = Array(repeating: 0, count: 6) }
        return BattleStat.allCases.map { stat in
            let i = stat.rawValue
            let scaled = (Double(base[i] + 3 * individuals[i]) * (stat == .hp ? 1.7 : 1.1)).rounded()
            let before = scaled + (stat == .hp ? 70 : 10)
            return Int((before * (1 + modifiers[i])).rounded()) + (stat == .hp ? 100 : 50)
        }
    }
}
