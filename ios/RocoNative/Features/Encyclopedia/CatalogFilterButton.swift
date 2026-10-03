import SwiftUI
import RocoContent

struct CatalogFilterButton: View {
    let content: ContentStore
    @Binding var query: PetCatalogQuery
    @Binding var ascending: Bool
    @State private var presented = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button("筛选与排序", systemImage: "line.3.horizontal.decrease") {
            presented.toggle()
        }
        .labelStyle(.iconOnly)
        .font(.body.weight(.medium))
        .frame(width: 44, height: 44)
        .buttonStyle(.plain)
        .background(reduceTransparency ? Color(uiColor: .secondarySystemBackground) : .clear, in: Circle())
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityValue("\(query.filterCount) 项筛选，按\(query.sort.rawValue)排序")
        .accessibilityIdentifier("catalog-filter-button")
        .popover(isPresented: $presented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            CatalogFilterSheet(content: content, query: $query, ascending: $ascending)
                .presentationCompactAdaptation(.popover)
                .presentationBackground(.clear)
        }
    }
}
