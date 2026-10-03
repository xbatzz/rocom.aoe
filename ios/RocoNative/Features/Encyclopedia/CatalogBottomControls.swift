import SwiftUI
import RocoContent

/// A single mounted surface grows to the right; its leading edge never changes.
struct CatalogBottomControls: View {
    @Binding var query: PetCatalogQuery
    let presentation: CatalogSearchPresentation
    @State private var searchFocused = false
    @Namespace private var glass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .body) private var controlHeight = 52

    var body: some View {
        GeometryReader { geometry in
            let height = min(72, max(52, controlHeight))
            let expansion = 1 - presentation.collapseProgress
            let width = height + (geometry.size.width - height) * expansion
            let clearWidth: CGFloat = query.keyword.isEmpty ? 0 : 44
            let cornerRadius = height / 2 + (22 - height / 2) * expansion
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 0) {
                    Button(action: expandSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.body.weight(.medium))
                            .frame(width: height, height: height)
                    }
                    .frame(width: height, height: height)
                    .contentShape(Rectangle())
                    .accessibilityLabel("搜索精灵")
                    .accessibilityValue(query.keyword)
                    .accessibilityIdentifier("catalog-search-button")

                    CatalogSearchField(text: $query.keyword, focused: $searchFocused)
                        .frame(width: max(0, geometry.size.width - height - 44 - clearWidth), alignment: .leading)
                        .frame(width: max(0, width - height - (44 + clearWidth) * expansion), alignment: .leading)
                        .opacity(expansion)
                        .clipped()
                        .allowsHitTesting(expansion > 0.01)
                        .accessibilityHidden(expansion < 0.01)
                        .accessibilityLabel("搜索精灵")
                        .accessibilityIdentifier("catalog-search-field")

                    Button { query.keyword = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: height)
                    }
                    .frame(width: clearWidth * expansion)
                    .opacity(query.keyword.isEmpty ? 0 : expansion)
                    .clipped()
                    .allowsHitTesting(expansion > 0.01 && !query.keyword.isEmpty)
                    .accessibilityHidden(expansion < 0.01 || query.keyword.isEmpty)
                    .accessibilityLabel("清除搜索")
                    .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: query.keyword.isEmpty)

                    Button {
                        searchFocused = false
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.32)) {
                            presentation.cancel()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: height)
                    }
                    .frame(width: 44 * expansion)
                    .opacity(expansion)
                    .clipped()
                    .allowsHitTesting(expansion > 0.01)
                    .accessibilityHidden(expansion < 0.01)
                    .accessibilityLabel("取消搜索")
                    .accessibilityIdentifier("catalog-search-close")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                // The field keeps its text layout while its leading-aligned reveal
                // and the enclosing surface follow the same continuous progress.
                .frame(width: width, height: height, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .background(reduceTransparency ? Color(uiColor: .secondarySystemBackground) : .clear,
                    in: RoundedRectangle(cornerRadius: cornerRadius))
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
                .glassEffectID("catalog-search", in: glass)
                .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
                .accessibilityElement(children: .contain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: min(72, max(52, controlHeight)))
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .onChange(of: searchFocused) {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.24)) {
                presentation.focusChanged(searchFocused)
            }
        }
        .onChange(of: query.keyword, initial: true) {
            presentation.keywordChanged(query.keyword)
        }
    }

    private func expandSearch() {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.32)) {
            presentation.expand()
        }
        // The same mounted input receives a first-responder request in this tap transaction.
        searchFocused = true
    }
}
