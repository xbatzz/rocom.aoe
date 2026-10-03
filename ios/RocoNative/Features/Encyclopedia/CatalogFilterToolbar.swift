import SwiftUI
import UIKit
import RocoContent
import RocoDomain

/// System-owned catalog chrome.
///
/// UIKit owns both pieces of chrome:
/// - a real navigation-bar `UIBarButtonItem + UIMenu` for filtering
/// - a real `UISearchController` using iOS integrated toolbar search
///
/// Do not replace either control with custom glass, customView anchors, overlay
/// geometry, or hand-written hit testing. UIKit supplies placement, Liquid Glass,
/// keyboard motion, menu morphing, and accessibility behavior.
struct CatalogFilterToolbar: UIViewControllerRepresentable {
    let content: ContentStore
    @Binding var query: PetCatalogQuery
    @Binding var ascending: Bool

    func makeUIViewController(context: Context) -> ToolbarHost {
        ToolbarHost(
            content: content,
            query: $query,
            ascending: $ascending
        )
    }

    func updateUIViewController(_ host: ToolbarHost, context: Context) {
        host.update(
            content: content,
            query: $query,
            ascending: $ascending
        )
    }

    @MainActor
    final class ToolbarHost: UIViewController, UISearchResultsUpdating, UISearchBarDelegate {
        private var content: ContentStore
        private var query: Binding<PetCatalogQuery>
        private var ascending: Binding<Bool>

        private weak var itemOwner: UIViewController?
        private weak var navigation: UINavigationController?
        private var filterItem: UIBarButtonItem?
        private let searchController = UISearchController(searchResultsController: nil)
        private var synchronizingSearchText = false

        init(
            content: ContentStore,
            query: Binding<PetCatalogQuery>,
            ascending: Binding<Bool>
        ) {
            self.content = content
            self.query = query
            self.ascending = ascending
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear

            searchController.searchResultsUpdater = self
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.searchBar.delegate = self
            searchController.searchBar.placeholder = "名称、编号或配置 ID"
            searchController.searchBar.autocapitalizationType = .none
            searchController.searchBar.autocorrectionType = .no
            searchController.searchBar.returnKeyType = .search
            searchController.searchBar.accessibilityLabel = "搜索精灵"
            searchController.searchBar.accessibilityIdentifier = "catalog-search-field"
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            installChromeIfNeeded()
            navigation?.setToolbarHidden(false, animated: animated)
            associateCatalogScrollView()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            installChromeIfNeeded()
            associateCatalogScrollView()
        }

        func update(
            content: ContentStore,
            query: Binding<PetCatalogQuery>,
            ascending: Binding<Bool>
        ) {
            self.content = content
            self.query = query
            self.ascending = ascending
            installChromeIfNeeded()
            rebuildMenu()
            syncSearchText()
        }

        private func installChromeIfNeeded() {
            guard let owner = navigationItemOwner() else { return }

            if itemOwner !== owner {
                detach(from: itemOwner)

                itemOwner = owner
                navigation = owner.navigationController
                owner.definesPresentationContext = true

                let item = UIBarButtonItem(
                    title: nil,
                    image: UIImage(systemName: "line.3.horizontal.decrease"),
                    primaryAction: nil,
                    menu: makeMenu()
                )
                item.accessibilityLabel = "筛选与排序"
                item.accessibilityIdentifier = "catalog-filter-button"
                owner.navigationItem.rightBarButtonItem = item
                filterItem = item

                owner.navigationItem.searchController = searchController
                owner.navigationItem.preferredSearchBarPlacement = .integrated
                owner.navigationItem.searchBarPlacementAllowsToolbarIntegration = true
                // The navigation controller hides both bars on swipe. Keep search
                // itself expanded whenever the bars are visible.
                owner.navigationItem.hidesSearchBarWhenScrolling = false

                let searchItem = owner.navigationItem.searchBarPlacementBarButtonItem
                searchItem.accessibilityLabel = "搜索精灵"
                searchItem.accessibilityIdentifier = "catalog-search-button"

                // Keep search leading, matching the catalog's established thumb-reach
                // layout. The system still owns the search button -> field morph.
                owner.toolbarItems = [
                    searchItem,
                    UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                ]

                syncSearchText()
            } else {
                rebuildMenu()
                syncSearchText()
            }
        }

        private func navigationItemOwner() -> UIViewController? {
            var candidate = parent
            while let current = candidate {
                if current.navigationController != nil {
                    return current
                }
                candidate = current.parent
            }
            return nil
        }

        private func syncSearchText() {
            let text = query.wrappedValue.keyword
            guard searchController.searchBar.text != text else { return }

            synchronizingSearchText = true
            searchController.searchBar.text = text
            synchronizingSearchText = false
        }

        func updateSearchResults(for searchController: UISearchController) {
            guard !synchronizingSearchText else { return }
            setKeyword(searchController.searchBar.text ?? "")
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            setKeyword("")
        }

        private func setKeyword(_ keyword: String) {
            guard query.wrappedValue.keyword != keyword else { return }
            var value = query.wrappedValue
            value.keyword = keyword
            query.wrappedValue = value
        }

        private func rebuildMenu() {
            filterItem?.menu = makeMenu()
            filterItem?.accessibilityValue =
                "\(query.wrappedValue.filterCount) 项筛选，按\(query.wrappedValue.sort.rawValue)排序，\(ascending.wrappedValue ? "升序" : "降序")"
        }

        private func makeMenu() -> UIMenu {
            let value = query.wrappedValue

            let typeMenu = UIMenu(
                title: "属性",
                image: UIImage(systemName: "square.grid.2x2"),
                children: [
                    makeTypeSlotMenu(title: "属性一", selected: value.firstType, slot: 0),
                    makeTypeSlotMenu(title: "属性二", selected: value.secondType, slot: 1)
                ]
            )

            let formMenu = UIMenu(
                title: "形态",
                image: UIImage(systemName: "person.crop.circle.badge.checkmark"),
                options: .singleSelection,
                children: [
                    action(title: "全部", selected: value.leader == .all) { host in
                        host.mutateQuery { $0.leader = .all }
                    },
                    action(title: "普通", selected: value.leader == .ordinary) { host in
                        host.mutateQuery { $0.leader = .ordinary }
                    },
                    action(title: "首领", selected: value.leader == .leader) { host in
                        host.mutateQuery { $0.leader = .leader }
                    }
                ]
            )

            let stageMenu = UIMenu(
                title: "阶段",
                image: UIImage(systemName: "arrow.triangle.branch"),
                options: .singleSelection,
                children: PetCatalogQuery.Stage.allCases.map { stage in
                    action(title: stage.rawValue, selected: value.stage == stage) { host in
                        host.mutateQuery { $0.stage = stage }
                    }
                }
            )

            let sortMenu = UIMenu(
                title: "排序",
                image: UIImage(systemName: "arrow.up.arrow.down"),
                options: .singleSelection,
                children: PetCatalogQuery.Sort.allCases.map { sort in
                    action(title: sort.rawValue, selected: value.sort == sort) { host in
                        host.mutateQuery { $0.sort = sort }
                    }
                }
            )

            let directionMenu = UIMenu(
                title: "排序方向",
                image: UIImage(systemName: ascending.wrappedValue ? "arrow.up" : "arrow.down"),
                options: .singleSelection,
                children: [
                    action(title: "升序", image: "arrow.up", selected: ascending.wrappedValue) { host in
                        host.ascending.wrappedValue = true
                        host.rebuildMenu()
                    },
                    action(title: "降序", image: "arrow.down", selected: !ascending.wrappedValue) { host in
                        host.ascending.wrappedValue = false
                        host.rebuildMenu()
                    }
                ]
            )

            let clear = UIAction(
                title: "清除筛选",
                image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
                attributes: value.hasFilters ? [] : [.disabled]
            ) { [weak self] _ in
                self?.mutateQuery { $0.clearFilters() }
            }

            return UIMenu(
                title: "",
                children: [
                    typeMenu,
                    formMenu,
                    stageMenu,
                    UIMenu(options: .displayInline, children: [sortMenu, directionMenu]),
                    UIMenu(options: .displayInline, children: [clear])
                ]
            )
        }

        private func makeTypeSlotMenu(
            title: String,
            selected: TypeID?,
            slot: Int
        ) -> UIMenu {
            var children: [UIMenuElement] = [
                action(title: "全部", selected: selected == nil) { host in
                    host.mutateQuery {
                        if slot == 0 { $0.firstType = nil } else { $0.secondType = nil }
                    }
                }
            ]

            children += content.catalogTypes.map { type in
                action(
                    title: type.nameZh,
                    selected: selected == type.typeId
                ) { host in
                    host.mutateQuery {
                        if slot == 0 { $0.firstType = type.typeId } else { $0.secondType = type.typeId }
                    }
                }
            }

            return UIMenu(title: title, options: .singleSelection, children: children)
        }

        private func action(
            title: String,
            image systemImage: String? = nil,
            selected: Bool,
            handler: @escaping (ToolbarHost) -> Void
        ) -> UIAction {
            UIAction(
                title: title,
                image: systemImage.flatMap { UIImage(systemName: $0) },
                state: selected ? .on : .off
            ) { [weak self] _ in
                guard let self else { return }
                handler(self)
            }
        }

        private func mutateQuery(_ change: (inout PetCatalogQuery) -> Void) {
            var value = query.wrappedValue
            change(&value)
            query.wrappedValue = value
            rebuildMenu()
            syncSearchText()
        }

        private func associateCatalogScrollView() {
            guard let owner = itemOwner,
                  let rootView = owner.viewIfLoaded,
                  let scrollView = Self.contentScrollView(in: rootView),
                  owner.contentScrollView(for: .top) !== scrollView else {
                return
            }
            owner.setContentScrollView(scrollView, for: .top)
        }

        private static func contentScrollView(in view: UIView) -> UIScrollView? {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            for child in view.subviews {
                if let scrollView = contentScrollView(in: child) {
                    return scrollView
                }
            }
            return nil
        }

        private func detach(from owner: UIViewController?) {
            guard let owner else { return }

            if owner.navigationItem.rightBarButtonItem === filterItem {
                owner.navigationItem.rightBarButtonItem = nil
            }
            if owner.navigationItem.searchController === searchController {
                owner.navigationItem.searchController = nil
            }
            owner.toolbarItems = nil
        }

        static func dismantle(_ host: ToolbarHost) {
            host.searchController.isActive = false
            host.navigation?.setToolbarHidden(true, animated: false)
            host.detach(from: host.itemOwner)
        }
    }

    static func dismantleUIViewController(_ host: ToolbarHost, coordinator: ()) {
        ToolbarHost.dismantle(host)
    }
}
