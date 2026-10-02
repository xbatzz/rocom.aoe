#if DEBUG
import SwiftUI
import RocoContent
import RocoDomain
import RocoUserData
import SwiftData

/// Simulator-only review entry points. Release retains the existing navigation unchanged.
/// Uses real canonical content and an isolated, ephemeral user database, never personal records.
enum VisualReview {
    static var route: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--visual-review"), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
    static func seed(_ context: ModelContext, content: ContentStore, tracking: TrackingCatalogIndex) throws {
        guard ProcessInfo.processInfo.arguments.contains("--visual-fixture") else { return }
        for slot in content.shinySlots.values.sorted(by: { $0.slotId.rawValue < $1.slotId.rawValue }).prefix(5) {
            try UserDatabase.toggleShiny(slot.slotId.rawValue, context: context)
        }
        for family in tracking.badgeFamilies.prefix(5) {
            try UserDatabase.toggleHero(family.familyKey.rawValue, context: context)
        }
        var team = TeamBuild(); team.name = "视觉复查示例队伍"
        let pets = content.orderedPets.filter { $0.implemented && $0.publicVisible && !$0.isLeader && $0.form == "default" }.prefix(4)
        for (i, pet) in pets.enumerated() { team.slots[i] = try TeamRules.assign(pet, content: content) }
        try UserDatabase.saveTeam(team, context: context)
    }
    @ViewBuilder static func page(_ route: String, content: ContentStore, portraits: PortraitStore, skills: SkillSearchIndex, tracking: TrackingCatalogIndex) -> some View {
        if route == "grid" {
            AlignedNavigation(content: content, portraits: portraits).ignoresSafeArea()
        } else {
        NavigationStack {
            switch route {
            case "version": ContentVersionView(content: content)
            case "grass-family":
                if let family = tracking.badgeFamilies.first { GrassFamilyView(family: family, content: content, index: tracking, location: .somia) }
            case "damage", "defense":
                let pets = content.orderedPets.filter { $0.implemented && $0.publicVisible && !$0.isLeader && $0.form == "default" }
                if pets.count >= 2, let a = try? TeamRules.assign(pets[0], content: content), let b = try? TeamRules.assign(pets[1], content: content) {
                    var first: BattleProfile { var profile = BattleProfile(); profile.slot = a; return profile }
                    var second: BattleProfile { var profile = BattleProfile(); profile.slot = b; return profile }
                    if route == "damage" { BattleDirectionView(attacker: first, defender: second, content: content, portraits: portraits, skillIndex: skills) }
                    else { TeamDefenseView(opponent: second, content: content) }
                }
            case "types", "types-dual", "types-coverage": TypeMatchupView(content: content)
            case "skills": SkillsView(content: content, portraits: portraits, index: skills)
            case "skill":
                if let skill = content.skills.values.sorted(by: { $0.skillId.rawValue < $1.skillId.rawValue }).first(where: { $0.iconAssetId != nil }) {
                    SkillDetailView(skill: skill, content: content, portraits: portraits, index: skills)
                }
            case "shiny": ShinyCollectionView(content: content, index: tracking)
            case "grass": GrassBadgeView(content: content, index: tracking)
            case "hero": DestinedHeroView(content: content, index: tracking)
            case "team-draft": TeamDraftView(initial: TeamBuild(), content: content, portraits: portraits, skillIndex: skills)
            case "teams": TeamBuilderView(content: content, portraits: portraits, skillIndex: skills)
            case "pvp", "pvp-filled": PVPBattleView(content: content, portraits: portraits, skillIndex: skills)
            case "backup": UserBackupView(content: content)
            case "pet":
                if let pet = content.orderedPets.first(where: { $0.implemented && $0.publicVisible && !$0.isLeader && $0.form == "default" }) {
                    ExistingPetDestination(pet: pet, content: content, portraits: portraits)
                }
            default: NativeFeatureEntry(content: content, portraits: portraits, skills: skills, tracking: tracking)
            }
        }
        }
    }
}
#endif
