import SwiftUI
import UIKit
import RocoDomain
import RocoContent

/// Pure SwiftUI experiment.
///
/// This branch deliberately removes the UIKit navigation/zoom bridge from the
/// active path. NavigationStack + matchedTransitionSource + navigationTransition
/// own the push, pop, interactive gesture, navigation bar, and zoom lifecycle.
///
/// The old UIKit bridge file name is retained so RocoApp does not need a second
/// integration path while this experiment is evaluated on a real device.
struct AlignedNavigation: View {
    let content: ContentStore
    let portraits: PortraitStore

    @Namespace private var zoomNamespace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("认识每一只精灵。")
                        .font(.title3)
                        .foregroundStyle(.primary.opacity(0.72))

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 20)],
                        spacing: 28
                    ) {
                        ForEach(content.orderedPets, id: \.petId) { pet in
                            NativePetGridCell(
                                pet: pet,
                                portraits: portraits,
                                namespace: zoomNamespace
                            )
                        }
                    }
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("图鉴")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: PetID.self) { petID in
                destination(for: petID)
            }
        }
    }

    @ViewBuilder
    private func destination(for petID: PetID) -> some View {
        if let pet = content.pets[petID] {
            switch Result(catching: { try portraits.image(for: pet) }) {
            case .success(let image):
                PetDetail(
                    pet: pet,
                    content: content,
                    image: image,
                    anchors: nil
                )
                .navigationTitle(pet.nameZh)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTransition(
                    .zoom(sourceID: pet.petId, in: zoomNamespace)
                )

            case .failure(let error):
                ContentUnavailableView(
                    "图片加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(String(describing: error))
                )
                .navigationTitle(pet.nameZh)
                .navigationBarTitleDisplayMode(.inline)
            }
        } else {
            ContentUnavailableView(
                "找不到精灵",
                systemImage: "questionmark.folder"
            )
        }
    }
}

private struct NativePetGridCell: View {
    let pet: Pet
    let portraits: PortraitStore
    let namespace: Namespace.ID

    var body: some View {
        let portrait = Result(catching: { try portraits.image(for: pet) })

        NavigationLink(value: pet.petId) {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    switch portrait {
                    case .success(let image):
                        GeometryReader { geometry in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    width: geometry.size.width * 0.84,
                                    height: geometry.size.height * 0.84
                                )
                                .position(
                                    x: geometry.size.width / 2,
                                    y: geometry.size.height / 2
                                )
                                // Only the portrait is the transition source. The
                                // NavigationStack itself remains entirely SwiftUI.
                                .matchedTransitionSource(
                                    id: pet.petId,
                                    in: namespace
                                )
                        }

                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                            Text("图片加载失败")
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .allowsHitTesting(false)

                Text(pet.nameZh)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pet.numberLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary.opacity(0.72))

                if case .failure(let error) = portrait {
                    Text(String(describing: error))
                        .font(.caption2)
                        .foregroundStyle(.red)
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
        if case .failure = self {
            return true
        }
        return false
    }
}
