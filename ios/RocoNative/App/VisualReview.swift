#if DEBUG
import SwiftUI
import RocoContent
import RocoDomain
import RocoUserData

/// Simulator-only review entry points. Release retains the existing navigation unchanged.
/// Uses real canonical content and an isolated, ephemeral user database, never personal records.
enum VisualReview {
    static var route: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--visual-review"), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
    @ViewBuilder static func page(_ route: String, content: ContentStore, portraits: PortraitStore, skills: SkillSearchIndex, tracking: TrackingCatalogIndex) -> some View {
        NavigationStack {
            switch route {
            case "types": TypeMatchupView(content: content)
            case "skills": SkillsView(content: content, portraits: portraits, index: skills)
            case "skill":
                if let skill = content.skills.values.sorted(by: { $0.skillId.rawValue < $1.skillId.rawValue }).first(where: { $0.iconAssetId != nil }) {
                    SkillDetailView(skill: skill, content: content, portraits: portraits, index: skills)
                }
            case "shiny": ShinyCollectionView(content: content, index: tracking)
            case "grass": GrassBadgeView(content: content, index: tracking)
            case "hero": DestinedHeroView(content: content, index: tracking)
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
#endif
