import SwiftUI
import RocoDomain
import RocoContent

struct PetPortrait: View {
    let image: UIImage
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(0.84)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

struct PetDetail: View {
    let pet: Pet
    let content: ContentStore
    let image: UIImage
    var anchors: PortraitAnchors? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        GeometryReader { geometry in
            // Navigation may propose zero width before its first layout.
            let side = max(0, min(320, geometry.size.width - 48, geometry.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.26 : 0.44)))
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Group {
                        if let anchors {
                            AnchoredPortrait(image: image, origin: nil, anchors: anchors)
                        } else {
                            PetPortrait(image: image)
                        }
                    }
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("hero-\(pet.petId.rawValue)")
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pet.numberLabel).font(.subheadline.monospacedDigit()).foregroundStyle(.primary.opacity(0.72))
                        Text(pet.nameZh).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                        Text(pet.typeIds.compactMap { content.types[$0]?.nameZh }.joined(separator: " · ")).font(.headline).foregroundStyle(.primary.opacity(0.72))
                        if pet.form != "default" { Text(pet.form).foregroundStyle(.primary.opacity(0.72)) }
                        if pet.portraitAssetId.flatMap({ content.assets[$0]?.availability }) == .missing { Label("暂无精灵图片", systemImage: "photo").foregroundStyle(.primary.opacity(0.72)) }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 16) {
                        Text("种族值").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        ForEach(Array(zip(["生命", "物攻", "魔攻", "物防", "魔防", "速度"], [pet.baseStats.hp, pet.baseStats.physicalAttack, pet.baseStats.magicalAttack, pet.baseStats.physicalDefense, pet.baseStats.magicalDefense, pet.baseStats.speed])), id: \.0) { label, value in
                            HStack {
                                Text(label).foregroundStyle(.primary.opacity(0.72))
                                Spacer()
                                Text(value, format: .number).monospacedDigit().fontWeight(.medium)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    if let traitId = content.petDetails[pet.petId]?.traitId, let trait = content.traits[traitId] {
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text("特性").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                            Text(trait.nameZh).font(.headline)
                            Text(trait.description).foregroundStyle(.primary.opacity(0.72))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .accessibilityIdentifier("detail-\(pet.petId.rawValue)")
        }
        .background(Color(uiColor: .systemBackground))
    }
}
