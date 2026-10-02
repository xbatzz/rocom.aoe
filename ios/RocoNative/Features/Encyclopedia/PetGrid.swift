import SwiftUI
import RocoDomain
import RocoContent

extension Pet {
    var numberLabel: String {
        if let handbookId { return String(format: "No. %03d", handbookId.rawValue) }
        return "配置 \(petId.rawValue)"
    }
}

struct AlignedPetGrid: View {
    /// Passed from ContentStore.orderedPets; never Dictionary iteration order.
    let pets: [Pet]
    let portraits: PortraitStore
    let anchors: PortraitAnchors
    let open: (Pet, PortraitOrigin) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("认识每一只精灵。")
                    .font(.title3).foregroundStyle(.primary.opacity(0.72))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 28) {
                    ForEach(pets, id: \.petId) { pet in
                        PetGridCell(pet: pet, portraits: portraits, anchors: anchors, open: open)
                    }
                }
            }.padding(24)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

/// Decoding lives in the lazy cell body, never in the catalog/ForEach input construction.
/// The mounted UIImageView and bounded PortraitStore cache own the bitmap; there is no
/// 721-element UIImage array or per-pet @State bitmap retained after scrolling away.
private struct PetGridCell: View {
    let pet: Pet
    let portraits: PortraitStore
    let anchors: PortraitAnchors
    let open: (Pet, PortraitOrigin) -> Void

    var body: some View {
        let origin = PortraitOrigin(petID: pet.petId, instance: "encyclopedia-grid")
        let portrait = Result { try portraits.image(for: pet) }
        Button { open(pet, origin) } label: {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    switch portrait {
                    case .success(let image):
                        AnchoredPortrait(image: image, origin: origin, anchors: anchors)
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                            Text("图片加载失败").font(.caption)
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .allowsHitTesting(false)
                Text(pet.nameZh).font(.headline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(pet.numberLabel).font(.caption.monospacedDigit()).foregroundStyle(.primary.opacity(0.72))
                if case .failure(let error) = portrait {
                    Text(String(describing: error)).font(.caption2).foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.interaction, Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(portrait.isFailure)
        .accessibilityIdentifier("pet-\(pet.petId.rawValue)")
        .accessibilityLabel("\(pet.nameZh)，\(pet.numberLabel)")
        .accessibilityHint(portrait.isFailure ? "图片加载失败" : "查看精灵详情")
    }
}

private extension Result {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}
