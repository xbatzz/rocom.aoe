import SwiftUI
import UIKit

/// Shares the encyclopedia's phase-driven chrome without owning page content.
private struct CompanionPageChromeModifier: ViewModifier {
    let identifier: String
    var query: Binding<String>?
    let prompt: String
    let searchLabel: String
    let makeMenu: (() -> UIMenu)?
    let menuLabel: String
    let menuSymbol: String
    @Environment(\.dismiss) private var dismiss
    @State private var visible = true

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, phase, _ in visible = phase == .idle }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .background {
                CompanionScrollChrome(query: query ?? .constant(""), visible: visible,
                    prompt: prompt, searchLabel: searchLabel, identifier: identifier,
                    returnToParent: { dismiss() }, makeMenu: makeMenu,
                    hasSearch: query != nil, menuLabel: menuLabel, menuSymbol: menuSymbol)
                    .frame(width: 0, height: 0)
            }
    }
}

extension View {
    func companionPageChrome(identifier: String, query: Binding<String>? = nil,
        prompt: String = "", searchLabel: String = "", makeMenu: (() -> UIMenu)? = nil,
        menuLabel: String = "筛选", menuSymbol: String = "line.3.horizontal.decrease") -> some View {
        modifier(CompanionPageChromeModifier(identifier: identifier, query: query,
            prompt: prompt, searchLabel: searchLabel, makeMenu: makeMenu,
            menuLabel: menuLabel, menuSymbol: menuSymbol))
    }
}
