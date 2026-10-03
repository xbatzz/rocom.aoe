import SwiftUI
import RocoContent

/// One concrete child per ID lets LazyVStack skip offscreen rows without
/// evaluating conditional/multiple-child ForEach contents across the catalog.
struct SkillCatalogRow: View {
    let skill: Skill
    let content: ContentStore
    let portraits: PortraitStore
    let index: SkillSearchIndex
    let prefetch: [AssetID]
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                SkillDetailView(skill: skill, content: content, portraits: portraits, index: index)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    SkillSummary(skill: skill, content: content)
                    Text(skill.acquisitionDescription ?? "\(index.sameNameFamilyCount[skill.skillId] ?? 0) 个可获得家族")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("skill-\(skill.skillId.rawValue)")
            Divider().padding(.leading, 70)
        }
        .task(id: skill.skillId, priority: .utility) {
            guard !prefetch.isEmpty else { return }
            await portraits.thumbnails.prefetch(prefetch, maxPixelSize: max(64, Int((52 * displayScale).rounded(.up))))
        }
    }
}
