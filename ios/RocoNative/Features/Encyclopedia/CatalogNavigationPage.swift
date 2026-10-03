import SwiftUI
import RocoContent

/// Home navigation uses the system push/pop; pet details retain their local image-only stack.
struct CatalogNavigationPage: View {
    let content: ContentStore
    let portraits: PortraitStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AlignedNavigation(content: content, portraits: portraits, returnToHome: { dismiss() })
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
    }
}
