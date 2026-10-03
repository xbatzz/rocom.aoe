import SwiftUI
import RocoContent

/// Home navigation owns the catalog chrome; the private UIKit stack is used only
/// for the image-only pet-detail transition.
struct CatalogNavigationPage: View {
    let content: ContentStore
    let portraits: PortraitStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = PetCatalogQuery()
    @State private var ascending = true
    @State private var chromeVisible = true
    @State private var detailPresented = false
    @State private var detailPopRequest = 0

    var body: some View {
        AlignedNavigation(
            content: content,
            portraits: portraits,
            query: $query,
            ascending: $ascending,
            chromeVisible: $chromeVisible,
            detailPopRequest: detailPopRequest,
            onDetailVisibilityChanged: { detailPresented = $0 },
            returnToHome: { dismiss() }
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .background {
            CatalogFilterToolbar(
                content: content,
                query: $query,
                ascending: $ascending,
                chromeVisible: chromeVisible,
                detailPresented: detailPresented,
                returnToParent: { dismiss() },
                popDetail: { detailPopRequest &+= 1 }
            )
            .frame(width: 0, height: 0)
        }
    }
}
