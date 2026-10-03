/// A bounded window into filtered results. Empty results still have a valid page.
nonisolated struct CatalogPage {
    static let size = 24
    let totalCount: Int
    let pageCount: Int
    let number: Int
    let range: Range<Int>

    init(totalCount: Int, requestedPage: Int) {
        self.totalCount = max(0, totalCount)
        pageCount = max(1, self.totalCount / Self.size + (self.totalCount % Self.size == 0 ? 0 : 1))
        number = min(max(1, requestedPage), pageCount)
        let start = (number - 1) * Self.size
        range = start..<min(start + Self.size, self.totalCount)
    }
}
