import SwiftUI
import UIKit
import RocoContent
import RocoDomain

/// Standard UIKit navigation-bar menu for catalog filtering.
///
/// The navigation controller owns the real UIBarButtonItem and UIKit owns its
/// placement, hit testing, menu presentation, and Liquid Glass appearance.
/// Do not replace this with a customView/overlay/coordinate bridge.
struct CatalogFilterToolbar: UIViewControllerRepresentable {
    let content: ContentStore
    @Binding var query: PetCatalogQuery
    @Binding var ascending: Bool

    func makeUIViewController(context: Context) -> ToolbarHost {
        ToolbarHost(content: content, query: $query, ascending: $ascending)
    }

    func updateUIViewController(_ host: ToolbarHost, context: Context) {
        host.update(content: content, query: $query, ascending: $ascending)
    }

    @MainActor
    final class ToolbarHost: UIViewController {
        private var content: ContentStore
        private var query: Binding<PetCatalogQuery>
        private var ascending: Binding<Bool>

        private weak var itemOwner: UIViewController?
        private var item: UIBarButtonItem?

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
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            installBarItemIfNeeded()
            associateCatalogScrollView()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            installBarItemIfNeeded()
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
            installBarItemIfNeeded()
            rebuildMenu()
        }

        private func installBarItemIfNeeded() {
            guard let owner = navigationItemOwner() else { return }

            if itemOwner !== owner || item == nil {
                let barItem = UIBarButtonItem(
                    title: nil,
                    image: UIImage(systemName: "line.3.horizontal.decrease"),
                    primaryAction: nil,
                    menu: makeMenu()
                )
                barItem.accessibilityLabel = "筛选与排序"
                barItem.accessibilityIdentifier = "catalog-filter-button"

                // Keep the system-provided navigation-bar appearance. On current
                // iOS this is the Liquid Glass treatment; no custom background,
                // customView, or manual positioning is applied.
                owner.navigationItem.rightBarButtonItem = barItem
                itemOwner = owner
                item = barItem
            } else {
                rebuildMenu()
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

        private func rebuildMenu() {
            item?.menu = makeMenu()
            item?.accessibilityValue =
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

        static func dismantle(_ host: ToolbarHost) {
            if host.itemOwner?.navigationItem.rightBarButtonItem === host.item {
                host.itemOwner?.navigationItem.rightBarButtonItem = nil
            }
        }
    }

    static func dismantleUIViewController(_ host: ToolbarHost, coordinator: ()) {
        ToolbarHost.dismantle(host)
    }
}
