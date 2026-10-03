import Foundation
import RocoDomain

/// Shared identifier semantics for catalog, build pickers and collection members.
public enum PetSearch {
    /// Prepare once per result set, rather than running ICU transforms per pet.
    public struct Query: Sendable {
        private let text: String
        private let number: Int?
        public var isEmpty: Bool { text.isEmpty }

        public init(_ query: String) {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            text = trimmed.isEmpty ? "" : trimmed.applyingTransform(.fullwidthToHalfwidth, reverse: false)?.lowercased() ?? query.lowercased()
            let numberText = text.hasPrefix("#") ? String(text.dropFirst()) : text
            number = numberText.allSatisfy(\.isNumber) ? Int(numberText) : nil
        }

        public func matches(_ pet: Pet) -> Bool {
            if isEmpty { return true }
            if let number {
                return pet.petId.rawValue == number || pet.handbookId?.rawValue == number || pet.speciesId.rawValue == number
            }
            return pet.nameZh.localizedStandardContains(text) || pet.form.localizedStandardContains(text)
                || pet.resourceKey.localizedStandardContains(text) || pet.searchAliases.contains { $0.localizedStandardContains(text) }
        }
    }

    public static func matches(_ pet: Pet, query: String) -> Bool {
        Query(query).matches(pet)
    }
}

public struct PetQuery: Sendable {
    public enum Implementation: String, CaseIterable, Sendable { case all = "全部", implemented = "已实装", unimplemented = "未实装" }
    public enum Stage: String, CaseIterable, Sendable { case all = "全部", initial = "初始", evolved = "已进化", canEvolve = "可进化" }
    public enum Sort: String, CaseIterable, Sendable {
        case handbook = "图鉴编号", name = "中文名", total = "总种族值", hp = "生命", physicalAttack = "物攻", magicalAttack = "魔攻", physicalDefense = "物防", magicalDefense = "魔防", speed = "速度"
    }
    public var keyword = ""
    public var type: TypeID?
    public var skill: SkillID?
    public var source: PetSkillSource?
    public var style: PetAttackStyle?
    public var stage = Stage.all
    public var implementation = Implementation.implemented
    public var sort = Sort.handbook
    public var descending = false
    public init() {}
    public func results(content: ContentStore) -> [Pet] {
        let search = PetSearch.Query(keyword)
        let parents = Set(content.pets.values.compactMap(\.parentPetId)).union(content.evolutions.values.map(\.sourcePetId))
        let matches = content.orderedPets.filter { pet in
            guard pet.publicVisible, search.matches(pet), type == nil || pet.typeIds.contains(type!),
                style == nil || pet.attackStyle == style else { return false }
            if implementation != .all && pet.implemented != (implementation == .implemented) { return false }
            if stage == .initial && pet.parentPetId != nil || stage == .evolved && pet.parentPetId == nil || stage == .canEvolve && !parents.contains(pet.petId) { return false }
            if skill != nil || source != nil {
                return content.petSkills(for: pet.petId).contains { (skill == nil || $0.skillId == skill) && (source == nil || $0.source == source) }
            }
            return true
        }
        return PetCatalogPresentation.collapseDuplicateLeaderConfigurations(matches).sorted { left, right in
            if sort == .handbook { return descending ? PetCatalogPresentation.handbookOrder(right, left) : PetCatalogPresentation.handbookOrder(left, right) }
            if sort == .name {
                let order = left.nameZh.compare(right.nameZh, locale: Locale(identifier: "zh_CN"))
                if order != .orderedSame { return descending ? order == .orderedDescending : order == .orderedAscending }
            } else {
                let a = value(left), b = value(right)
                if a != b { return descending ? a > b : a < b }
            }
            return left.petId.rawValue < right.petId.rawValue
        }
    }
    private func value(_ pet: Pet) -> Int {
        let s = pet.baseStats
        switch sort {
        case .hp: return s.hp
        case .physicalAttack: return s.physicalAttack
        case .magicalAttack: return s.magicalAttack
        case .physicalDefense: return s.physicalDefense
        case .magicalDefense: return s.magicalDefense
        case .speed: return s.speed
        default: return s.hp + s.physicalAttack + s.magicalAttack + s.physicalDefense + s.magicalDefense + s.speed
        }
    }
}
