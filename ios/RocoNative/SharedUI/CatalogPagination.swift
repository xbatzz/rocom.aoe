import SwiftUI

struct CatalogPagination: View {
    let window: CatalogPage
    @Binding var page: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if window.totalCount > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("第 \(window.range.lowerBound + 1)–\(window.range.upperBound) 项 · 共 \(window.totalCount) 项")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .accessibilityIdentifier("pagination-range")
                if window.pageCount > 1 {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 8) { controls }
                        } else {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 12) { controls }.fixedSize(horizontal: true, vertical: false)
                                VStack(alignment: .leading, spacing: 8) { controls }
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.primary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var controls: some View {
        Button("上一页", systemImage: "chevron.left") { page = window.number - 1 }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.bordered).controlSize(.large).tint(.primary)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(window.number == 1)
            .accessibilityIdentifier("pagination-previous")
        Menu {
            Picker("页码", selection: Binding(get: { window.number }, set: { page = $0 })) {
                ForEach(1...window.pageCount, id: \.self) { number in
                    Text("第 \(number) / \(window.pageCount) 页").tag(number)
                }
            }
        } label: {
            Text("\(window.number) / \(window.pageCount) 页").monospacedDigit().fixedSize()
        }
        .accessibilityLabel("跳转页码")
        .accessibilityValue("第 \(window.number) 页，共 \(window.pageCount) 页")
        .accessibilityIdentifier("pagination-page")
        .buttonStyle(.bordered).controlSize(.large).tint(.primary)
        Button("下一页", systemImage: "chevron.right") { page = window.number + 1 }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.bordered).controlSize(.large).tint(.primary)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(window.number == window.pageCount)
            .accessibilityIdentifier("pagination-next")
    }
}
