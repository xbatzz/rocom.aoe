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
    @State private var encyclopedia = false
    @Query(sort: \TeamRecord.updatedAt, order: .reverse) private var teams: [TeamRecord]
    @Query private var shiny: [ShinyRecord]
    @Query private var heroes: [HeroRecord]
    private var featured: [Pet] {
        Array(content.orderedPets.filter { $0.implemented && $0.publicVisible && !$0.isLeader && $0.form == "default" }.prefix(3))
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
                                    Text("探索属性、技能与进化谱系").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.title3.weight(.semibold))
                            }
                            HStack(spacing: 4) {
                                ForEach(featured, id: \.petId) { pet in
                                    CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 92)
                                        .frame(maxWidth: .infinity)
                                }
                            }.accessibilityHidden(true)
                            HStack {
                                CompanionMetric(value: String(content.pets.count), label: "精灵配置")
                                CompanionMetric(value: String(content.skills.count), label: "技能配置")
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("离线可用").font(.caption.weight(.semibold)).foregroundStyle(.green)
                                    Text(content.seasons[content.manifest.defaultSeason]?.nameZh ?? "当前内容")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }.padding(20).companionSurface()
                    }.buttonStyle(.plain).accessibilityHint("打开精灵图鉴")

                    HStack(spacing: 12) {
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
                            HStack {
                                Text("配队").font(.headline)
                                Spacer()
                                Text(teams.first?.name ?? "组建第一支队伍").font(.subheadline).foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.caption)
                            }
                            if let build = teams.first.flatMap({ try? $0.decode() }) {
                                HStack(spacing: 4) {
                                    ForEach(build.slots.indices, id: \.self) { i in
                                        let asset = build.slots[i].petID.flatMap { content.pets[PetID(rawValue: $0)]?.portraitAssetId }
                                        CanonicalThumbnail(assetID: asset, content: content, size: 40).frame(maxWidth: .infinity)
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
                            Text("VS").font(.title2.bold()).foregroundStyle(.orange)
                        }.padding(20).companionSurface()
                    }.buttonStyle(.plain)
                    HStack {
                        NavigationLink("备份与恢复") { UserBackupView(content: content) }
                        Spacer()
                        NavigationLink("数据版本") { ContentVersionView(content: content) }
                    }.font(.subheadline).padding(.vertical, 8)
                }.padding(20)
            }.companionBackground().navigationTitle("洛克工具")
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
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }.padding(16)
    }

}

private struct ContentVersionView: View {
    let content: ContentStore
    var body: some View {
        List {
            Section("当前离线内容") {
                LabeledContent("内容版本", value: content.manifest.contentVersion)
                LabeledContent("规则版本", value: content.manifest.rulesVersion)
                LabeledContent("精灵", value: String(content.pets.count))
                LabeledContent("技能", value: String(content.skills.count))
                if let season = content.seasons[content.manifest.defaultSeason] {
                    LabeledContent("默认赛季", value: season.nameZh)
                }
            }
            Section("来源") {
                Text(content.manifest.sourceRevision).font(.footnote.monospaced()).textSelection(.enabled)
                Text("以上为当前安装包的内容快照。本机收藏与队伍独立保存，可通过备份与恢复导出。")
                    .font(.footnote).foregroundStyle(.secondary)
                LabeledContent("用户数据格式", value: String(UserDatabase.currentVersion))
            }
        }.navigationTitle("数据版本")
    }
}
