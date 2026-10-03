import SwiftUI
import RocoContent

struct TraitDetailCard: View {
    let trait: Trait
    let content: ContentStore
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("特性").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            HStack(spacing: 14) {
                CanonicalThumbnail(assetID: trait.iconAssetId, content: content, size: 56)
                Text(trait.nameZh).font(.headline).fixedSize(horizontal: false, vertical: true)
            }
            if !trait.description.isEmpty {
                Text(trait.description).textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .companionAccentSurface(tint: tint)
    }
}
