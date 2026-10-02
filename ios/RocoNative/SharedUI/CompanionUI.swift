import SwiftUI
import RocoContent
import RocoDomain

/// Small, audited presentation vocabulary shared by the home, battle and collection views.
enum GameIconCatalog {
    private static let typeImages: [Int: UIImage] = Dictionary(uniqueKeysWithValues: (1...18).compactMap { id in
        image("type-\(id)").map { (id, $0) }
    })
    static func type(_ id: TypeID) -> UIImage? { typeImages[id.rawValue] }
    static let leader = image("leader-crown")
    static let collected = image("collected-check")
    private static func image(_ name: String) -> UIImage? {
        Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "GameIcons")
            .flatMap { UIImage(contentsOfFile: $0.path) }
    }
    static func color(_ id: TypeID) -> Color {
        switch id.rawValue {
        case 2: .green
        case 3: .orange
        case 4: .blue
        case 5, 9: .yellow
        case 6, 12: .brown
        case 7, 13: .cyan
        case 8, 10, 15, 18: .purple
        case 11: .mint
        case 14: .pink
        default: .gray
        }
    }
}

struct TypeBadge: View {
    let type: BattleType
    var body: some View {
        HStack(spacing: 4) {
            if let image = GameIconCatalog.type(type.typeId) {
                Image(uiImage: image).resizable().scaledToFit().frame(width: 22, height: 22).accessibilityHidden(true)
            }
            Text(type.nameZh).font(.caption.weight(.semibold)).fixedSize()
        }
        .padding(.leading, 4).padding(.trailing, 8).padding(.vertical, 3)
        .background(GameIconCatalog.color(type.typeId).opacity(0.12), in: Capsule())
        .accessibilityElement(children: .ignore).accessibilityLabel("\(type.nameZh)属性")
    }
}

struct PetTypes: View {
    let pet: Pet
    let content: ContentStore
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { badges }
            VStack(alignment: .leading, spacing: 4) { badges }
        }
    }
    @ViewBuilder private var badges: some View {
        ForEach(pet.typeIds, id: \.self) { id in
            if let type = content.types[id] { TypeBadge(type: type) }
        }
    }
}

extension SkillCategory {
    var displayName: String {
        switch self {
        case .physicalAttack: "物理攻击"
        case .magicAttack: "魔法攻击"
        case .status: "变化"
        case .defense: "防御"
        case .unknown: "未分类"
        }
    }
}

struct SkillCategoryPill: View {
    let category: SkillCategory
    var body: some View {
        Text(category.displayName).font(.caption.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
    }
}

struct CompanionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold()).foregroundStyle(.primary).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct CompanionMetric: View {
    let value: String
    let label: String
    var tint: Color = .primary
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }
}

struct CollectionProgress: View {
    let title: String
    let count: Int
    let total: Int
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(count.formatted()).font(.largeTitle.bold().monospacedDigit()).foregroundStyle(tint)
                Text("/ \(total.formatted())").font(.title3.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Text(title).font(.subheadline.weight(.medium))
            }
            ProgressView(value: Double(count), total: Double(max(1, total))).tint(tint)
                .accessibilityLabel(title).accessibilityValue("\(count) / \(total)")
        }.padding(20).companionSurface()
    }
}

struct CollectionStatus: View {
    let selected: Bool
    var selectedTitle = "已收集"
    var idleTitle = "未收集"
    var tint: Color = .green
    var body: some View {
        HStack(spacing: 4) {
            if selected, let image = GameIconCatalog.collected {
                Image(uiImage: image).resizable().scaledToFit().frame(width: 18, height: 18).accessibilityHidden(true)
            }
            Text(selected ? selectedTitle : idleTitle).font(.caption.weight(.semibold))
        }.foregroundStyle(selected ? tint : .secondary)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background((selected ? tint : Color.secondary).opacity(0.10), in: Capsule())
    }
}

extension View {
    func companionSurface() -> some View {
        background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
    func companionBackground() -> some View {
        background(Color(uiColor: .systemGroupedBackground))
    }
}

struct CompanionSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CompanionHeading(title: title)
            content
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TeamPetTile: View {
    let slot: TeamSlot
    let content: ContentStore
    var label: String? = nil
    private var pet: Pet? { slot.petID.flatMap { content.pets[PetID(rawValue: $0)] } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let label { Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
            if let pet {
                CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 88).frame(maxWidth: .infinity)
                Text(pet.nameZh).font(.headline).fixedSize(horizontal: false, vertical: true)
                PetTypes(pet: pet, content: content)
                Text("\(slot.skillIDs.count) / 4 技能").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            } else {
                Image(systemName: "plus").font(.title2.weight(.medium)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 88).accessibilityHidden(true)
                Text(slot.petID.map { "无法解析 #\($0)" } ?? "选择精灵").font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(slot.petID == nil ? "搭配属性与技能" : "原构筑保留").font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).companionSurface()
    }
}
