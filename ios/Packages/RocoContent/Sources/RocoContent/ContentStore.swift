import Foundation
import RocoDomain

/// Fully validated snapshot. All storage is immutable and compiler-checked Sendable.
/// Own one instance per application lifetime; queries never decode or scan entity arrays.
public struct ContentStore: Sendable {
    public let manifest: Manifest
    public let assetResolver: AssetResolver
    public let orderedPets: [Pet]
    public let pets: [PetID: Pet]
    public let petDetails: [PetID: PetDetail]
    public let types: [TypeID: BattleType]
    public let skills: [SkillID: Skill]
    public let skillGroups: [SkillGroupID: SkillGroup]
    public let traits: [TraitID: Trait]
    public let evolutions: [EvolutionEdgeID: Evolution]
    public let shinySlots: [ShinySlotID: ShinySlot]
    public let badgeFootprints: [FootprintKey: BadgeFootprint]
    public let badgeLocations: [BadgeLocationLocationId: BadgeLocation]
    public let personalities: [PersonalityID: Personality]
    public let magicItems: [MagicItemID: MagicItem]
    public let seasons: [SeasonID: Season]
    public let battleEffects: [EffectID: BattleEffect]
    public let assets: [AssetID: Asset]
    public let petSkillsByPet: [PetID: [PetSkill]]
    public let evolutionsByPet: [PetID: [Evolution]]
    public let incomingEvolutionsByPet: [PetID: [Evolution]]
    public let families: [FamilyIdentity: Family]
    public let familiesByPet: [PetID: [FamilyKind: [Family]]]
    public let shinySlotsByPet: [PetID: [ShinySlot]]
    public let shinySlotsBySeason: [SeasonID: [ShinySlot]]
    public let badgeFootprintsByPet: [PetID: BadgeFootprint]
    public let battleEffectsBySkill: [SkillID: [BattleEffect]]
    public let battleEffectsByPet: [PetID: [BattleEffect]]

    /// Layout: <Bundle resources>/Content/{canonical,assets}/...
    /// Throws with a file/field/ID context; never returns a partial snapshot.
    public static func load(bundle: Bundle, directory: String = "Content", appBuild: Int = 1) throws -> ContentStore {
        try ContentStore(bundle: bundle, directory: directory, appBuild: appBuild)
    }

    /// Real-package validation takes hundreds of milliseconds; this entry point keeps it off the UI actor.
    @concurrent public static func loadInBackground(bundleURL: URL, directory: String = "Content", appBuild: Int = 1) async throws -> ContentStore {
        guard let bundle = Bundle(url: bundleURL) else { throw ContentError.invalid("Cannot open Bundle: \(bundleURL.path)") }
        return try load(bundle: bundle, directory: directory, appBuild: appBuild)
    }

    private init(bundle: Bundle, directory: String, appBuild: Int) throws {
        let reader = try BundleReader(bundle: bundle, directory: directory + "/canonical")
        let manifestBytes = try reader.data("manifest.json")
        let decodedManifest = try decodeData(Manifest.self, bytes: manifestBytes, context: "manifest.json")
        manifest = decodedManifest
        try require(manifest.schemaVersion == 2, "Unsupported schemaVersion")
        try require(appBuild >= manifest.minimumAppBuild, "App build below manifest.minimumAppBuild")
        let files = try uniqueIndex(manifest.files, id: { $0.path }, context: "manifest.files")
        try require(Set(files.keys) == Set(["pets.json", "pet-details.json", "types.json", "skills.json", "skill-groups.json", "pet-skills.json", "traits.json", "evolutions.json", "families.json", "shiny-slots.json", "badge-footprints.json", "badge-locations.json", "personalities.json", "magic-items.json", "seasons.json", "battle-effects.json", "assets.json"]), "Expected exactly 17 canonical files")
        try require(Set(manifest.counts.keys) == Set(["pets", "petDetails", "types", "skills", "skillGroups", "petSkills", "traits", "evolutions", "families", "shinySlots", "badgeFootprints", "badgeLocations", "personalities", "magicItems", "seasons", "battleEffects", "assets"]), "Expected exactly 17 manifest counts")
        func load<T: Decodable>(_ type: T.Type, _ name: String, _ path: String) throws -> [T] {
            guard let file = files[path] else { throw ContentError.invalid("Missing manifest entry: \(path)") }
            let values = try reader.decode([T].self, path: path, file: file)
            try require(values.count == decodedManifest.counts[name], "Count mismatch: \(name)")
            return values
        }
        let petsRows = try load(Pet.self, "pets", "pets.json")
        pets = try uniqueIndex(petsRows, id: { $0.petId }, context: "pets")
        let petDetailsRows = try load(PetDetail.self, "petDetails", "pet-details.json")
        petDetails = try uniqueIndex(petDetailsRows, id: { $0.petId }, context: "petDetails")
        let typesRows = try load(BattleType.self, "types", "types.json")
        types = try uniqueIndex(typesRows, id: { $0.typeId }, context: "types")
        let skillsRows = try load(Skill.self, "skills", "skills.json")
        skills = try uniqueIndex(skillsRows, id: { $0.skillId }, context: "skills")
        let skillGroupsRows = try load(SkillGroup.self, "skillGroups", "skill-groups.json")
        skillGroups = try uniqueIndex(skillGroupsRows, id: { $0.groupId }, context: "skillGroups")
        let petSkillsRows = try load(PetSkill.self, "petSkills", "pet-skills.json")
        let traitsRows = try load(Trait.self, "traits", "traits.json")
        traits = try uniqueIndex(traitsRows, id: { $0.traitId }, context: "traits")
        let evolutionsRows = try load(Evolution.self, "evolutions", "evolutions.json")
        evolutions = try uniqueIndex(evolutionsRows, id: { $0.edgeId }, context: "evolutions")
        let familiesRows = try load(Family.self, "families", "families.json")
        let shinySlotsRows = try load(ShinySlot.self, "shinySlots", "shiny-slots.json")
        shinySlots = try uniqueIndex(shinySlotsRows, id: { $0.slotId }, context: "shinySlots")
        let badgeFootprintsRows = try load(BadgeFootprint.self, "badgeFootprints", "badge-footprints.json")
        badgeFootprints = try uniqueIndex(badgeFootprintsRows, id: { $0.footprintKey }, context: "badgeFootprints")
        let badgeLocationsRows = try load(BadgeLocation.self, "badgeLocations", "badge-locations.json")
        badgeLocations = try uniqueIndex(badgeLocationsRows, id: { $0.locationId }, context: "badgeLocations")
        let personalitiesRows = try load(Personality.self, "personalities", "personalities.json")
        personalities = try uniqueIndex(personalitiesRows, id: { $0.personalityId }, context: "personalities")
        let magicItemsRows = try load(MagicItem.self, "magicItems", "magic-items.json")
        magicItems = try uniqueIndex(magicItemsRows, id: { $0.magicItemId }, context: "magicItems")
        let seasonsRows = try load(Season.self, "seasons", "seasons.json")
        seasons = try uniqueIndex(seasonsRows, id: { $0.seasonId }, context: "seasons")
        let battleEffectsRows = try load(BattleEffect.self, "battleEffects", "battle-effects.json")
        battleEffects = try uniqueIndex(battleEffectsRows, id: { $0.effectId }, context: "battleEffects")
        let assetsRows = try load(Asset.self, "assets", "assets.json")
        assets = try uniqueIndex(assetsRows, id: { $0.assetId }, context: "assets")
        orderedPets = petsRows.sorted { $0.ordinal < $1.ordinal }
        try require(assetsRows == manifest.assets, "manifest.assets differs from assets.json")
        families = try uniqueIndex(familiesRows, id: { FamilyIdentity(kind: $0.kind, key: $0.familyKey) }, context: "families")
        var familyIndex: [PetID: [FamilyKind: [Family]]] = [:]
        for family in familiesRows {
            for pet in family.memberPetIds {
                familyIndex[pet, default: [:]][family.kind, default: []].append(family)
            }
        }
        familiesByPet = familyIndex.mapValues { $0.mapValues { $0.sorted { $0.ordinal < $1.ordinal } } }
        petSkillsByPet = Dictionary(grouping: petSkillsRows, by: \.petId).mapValues { $0.sorted { $0.ordinal < $1.ordinal } }
        evolutionsByPet = Dictionary(grouping: evolutionsRows, by: \.sourcePetId).mapValues { $0.sorted { $0.ordinal < $1.ordinal } }
        incomingEvolutionsByPet = Dictionary(grouping: evolutionsRows, by: \.targetPetId).mapValues { $0.sorted { $0.ordinal < $1.ordinal } }
        shinySlotsByPet = memberIndex(shinySlotsRows, members: { $0.memberPetIds })
        shinySlotsBySeason = Dictionary(grouping: shinySlotsRows, by: \.seasonId)
        badgeFootprintsByPet = try uniqueIndex(badgeFootprintsRows, id: { $0.petId }, context: "badgeFootprints.pet")
        battleEffectsBySkill = optionalIndex(battleEffectsRows, id: { $0.skillId })
        battleEffectsByPet = optionalIndex(battleEffectsRows, id: { $0.petId })
        assetResolver = try AssetResolver(bundle: bundle, directory: directory + "/assets",
            canonical: assets, manifest: manifest, canonicalManifestHash: sha256(manifestBytes))
        try validateRelations(petSkillsRows: petSkillsRows)
    }

    public func pet(_ id: PetID) -> Pet? { pets[id] }
    public func skill(_ id: SkillID) -> Skill? { skills[id] }
    public func type(_ id: TypeID) -> BattleType? { types[id] }
    public func trait(_ id: TraitID) -> Trait? { traits[id] }
    public func petSkills(for id: PetID) -> [PetSkill] { petSkillsByPet[id] ?? [] }
    public func evolutions(from id: PetID) -> [Evolution] { evolutionsByPet[id] ?? [] }
    public func families(for id: PetID, kind: FamilyKind) -> [Family] { familiesByPet[id]?[kind] ?? [] }
}

public struct FamilyIdentity: Hashable, Sendable {
    public let kind: FamilyKind
    public let key: FamilyKey
    public init(kind: FamilyKind, key: FamilyKey) { self.kind = kind; self.key = key }
}

func memberIndex<T, ID: Hashable>(_ rows: [T], members: (T) -> [ID]) -> [ID: [T]] {
    var result: [ID: [T]] = [:]
    for row in rows { for id in members(row) { result[id, default: []].append(row) } }
    return result
}
func optionalIndex<T, ID: Hashable>(_ rows: [T], id: (T) -> ID?) -> [ID: [T]] {
    var result: [ID: [T]] = [:]
    for row in rows { if let key = id(row) { result[key, default: []].append(row) } }
    return result
}
