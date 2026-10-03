#if DEBUG
import SwiftUI
import RocoContent

/// Deterministic geometry review of the production controls in both scroll states.
struct CatalogControlsReview: View {
    let content: ContentStore
    @State private var ascending = true
    @State private var searchPresentation = CatalogSearchPresentation()
    @State private var compact = false
    @State private var query: PetCatalogQuery = {
        var query = PetCatalogQuery()
        query.leader = .leader
        return query
    }()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            Button("切换滚动控制状态") {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { compact.toggle() }
            }
            .accessibilityIdentifier("review-toggle-compact")
            .padding()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CatalogBottomControls(query: $query, presentation: searchPresentation)
        }
        .navigationTitle("控制层布局验证")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CatalogFilterButton(content: content, query: $query, ascending: $ascending)
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }
}
#endif
