import SwiftUI
import RocoContent

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
                    NavigationLink { TeamBuilderView(content: content) } label: { Label("配队", systemImage: "person.3") }
                    planned("PVP 助手", "bolt.shield")
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
    private func planned(_ name: String, _ symbol: String) -> some View {
        LabeledContent { Text("待实现").foregroundStyle(.secondary) } label: { Label(name, systemImage: symbol) }
    }
}
