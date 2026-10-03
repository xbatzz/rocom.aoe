import SwiftUI
import RocoContent

struct SkillCategoryPill: View {
    let category: SkillCategory
    var title: String? = nil
    var body: some View {
        Label {
            Text(title ?? category.displayName)
        } icon: {
            Image(systemName: category.symbolName).foregroundStyle(category.tint)
        }
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title ?? category.displayName)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(category.tint.opacity(0.10), in: Capsule())
    }
}

