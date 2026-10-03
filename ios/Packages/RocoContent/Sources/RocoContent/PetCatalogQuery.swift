import Foundation
import RocoDomain

public struct PetCatalogQuery: Equatable, Sendable {
    public enum Sort: String, CaseIterable, Sendable {
        case handbook = "图鉴编号", total = "总种族值", speed = "速度", name = "中文名"
    }
    public enum Leader: String, CaseIterable, Sendable {
        case all = "全部", leader = "首领形态", ordinary = "普通形态"
    }
    public enum Stage: String, CaseIterable, Sendable {
        case all = "全部", initial = "初始", evolved = "已进化", canEvolve = "可进化"
    }

    public var keyword = ""
    public var firstType: TypeID?
    public var secondType: TypeID?
    public var attackStyle: PetAttackStyle?
    public var leader = Leader.all
    public var stage = Stage.all
    public var skill: SkillID?
    public var source: PetSkillSource?
    public var sort = Sort.handbook

    public init() {}

    public var filterCount: Int {
        Set([firstType, secondType].compactMap { $0 }).count
            + (attackStyle == nil ? 0 : 1) + (leader == .all ? 0 : 1)
            + (stage == .all ? 0 : 1) + (skill == nil ? 0 : 1) + (source == nil ? 0 : 1)
    }
    public var hasFilters: Bool { filterCount > 0 }

    public mutating func clearFilters() {
        let keyword = keyword, sort = sort
        self = Self()
        self.keyword = keyword
        self.sort = sort
    }

    @concurrent public func results(content: ContentStore) async -> [Pet] {
        let query = Self.normalize(keyword)
        let numeric = !query.isEmpty && query.utf8.allSatisfy { (48...57).contains($0) }
        // parentPetId preserves Web's reverse-parent rule, including links absent
        // from the narrower evolution edge table. Branch edges are included too.
        let evolutionSources = content.evolutionSources
        let matches = content.catalogPets.filter { pet in
            let typesMatch = [firstType, secondType].compactMap { $0 }.allSatisfy { pet.typeIds.contains($0) }
            let leaderMatch = leader == .all || (leader == .leader ? pet.isLeader : !pet.isLeader)
            let stageMatch: Bool = switch stage {
            case .all: true
            case .initial: pet.parentPetId == nil
            case .evolved: pet.parentPetId != nil
            case .canEvolve: evolutionSources.contains(pet.petId)
            }
            guard typesMatch, leaderMatch, stageMatch,
                attackStyle == nil || pet.attackStyle == attackStyle else { return false }
            if skill != nil || source != nil {
                guard content.petSkills(for: pet.petId).contains(where: {
                    (skill == nil || $0.skillId == skill) && (source == nil || $0.source == source)
                }) else { return false }
            }
            if query.isEmpty { return true }
            if numeric {
                // Configuration ID is an independent exact match. Never substitute
                // speciesId for a missing real handbook number.
                let unpadded = Self.unpadded(query)
                if unpadded == String(pet.petId.rawValue) { return true }
                guard let number = pet.handbookId?.rawValue else { return false }
                let text = String(number)
                let padded = String(format: "%03d", number)
                return text.hasPrefix(unpadded) || padded.hasPrefix(query) || padded.hasSuffix(query)
            }
            let typeNames = (pet.typeIds + [pet.defaultLegacyTypeId].compactMap { $0 })
                .compactMap { content.type($0)?.nameZh }
            let fields = [pet.nameZh, pet.resourceKey, pet.form] + pet.searchAliases + typeNames
            return fields.contains { Self.normalize($0).contains(query) }
        }
        return PetCatalogPresentation.collapseDuplicateLeaderConfigurations(matches).sorted { left, right in
            switch sort {
            case .handbook:
                return PetCatalogPresentation.handbookOrder(left, right)
            case .total:
                let l = Self.total(left), r = Self.total(right)
                if l != r { return l > r }
            case .speed:
                if left.baseStats.speed != right.baseStats.speed { return left.baseStats.speed > right.baseStats.speed }
            case .name:
                let order = left.nameZh.compare(right.nameZh, locale: Locale(identifier: "zh_CN"))
                if order != .orderedSame { return order == .orderedAscending }
            }
            return left.petId.rawValue < right.petId.rawValue
        }
    }

    private static func total(_ pet: Pet) -> Int {
        let s = pet.baseStats
        return s.hp + s.physicalAttack + s.magicalAttack + s.physicalDefense + s.magicalDefense + s.speed
    }

    private static func unpadded(_ value: String) -> String {
        let stripped = value.drop(while: { $0 == "0" })
        return stripped.isEmpty ? "0" : String(stripped)
    }

    private static func normalize(_ value: String) -> String {
        let scalars = value.unicodeScalars.map { scalar -> String in
            if (0xFF10...0xFF19).contains(scalar.value), let digit = UnicodeScalar(scalar.value - 0xFEE0) {
                return String(digit)
            }
            return String(scalar)
        }
        return scalars.joined().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

