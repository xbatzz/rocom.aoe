import SwiftUI
import RocoContent
import RocoDomain

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
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

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
            // Use the exact same shared chrome bridge as SkillsView and the other
            // top-level pages. The catalog only supplies its query/menu semantics.
            CompanionScrollChrome(
                query: keywordBinding,
                visible: chromeVisible,
                prompt: "名称、编号或配置 ID",
                searchLabel: "搜索精灵",
                identifier: "catalog",
                returnToParent: {
                    if detailPresented {
                        detailPopRequest &+= 1
                    } else {
                        dismiss()
                    }
                },
                makeMenu: makeFilterMenu,
                filterValue: "\(query.filterCount) 项筛选，按\(query.sort.rawValue)排序，\(ascending ? "升序" : "降序")",
                chromeEnabled: !detailPresented,
                keepLeadingWhenDisabled: detailPresented
            )
            .frame(width: 0, height: 0)
        }
        }
    }

    private var keywordBinding: Binding<String> {
        Binding(
            get: { query.keyword },
            set: { keyword in
                guard query.keyword != keyword else { return }
                var value = query
                value.keyword = keyword
                query = value
            }
        )
    }

    private func makeFilterMenu() -> UIMenu {
        let queryBinding = $query
        let ascendingBinding = $ascending
        let value = query

        func action(
            title: String,
            image: String? = nil,
            selected: Bool,
            change: @escaping (inout PetCatalogQuery) -> Void
        ) -> UIAction {
            UIAction(
                title: title,
                image: image.flatMap { UIImage(systemName: $0) },
                state: selected ? .on : .off
            ) { _ in
                var next = queryBinding.wrappedValue
                change(&next)
                queryBinding.wrappedValue = next
            }
        }

        func typeMenu(title: String, selected: TypeID?, slot: Int) -> UIMenu {
            var children: [UIMenuElement] = [
                action(title: "全部", selected: selected == nil) {
                    if slot == 0 { $0.firstType = nil } else { $0.secondType = nil }
                }
            ]
            children += content.catalogTypes.map { type in
                action(title: type.nameZh, selected: selected == type.typeId) {
                    if slot == 0 { $0.firstType = type.typeId } else { $0.secondType = type.typeId }
                }
            }
            return UIMenu(title: title, options: .singleSelection, children: children)
        }

        let types = UIMenu(
            title: "属性",
            image: UIImage(systemName: "square.grid.2x2"),
            children: [
                typeMenu(title: "属性一", selected: value.firstType, slot: 0),
                typeMenu(title: "属性二", selected: value.secondType, slot: 1)
            ]
        )

        let forms = UIMenu(
            title: "形态",
            image: UIImage(systemName: "person.crop.circle.badge.checkmark"),
            options: .singleSelection,
            children: [
                action(title: "全部", selected: value.leader == .all) { $0.leader = .all },
                action(title: "普通", selected: value.leader == .ordinary) { $0.leader = .ordinary },
                action(title: "首领", selected: value.leader == .leader) { $0.leader = .leader }
            ]
        )

        let stages = UIMenu(
            title: "阶段",
            image: UIImage(systemName: "arrow.triangle.branch"),
            options: .singleSelection,
            children: PetCatalogQuery.Stage.allCases.map { stage in
                action(title: stage.rawValue, selected: value.stage == stage) { $0.stage = stage }
            }
        )

        let sorts = UIMenu(
            title: "排序",
            image: UIImage(systemName: "arrow.up.arrow.down"),
            options: .singleSelection,
            children: PetCatalogQuery.Sort.allCases.map { sort in
                action(title: sort.rawValue, selected: value.sort == sort) { $0.sort = sort }
            }
        )

        let directions = UIMenu(
            title: "排序方向",
            image: UIImage(systemName: ascending ? "arrow.up" : "arrow.down"),
            options: .singleSelection,
            children: [
                UIAction(title: "升序", image: UIImage(systemName: "arrow.up"), state: ascending ? .on : .off) { _ in
                    ascendingBinding.wrappedValue = true
                },
                UIAction(title: "降序", image: UIImage(systemName: "arrow.down"), state: ascending ? .off : .on) { _ in
                    ascendingBinding.wrappedValue = false
                }
            ]
        )

        let clear = UIAction(
            title: "清除筛选",
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            attributes: value.hasFilters ? [] : [.disabled]
        ) { _ in
            var next = queryBinding.wrappedValue
            next.clearFilters()
            queryBinding.wrappedValue = next
        }

        return UIMenu(children: [
            types,
            forms,
            stages,
            UIMenu(options: .displayInline, children: [sorts, directions]),
            UIMenu(options: .displayInline, children: [clear])
        ])
    }
}
