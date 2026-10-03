import SwiftUI
import RocoContent

/// Relative lengths compare this pet's six canonical base stats; values remain the source of truth.
struct PetStatChart: View {
    let pet: Pet
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var values: [(label: String, value: Int)] {
        let stats = pet.baseStats
        return [("生命", stats.hp), ("物攻", stats.physicalAttack), ("魔攻", stats.magicalAttack),
                ("物防", stats.physicalDefense), ("魔防", stats.magicalDefense), ("速度", stats.speed)]
    }

    var body: some View {
        let maximum = max(1, values.map(\.value).max() ?? 1)
        let tint = pet.typeIds.first.map(GameIconCatalog.color) ?? .teal
        VStack(alignment: .leading, spacing: 14) {
            ForEach(values, id: \.label) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(stat.label).foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        Text(stat.value.formatted()).font(.headline.monospacedDigit())
                    }
                    if !dynamicTypeSize.isAccessibilitySize {
                        GeometryReader { geometry in
                            Capsule().fill(tint.opacity(0.10))
                            Capsule().fill(tint.gradient)
                                .frame(width: geometry.size.width * CGFloat(max(0, stat.value)) / CGFloat(maximum))
                        }.frame(height: 5).accessibilityHidden(true)
                    }
                }.accessibilityElement(children: .combine)
            }
            Divider()
            LabeledContent("总种族值") {
                Text(values.reduce(0) { $0 + $1.value }.formatted()).font(.title2.bold().monospacedDigit()).foregroundStyle(.primary)
            }
        }
    }
}
