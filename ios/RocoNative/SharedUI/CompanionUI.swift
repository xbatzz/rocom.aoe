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

struct CompanionHeading: View {
    let title: String
    var detail: String? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) { heading; detailText }
        } else {
            HStack(alignment: .firstTextBaseline) { heading; Spacer(minLength: 8); detailText }
        }
    }
    private var heading: some View {
        Text(title).font(.title3.bold()).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }
    @ViewBuilder private var detailText: some View {
        if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
    }
}

struct CompanionMetric: View {
    let value: String
    let label: String
    var tint: Color = .primary
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(tint)
                .fixedSize(horizontal: true, vertical: true)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                Text(title).font(.subheadline.weight(.medium))
                totalText
            } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(count.formatted()).font(.largeTitle.bold().monospacedDigit()).foregroundStyle(tint)
                Text("/ \(total.formatted())").font(.title3.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Text(title).font(.subheadline.weight(.medium))
            }
            }
            ProgressView(value: Double(count), total: Double(max(1, total))).tint(tint)
                .accessibilityLabel(title).accessibilityValue("\(count) / \(total)")
        }.padding(20).companionAccentSurface(tint: tint)
    }
    private var totalText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(count.formatted()).font(.largeTitle.bold().monospacedDigit()).foregroundStyle(tint)
            Text("共 \(total.formatted())").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
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
    func companionPrimaryAction() -> some View {
        buttonStyle(.borderedProminent).controlSize(.large).tint(.primary)
            .foregroundStyle(Color(uiColor: .systemBackground))
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
    var compact = false
    private var pet: Pet? { slot.petID.flatMap { content.pets[PetID(rawValue: $0)] } }
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            if let label { Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
            if let pet {
                CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: compact ? 60 : 88).frame(maxWidth: .infinity)
                Text(pet.nameZh).font(.headline).fixedSize(horizontal: false, vertical: true)
                PetTypes(pet: pet, content: content)
                Text("\(slot.skillIDs.count) / 4 技能").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            } else {
                Image(systemName: "plus").font(.title2.weight(.medium)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: compact ? 44 : 88).accessibilityHidden(true)
                Text(slot.petID.map { "无法解析 #\($0)" } ?? "选择精灵").font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(slot.petID == nil ? "搭配属性与技能" : "原构筑保留").font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(compact ? 12 : 16)
            .companionAccentSurface(tint: pet?.typeIds.first.map(GameIconCatalog.color) ?? .clear)
    }
}

// Debug screenshot positioning has no effect on Release behavior.
extension View {
    @ViewBuilder func reviewScrollPosition() -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--visual-bottom") {
            self.defaultScrollAnchor(.bottom)
        } else if ProcessInfo.processInfo.arguments.contains("--visual-middle") {
            self.defaultScrollAnchor(.center)
        } else if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--visual-anchor"),
            ProcessInfo.processInfo.arguments.indices.contains(index + 1),
            let y = Double(ProcessInfo.processInfo.arguments[index + 1]), (0...1).contains(y) {
            self.defaultScrollAnchor(UnitPoint(x: 0.5, y: y))
        } else { self }
        #else
        self
        #endif
    }
}

struct SkillSummary: View {
    let skill: Skill
    let content: ContentStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) { artwork; name }
                    skillBadges
                    CompanionMetrics {
                        if let power = skill.power { CompanionMetric(value: power.formatted(), label: "威力") }
                        if let cost = skill.energyCost { CompanionMetric(value: cost.formatted(), label: "能耗") }
                    }
                    identifier
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    artwork
                    VStack(alignment: .leading, spacing: 8) { name; skillBadges; identifier }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 6) {
                        if let power = skill.power {
                            Text(power.formatted()).font(.title3.bold().monospacedDigit())
                            Text("威力").font(.caption2).foregroundStyle(.secondary)
                        }
                        if let cost = skill.energyCost { Text("\(cost.formatted()) 能耗").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                    }
                }
            }
        }.padding(.vertical, 16)
    }
    @ViewBuilder private var artwork: some View {
        if let icon = content.skillIcon(for: skill) {
            CanonicalThumbnail(assetID: icon, content: content, size: 52)
        } else {
            Text(String(skill.nameZh.prefix(1))).font(.system(size: 22, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 52, height: 52).background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("暂无技能图标")
        }
    }
    private var name: some View { Text(skill.nameZh).font(.headline).fixedSize(horizontal: false, vertical: true) }
    private var identifier: some View { Text("#\(String(skill.skillId.rawValue))").font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }
    private var skillBadges: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { badges }
            VStack(alignment: .leading, spacing: 4) { badges }
        }
    }
    @ViewBuilder private var badges: some View {
        if let id = skill.typeId, let type = content.types[id] { TypeBadge(type: type) }
        SkillCategoryPill(category: skill.category)
    }
}

struct CompanionMetrics<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 16) { content }
        } else {
            HStack(alignment: .top, spacing: 12) { content }
        }
    }
}

struct BadgeLocationPicker: View {
    let content: ContentStore
    @Binding var selection: BadgeLocationLocationId
    var body: some View {
        Menu {
            Picker("地点", selection: $selection) {
                ForEach(content.badgeLocations.values.sorted { $0.locationId.rawValue < $1.locationId.rawValue }, id: \.locationId) {
                    Text($0.nameZh).tag($0.locationId)
                }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(content.badgeLocations[selection]?.nameZh ?? selection.rawValue)
                    .font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
            }.frame(minHeight: 44)
        }.tint(.primary).accessibilityLabel("地点：\(content.badgeLocations[selection]?.nameZh ?? selection.rawValue)")
    }
}
