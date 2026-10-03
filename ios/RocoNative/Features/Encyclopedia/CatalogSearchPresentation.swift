import SwiftUI

/// Presentation-only browsing intent. Scroll samples never start an animation.
@Observable @MainActor
final class CatalogSearchPresentation {
    private(set) var collapseProgress: CGFloat = 0
    private(set) var isSearching = false
    private var keywordIsEmpty = true
    private var scrollOrigin: CGFloat?
    private var originProgress: CGFloat = 0
    private var lastOffset: CGFloat = 0

    func scroll(to offset: CGFloat, userScrolling: Bool) {
        let previousOffset = lastOffset
        lastOffset = offset
        guard userScrolling, !isSearching, keywordIsEmpty else { return }
        if scrollOrigin == nil {
            scrollOrigin = previousOffset
            originProgress = collapseProgress
        }
        // Ignore small reading adjustments; then morph over 100 points of travel.
        let travel = offset - (scrollOrigin ?? offset)
        let progress = originProgress + max(0, travel - 20) / 100
        collapseProgress = min(1, max(0, progress))
    }

    func focusChanged(_ focused: Bool) {
        isSearching = focused
        scrollOrigin = nil
        if focused { collapseProgress = 0 }
    }

    func keywordChanged(_ keyword: String) {
        keywordIsEmpty = keyword.isEmpty
        scrollOrigin = nil
        if !keywordIsEmpty { collapseProgress = 0 }
    }

    func expand() {
        isSearching = true
        collapseProgress = 0
        scrollOrigin = nil
    }

    func cancel() {
        isSearching = false
        collapseProgress = keywordIsEmpty ? 1 : 0
        scrollOrigin = nil
    }
}
