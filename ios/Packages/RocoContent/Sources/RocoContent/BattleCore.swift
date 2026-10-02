import Foundation
import RocoDomain

/// Source: meteorBugCaptureBall.ts; only its speed effect is used by pvp-lite.
public enum MeteorBall: String, Codable, CaseIterable, Sendable {
    case normal, advanced, king, wonderful, temperature, photosynthesis, net, insulated
    case sand, shifting, darkStar, bellicose, light, prism
    public var label: String {
        switch self {
        case .normal: "普通球"; case .advanced: "高级球"; case .king: "国王球"; case .wonderful: "美妙球"
        case .temperature: "调温球"; case .photosynthesis: "光合球"; case .net: "网兜球"; case .insulated: "绝缘球"
        case .sand: "淘沙球"; case .shifting: "变幻球"; case .darkStar: "暗星球"; case .bellicose: "好战球"
        case .light: "捕光球"; case .prism: "棱镜球"
        }
    }
    public func speed(_ speed: Int, petID: Int) -> Int {
        guard petID == 3400 else { return speed }
        let percent: Double = switch self { case .normal: 0.05; case .advanced: 0.1; case .king: 0.15; default: 0 }
        return Int((Double(speed) * (1 + percent)).rounded()) + (self == .insulated ? 50 : 0)
    }
}

public struct BattleProfile: Equatable, Sendable {
    public var slot = TeamSlot()
    public var hpPercent = 100
    public var meteorBall: MeteorBall = .insulated
    public init() {}
}

public struct DamageSettings: Equatable, Sendable {
    public var choiceIndex = 0
    public var swarmPowerCount = 0
    public var swarmHitCount = 0
    public var blazingStage = 0
    public init() {}
}

public struct DamageChoice: Sendable {
    public let label: String
    public let description: String
    public let flatPower: Double
    public let percentPower: Double
    public let threshold: Double?
    public let below: Bool
    public var assumesTrigger: Bool {
        description.range(of: "若|时|应对|位于|携带", options: .regularExpression) != nil
    }
    public func enabled(hpPercent: Int) -> Bool {
        guard let threshold else { return true }
        return below ? Double(hpPercent) < threshold : Double(hpPercent) > threshold
    }
}

public struct PaperDamage: Sendable {
    public let displayPower: Int
    public let singleHit: Int
    public let total: Int
    public let defenderHP: Int
    public let typeMultiplier: Double
    public let stabMultiplier: Double
    public var hpPercent: Double { (Double(total) / Double(defenderHP) * 1000).rounded() / 10 }
    public var hitsToKO: Int { Int(ceil(Double(defenderHP) / Double(total))) }
}

/// Exact source rules; no View dependencies and no replacement battle chart.
public enum BattleCore {
    public static func pet(_ profile: BattleProfile, content: ContentStore) throws -> Pet {
        guard let id = profile.slot.petID, let pet = content.pets[PetID(rawValue: id)] else {
            throw ContentError.invalid("请选择可解析的精灵")
        }
        return pet
    }
    public static func stats(_ profile: BattleProfile, content: ContentStore) throws -> [Int] {
        let pet = try pet(profile, content: content)
        let personality = profile.slot.personalityID.flatMap { content.personalities[PersonalityID(rawValue: $0)] }
        if profile.slot.personalityID != nil && personality == nil { throw ContentError.invalid("性格无法解析") }
        var stats = try BattleStatsCalculator.calculate(pet: pet, individuals: profile.slot.individualValues, personality: personality)
        stats[5] = profile.meteorBall.speed(stats[5], petID: pet.petId.rawValue)
        return stats
    }

    /// pvp-lite getDamageEffectOptions/getChoice*; only two-choice immediate bonuses.
    /// Permanent bonuses are excluded exactly as in Web. Other triggers are explicit assumptions.
    public static func choices(_ skill: Skill) -> [DamageChoice] {
        let description = skill.description.replacingOccurrences(of: "\u{200B}", with: "")
        guard let choiceText = captures("选择[：:](.+)", in: description).first else { return [] }
        let choices = choiceText.components(separatedBy: "或").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard choices.count >= 2 else { return [] }
        let name = normalizedName(skill.nameZh)
        return choices.prefix(2).enumerated().map { i, text in
            let permanent = text.contains("永久")
            let condition = captures("自己生命(低于|小于|高于|大于)(\\d+)%", in: text)
            let flat = permanent ? 0 : number("威力\\+(\\d+)(?![%\\d])", in: text)
            let percent = permanent ? 0 : number("威力\\+(\\d+)%", in: text)
            return DamageChoice(label: name == "下注" ? (i == 0 ? "明" : "暗") : "选项\(i + 1)",
                description: text, flatPower: flat, percentPower: percent,
                threshold: condition.count == 2 ? Double(condition[1]) : nil,
                below: condition.first == "低于" || condition.first == "小于")
        }
    }
    public static func isSwarm(_ skill: Skill) -> Bool { normalizedName(skill.nameZh) == "虫群" }
    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }
    private static func captures(_ pattern: String, in text: String) -> [String] {
        // Constant patterns are programmer-owned; invalid syntax is a programming error.
        guard let regex = try? NSRegularExpression(pattern: pattern) else { preconditionFailure("Invalid battle rule regex") }
        let input = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: input.length)) else { return [] }
        return (1..<match.numberOfRanges).map { input.substring(with: match.range(at: $0)) }
    }
    private static func number(_ pattern: String, in text: String) -> Double {
        captures(pattern, in: text).first.flatMap(Double.init) ?? 0 // No matching Web rule => no bonus.
    }

    public static func damage(attacker: BattleProfile, defender: BattleProfile, skill: Skill,
        settings: DamageSettings = DamageSettings(), content: ContentStore) throws -> PaperDamage {
        guard let power = skill.power, power > 0, let type = skill.typeId,
            [.physicalAttack, .magicAttack].contains(skill.category) else {
            throw ContentError.invalid("仅固定威力、固定属性的攻击技能可计算；变化/防御技能不参与纸面伤害")
        }
        guard (0...100).contains(attacker.hpPercent), (0...20).contains(settings.swarmPowerCount),
            (0...20).contains(settings.swarmHitCount), settings.blazingStage >= 0 else { throw ContentError.invalid("战斗条件超出范围") }
        let choices = choices(skill)
        let choice: DamageChoice?
        if choices.isEmpty { choice = nil }
        else {
            guard choices.indices.contains(settings.choiceIndex) else { throw ContentError.invalid("技能选项不存在") }
            choice = choices[settings.choiceIndex]
        }
        let enabled = choice?.enabled(hpPercent: attacker.hpPercent) == true
        let bonus = (enabled ? choice?.flatPower ?? 0 : 0) + (isSwarm(skill) ? Double(settings.swarmPowerCount * 20) : 0)
        let percent = enabled ? choice?.percentPower ?? 0 : 0
        let stage = attacker.slot.petID == 5017 ? 1 + Double(settings.blazingStage) / 10 : 1
        return try paper(attacker: attacker, defender: defender, power: power, type: type, category: skill.category,
            powerBonus: bonus, powerPercent: percent, hits: isSwarm(skill) ? 1 + settings.swarmHitCount : 1,
            stage: stage, content: content)
    }

    /// damageCalculator.ts: round display power, round numerator, floor division, min 2, then hits.
    private static func paper(attacker: BattleProfile, defender: BattleProfile, power: Double, type: TypeID,
        category: SkillCategory, powerBonus: Double = 0, powerPercent: Double = 0,
        hits: Int = 1, stage: Double = 1, content: ContentStore) throws -> PaperDamage {
        let attackingPet = try pet(attacker, content: content)
        let defendingPet = try pet(defender, content: content)
        let attack = try stats(attacker, content: content)
        let defense = try stats(defender, content: content)
        let physical = category == .physicalAttack
        let typeMultiplier = try TypeMatchup(types: content.types).defense(attack: type, defenders: defendingPet.typeIds)
        let stab = attackingPet.typeIds.contains(type) ? 1.25 : 1
        let effective = max(0, power + powerBonus) * (1 + powerPercent / 100)
        let display = Int((effective * stab * typeMultiplier * stage).rounded())
        let coefficient = (60.0 * 45 / 100 + 10) / 41
        let raw = floor((Double(attack[physical ? 1 : 2]) * Double(display) * coefficient).rounded() / Double(max(1, defense[physical ? 3 : 4])))
        let single = max(2, Int(raw))
        return PaperDamage(displayPower: display, singleHit: single, total: single * hits, defenderHP: max(1, defense[0]),
            typeMultiplier: typeMultiplier, stabMultiplier: stab)
    }

    /// damageCalculator.ts binary search; one-hit lines intentionally use base paper rules,
    /// as pvp-lite createOneHitPowerLine does, without choice/swarm/blazing modifiers.
    public static func oneHitPower(attacker: BattleProfile, defender: BattleProfile,
        type: TypeID, category: SkillCategory, content: ContentStore) throws -> Int? {
        guard (0...100).contains(defender.hpPercent), [.physicalAttack, .magicAttack].contains(category) else { throw ContentError.invalid("一击线输入无效") }
        if defender.hpPercent == 0 { return 0 }
        let target = Int(ceil(Double(try stats(defender, content: content)[0]) * Double(defender.hpPercent) / 100))
        func doesKO(_ power: Int) throws -> Bool {
            try paper(attacker: attacker, defender: defender, power: Double(power), type: type, category: category, content: content).total >= target
        }
        guard try doesKO(5000) else { return nil }
        var low = 1, high = 5000
        while low < high {
            let middle = (low + high) / 2
            if try doesKO(middle) { high = middle } else { low = middle + 1 }
        }
        return low
    }

    public static func preferredCategory(_ pet: Pet) -> SkillCategory {
        if pet.attackStyle == .physical { return .physicalAttack }
        if pet.attackStyle == .magic { return .magicAttack }
        return pet.baseStats.physicalAttack >= pet.baseStats.magicalAttack ? .physicalAttack : .magicAttack
    }
    /// teamAnalysis getTypeRelationNet/getTypeMultiplier: strongest native type, not multiplied attacks.
    public static func switchMultipliers(attacker: Pet, candidates: [Pet], content: ContentStore) throws -> [(PetID, Double)] {
        let engine = TypeMatchup(types: content.types)
        return try candidates.map { defender in
            let multipliers = try attacker.typeIds.map { try engine.defense(attack: $0, defenders: defender.typeIds) }
            guard let strongest = multipliers.max() else { throw ContentError.invalid("攻击属性不存在") }
            return (defender.petId, strongest)
        }
    }
}

extension BattleCore {
    public struct OneHitLine: Sendable {
        public let label: String
        public let typeID: TypeID?
        public let requiredPower: Int?
        public let multiplier: Double?
    }
    public static func oneHitLines(attacker: BattleProfile, defender: BattleProfile, content: ContentStore) throws -> [OneHitLine] {
        let pet = try pet(attacker, content: content)
        let target = try Self.pet(defender, content: content)
        let engine = TypeMatchup(types: content.types)
        let category = preferredCategory(pet)
        func line(_ type: TypeID, label: String) throws -> OneHitLine {
            OneHitLine(label: label, typeID: type,
                requiredPower: try oneHitPower(attacker: attacker, defender: defender, type: type, category: category, content: content),
                multiplier: try engine.defense(attack: type, defenders: target.typeIds))
        }
        let stab = try pet.typeIds.filter { content.types[$0]?.normalBattleType == true }.map { try line($0, label: "本系") }.sorted {
            let left = $0.requiredPower ?? Int.max, right = $1.requiredPower ?? Int.max
            if left != right { return left < right }
            return ($0.multiplier ?? 1) > ($1.multiplier ?? 1)
        }
        let neutral = try engine.selectable.first { type in
            if pet.typeIds.contains(type.typeId) { return false }
            return try engine.defense(attack: type.typeId, defenders: target.typeIds) == 1
        }
        let empty = OneHitLine(label: "本系", typeID: nil, requiredPower: nil, multiplier: nil)
        return [stab.first ?? empty, try neutral.map { try line($0.typeId, label: "非本系") }
            ?? OneHitLine(label: "非本系", typeID: nil, requiredPower: nil, multiplier: nil)]
    }
    public static func calculableSkills(_ profile: BattleProfile, content: ContentStore) throws -> [Skill] {
        let pet = try pet(profile, content: content)
        let ids = Set(content.petSkills(for: pet.petId).map(\.skillId))
        return ids.compactMap { content.skills[$0] }.filter {
            [.physicalAttack, .magicAttack].contains($0.category) && ($0.power ?? 0) > 0 && $0.typeId != nil
        }.sorted { ($0.skillId.rawValue) < ($1.skillId.rawValue) }
    }
}
