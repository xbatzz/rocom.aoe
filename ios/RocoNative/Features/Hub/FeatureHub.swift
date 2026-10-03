import SwiftUI
import RocoContent
import RocoUserData
import RocoDomain
import SwiftData

/// Feature navigation surrounds, rather than replaces, the frozen encyclopedia stack.
struct NativeFeatureEntry: View {
    let content: ContentStore
    let portraits: PortraitStore
    let skills: SkillSearchIndex
    let tracking: TrackingCatalogIndex
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var encyclopedia = false
    @Query(sort: \TeamRecord.updatedAt, order: .reverse) private var teams: [TeamRecord]
    @Query private var shiny: [ShinyRecord]
    @Query private var heroes: [HeroRecord]
    private var featured: [Pet] {
        Array(content.orderedPets.filter { $0.implemented && $0.publicVisible && !$0.isLeader && $0.form == "default" }.prefix(3))
    }

    private var toolLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Button { encyclopedia = true } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("精灵图鉴").font(.title2.bold())
                                    Text("属性、技能与进化谱系").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !dynamicTypeSize.isAccessibilitySize { Image(systemName: "arrow.up.right").font(.title3.weight(.semibold)) }
                            }
                            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(spacing: 4))) {
                                ForEach(dynamicTypeSize.isAccessibilitySize ? Array(featured.prefix(1)) : featured, id: \.petId) { pet in
                                    VStack(spacing: 8) {
                                        CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 92)
                                        PetTypes(pet: pet, content: content)
                                    }.frame(maxWidth: .infinity)
                                }
                            }.accessibilityHidden(true)
                            CompanionMetrics {
                                CompanionMetric(value: String(content.pets.count), label: "精灵配置")
                                CompanionMetric(value: String(content.skills.count), label: "技能配置")
                                VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                                    Text("离线可用").font(.caption.weight(.semibold)).foregroundStyle(.green)
                                    Text(content.seasons[content.manifest.defaultSeason]?.nameZh ?? "当前内容")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }.padding(20).companionAccentSurface(tint: .teal)
                    }.buttonStyle(.plain).accessibilityHint("打开精灵图鉴")

                    toolLayout {
                        NavigationLink { TypeMatchupView(content: content) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 4) {
                                    ForEach([2, 3, 4], id: \.self) { id in
                                        if let image = GameIconCatalog.type(TypeID(rawValue: id)) {
                                            Image(uiImage: image).resizable().scaledToFit().frame(width: 28, height: 28)
                                        }
                                    }
                                }.accessibilityHidden(true)
                                Text("属性克制").font(.headline)
                                Text("进攻与联防").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).companionSurface()
                        }
                        NavigationLink { SkillsView(content: content, portraits: portraits, index: skills) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                if let skill = content.skills.values.sorted(by: { $0.skillId.rawValue < $1.skillId.rawValue }).first(where: { $0.iconAssetId != nil }) {
                                    CanonicalThumbnail(assetID: skill.iconAssetId, content: content, size: 28)
                                }
                                Text("技能查询").font(.headline)
                                Text("威力、能耗与来源").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).companionSurface()
                        }
                    }.buttonStyle(.plain)

                    CompanionHeading(title: "我的收藏")
                    VStack(spacing: 0) {
                        NavigationLink { ShinyCollectionView(content: content, index: tracking) } label: {
                            homeCollection("异色收集", count: shiny.filter { $0.collected && content.shinySlots[ShinySlotID(rawValue: $0.slotID)] != nil }.count,
                                total: content.shinySlots.count, tint: .purple, asset: content.shinySlots.values.sorted { $0.slotId.rawValue < $1.slotId.rawValue }.first?.portraitAssetId)
                        }
                        Divider().padding(.leading, 74)
                        NavigationLink { GrassBadgeView(content: content, index: tracking) } label: {
                            homeCollection("草系徽章", subtitle: "按地点记录家族足迹", asset: tracking.badgeFamilies.first.flatMap { content.pets[$0.representativePetId]?.portraitAssetId })
                        }
                        Divider().padding(.leading, 74)
                        NavigationLink { DestinedHeroView(content: content, index: tracking) } label: {
                            homeCollection("命定勇者", count: heroes.filter { record in record.obtained && tracking.badgeFamilies.contains(where: { $0.familyKey.rawValue == record.familyID }) }.count,
                                total: tracking.badgeFamilies.count, tint: .orange, asset: tracking.badgeFamilies.dropFirst().first.flatMap { content.pets[$0.representativePetId]?.portraitAssetId })
                        }
                    }.buttonStyle(.plain).companionSurface()

                    CompanionHeading(title: "战斗准备", detail: "\(teams.count) 支队伍")
                    NavigationLink { TeamBuilderView(content: content, portraits: portraits, skillIndex: skills) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("配队").font(.headline)
                                    Text(teams.first?.name ?? "组建第一支队伍").font(.subheadline).foregroundStyle(.secondary)
                                }
                            } else {
                                HStack {
                                    Text("配队").font(.headline)
                                    Spacer()
                                    Text(teams.first?.name ?? "组建第一支队伍").font(.subheadline).foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right").font(.caption)
                                }
                            }
                            if let build = teams.first.flatMap({ try? $0.decode() }) {
                                HStack(spacing: 4) {
                                    ForEach(build.slots.indices, id: \.self) { i in
                                        Group {
                                            if let petID = build.slots[i].petID {
                                                CanonicalThumbnail(assetID: content.pets[PetID(rawValue: petID)]?.portraitAssetId, content: content, size: 40)
                                            } else {
                                                Text(String(format: "%02d", i + 1)).font(.system(size: 14, weight: .medium).monospacedDigit())
                                                    .foregroundStyle(.secondary).frame(width: 40, height: 40)
                                                    .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                                                    .accessibilityLabel("槽位 \(i + 1)，未配置")
                                            }
                                        }.frame(maxWidth: .infinity)
                                    }
                                }
                            } else {
                                Text("六个槽位，搭配属性、血脉与技能。").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }.padding(20).companionSurface()
                    }.buttonStyle(.plain)
                    NavigationLink { PVPBattleView(content: content, portraits: portraits, skillIndex: skills) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PVP 助手").font(.headline)
                                Text("双方构筑 · 伤害与一击线").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !dynamicTypeSize.isAccessibilitySize { Text("VS").font(.title2.bold()).foregroundStyle(.orange) }
                        }.padding(20).companionSurface()
                    }.buttonStyle(.plain)
                    toolLayout {
                        NavigationLink("备份与恢复") { UserBackupView(content: content) }
                        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                        NavigationLink("数据版本") { ContentVersionView(content: content) }
                    }.font(.subheadline).padding(.vertical, 8)
                }.padding(20)
            }.reviewScrollPosition().companionBackground().navigationTitle("洛克工具")
        }
        .fullScreenCover(isPresented: $encyclopedia) {
            ZStack(alignment: .bottomTrailing) {
                AlignedNavigation(content: content, portraits: portraits).ignoresSafeArea()
                Button("功能首页", systemImage: "house") { encyclopedia = false }
                    .buttonStyle(.borderedProminent).padding()
            }
        }
    }
    private func homeCollection(_ title: String, count: Int? = nil, total: Int = 0, tint: Color = .green, subtitle: String? = nil, asset: AssetID?) -> some View {
        HStack(spacing: 12) {
            CanonicalThumbnail(assetID: asset, content: content)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                if let count {
                    Text("\(count) / \(total) 已收集").font(.caption.monospacedDigit()).foregroundStyle(tint)
                    ProgressView(value: Double(count), total: Double(max(1, total))).tint(tint)
                } else if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
        }.padding(16)
    }

}

struct ContentVersionView: View {
    let content: ContentStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                CompanionSection("当前离线内容") {
                    if let season = content.seasons[content.manifest.defaultSeason] { Text(season.nameZh).font(.title2.bold()) }
                    CompanionMetrics {
                        CompanionMetric(value: String(content.pets.count), label: "精灵配置")
                        CompanionMetric(value: String(content.skills.count), label: "技能配置")
                    }.padding(20).companionSurface()
                    LabeledContent("规则版本", value: content.manifest.rulesVersion)
                }
                CompanionSection("内容标识") {
                    Text(content.manifest.contentVersion).font(.footnote.monospaced()).textSelection(.enabled)
                }
                CompanionSection("内容来源") {
                    Text(content.manifest.sourceRevision).font(.footnote.monospaced()).textSelection(.enabled)
                    Text("当前安装包的内容快照。本机收藏与队伍独立保存，可通过备份与恢复导出。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    LabeledContent("用户数据格式", value: String(UserDatabase.currentVersion))
                }
            }.padding(20)
        }.reviewScrollPosition().companionBackground().navigationTitle("数据版本")
    }
}
