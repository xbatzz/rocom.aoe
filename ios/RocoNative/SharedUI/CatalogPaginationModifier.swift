import SwiftUI

/// Filter edits reset the page; record edits only clamp a page that no longer exists.
private struct CatalogPaginationModifier: ViewModifier {
    @Binding var page: Int
    let totalCount: Int
    let resetKey: [AnyHashable]

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: resetKey) { page = 1; proxy.scrollTo("catalog-results-top", anchor: .top) }
                .onChange(of: totalCount) { page = CatalogPage(totalCount: totalCount, requestedPage: page).number }
                .onChange(of: page) { proxy.scrollTo("catalog-results-top", anchor: .top) }
        }
    }
}

extension View {
    func catalogPagination(page: Binding<Int>, totalCount: Int, resetKey: [AnyHashable]) -> some View {
        modifier(CatalogPaginationModifier(page: page, totalCount: totalCount, resetKey: resetKey))
    }
}
