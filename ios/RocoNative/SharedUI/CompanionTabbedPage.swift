import SwiftUI

/// Each section starts at the top when selected; the owning page retains its
/// configuration and filter state while inactive sections leave the view tree.
struct CompanionTabbedPage<Selection: Hashable & RawRepresentable, Content: View>: View where Selection.RawValue == String {
    let title: String
    @Binding var selection: Selection
    let options: [Selection]
    let identifier: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .id("section-top")
            }
            .scrollDismissesKeyboard(.interactively)
            .reviewScrollPosition()
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    CompanionTabBar(title: title, selection: $selection, options: options, identifier: identifier)
                        .padding(.horizontal, 20).padding(.vertical, 6)
                    Divider()
                }.background(Color(uiColor: .systemGroupedBackground))
            }
            .onChange(of: selection) { proxy.scrollTo("section-top", anchor: .top) }
        }.companionBackground()
    }
}
