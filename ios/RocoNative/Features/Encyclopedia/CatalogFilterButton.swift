import SwiftUI
import RocoContent

struct CatalogFilterButton: View {
    let content: ContentStore
    @Binding var query: PetCatalogQuery
    @Binding var ascending: Bool
    var topInset: CGFloat = 0
    var trailingInset: CGFloat = 0
    var onPresentationChange: (Bool) -> Void = { _ in }
    @State private var presented = false
    @State private var panelSize = CGSize(width: 168, height: 340)
    @Namespace private var glass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: close) {
                Color.clear.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(presented)
            .accessibilityHidden(true)

            GlassEffectContainer(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("筛选与排序").font(.subheadline.weight(.semibold))
                            Spacer(minLength: 8)
                            Button("关闭筛选", systemImage: "xmark", action: close)
                                .labelStyle(.iconOnly)
                                .frame(width: 44, height: 44)
                        }
                        .padding(.leading, 22)
                        .padding(.trailing, 8)
                        CatalogFilterSheet(content: content, query: $query, ascending: $ascending)
                    }
                    .fixedSize(horizontal: true, vertical: true)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { panelSize = $0 }
                    .opacity(presented ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16).delay(presented ? 0.08 : 0), value: presented)
                    .allowsHitTesting(presented)
                    .accessibilityHidden(!presented)

                    Button("筛选与排序", systemImage: "line.3.horizontal.decrease") {
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { presented = true }
                    }
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.medium))
                    .frame(width: 44, height: 44)
                    .opacity(presented ? 0 : 1)
                    .allowsHitTesting(!presented)
                    .accessibilityHidden(presented)
                    .accessibilityValue("\(query.filterCount) 项筛选，按\(query.sort.rawValue)排序")
                    .accessibilityIdentifier("catalog-filter-button")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .frame(width: presented ? panelSize.width : 44,
                    height: presented ? panelSize.height : 44, alignment: .topTrailing)
                .clipShape(RoundedRectangle(cornerRadius: presented ? 26 : 22))
                .background(reduceTransparency ? Color(uiColor: .secondarySystemBackground) : .clear,
                    in: RoundedRectangle(cornerRadius: presented ? 26 : 22))
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: presented ? 26 : 22))
                .glassEffectID("catalog-filter", in: glass)
                .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
                .accessibilityElement(children: .contain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, topInset)
            .padding(.trailing, trailingInset)
        }
        .onChange(of: presented) { onPresentationChange(presented) }
    }

    private func close() {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { presented = false }
    }
}
