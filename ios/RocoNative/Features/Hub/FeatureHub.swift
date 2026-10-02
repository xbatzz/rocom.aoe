import SwiftUI
import RocoContent
import RocoUserData

/// Feature navigation surrounds, rather than replaces, the frozen encyclopedia stack.
struct NativeFeatureEntry: View {
    let content: ContentStore
    let portraits: PortraitStore
    let skills: SkillSearchIndex
    let tracking: TrackingCatalogIndex
    @State private var encyclopedia = false

    var body: some View {
        NavigationStack {
            List {
                Section("探索") {
                    Button { encyclopedia = true } label: { Label("图鉴", systemImage: "book.closed") }
                    NavigationLink { TypeMatchupView(content: content) } label: { Label("属性克制", systemImage: "arrow.triangle.branch") }
                    NavigationLink { SkillsView(content: content, portraits: portraits, index: skills) } label: { Label("技能查询", systemImage: "sparkles") }
                }
                Section("收藏工具") {
                    NavigationLink { ShinyCollectionView(content: content, index: tracking) } label: { Label("异色收集", systemImage: "star") }
                    NavigationLink { GrassBadgeView(content: content, index: tracking) } label: { Label("草系徽章", systemImage: "leaf") }
                    NavigationLink { DestinedHeroView(content: content, index: tracking) } label: { Label("命定勇者", systemImage: "medal") }
                }
                Section("战斗工具") {
                    NavigationLink { TeamBuilderView(content: content, portraits: portraits, skillIndex: skills) } label: { Label("配队", systemImage: "person.3") }
                    NavigationLink { PVPBattleView(content: content, portraits: portraits, skillIndex: skills) } label: { Label("PVP 助手", systemImage: "bolt.shield") }
                }
                Section("用户数据") {
                    NavigationLink { UserBackupView(content: content) } label: { Label("备份与恢复", systemImage: "externaldrive") }
                    NavigationLink { ContentVersionView(content: content) } label: { Label("数据版本", systemImage: "info.circle") }
                }
            }.navigationTitle("洛克工具")
        }
        .fullScreenCover(isPresented: $encyclopedia) {
            ZStack(alignment: .bottomTrailing) {
                AlignedNavigation(content: content, portraits: portraits).ignoresSafeArea()
                Button("功能首页", systemImage: "house") { encyclopedia = false }
                    .buttonStyle(.borderedProminent).padding()
            }
        }
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
