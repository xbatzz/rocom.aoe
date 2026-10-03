import SwiftUI
import RocoContent

/// Host a control view, never a destination controller, in the navigation bar.
/// UINavigationController must keep the grid as its sole root destination.
struct CatalogFilterToolbar: UIViewControllerRepresentable {
    let content: ContentStore
    @Binding var query: PetCatalogQuery
    @Binding var ascending: Bool

    func makeUIViewController(context: Context) -> ToolbarHost {
        ToolbarHost(button: CatalogFilterButton(content: content, query: $query, ascending: $ascending))
    }

    func updateUIViewController(_ host: ToolbarHost, context: Context) {
        host.button.configuration = ToolbarHost.configuration(
            CatalogFilterButton(content: content, query: $query, ascending: $ascending))
    }

    final class ToolbarHost: UIViewController {
        let button: UIView & UIContentView
        private weak var itemOwner: UIViewController?
        private var item: UIBarButtonItem?

        static func configuration(_ button: CatalogFilterButton) -> some UIContentConfiguration {
            UIHostingConfiguration { button }
                .margins(.all, 0)
                .minSize(width: 44, height: 44)
        }

        init(button: CatalogFilterButton) {
            self.button = Self.configuration(button).makeContentView()
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            button.backgroundColor = .clear
            button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            var owner = parent
            while let candidate = owner {
                if candidate.navigationController != nil {
                    let item = UIBarButtonItem(customView: button)
                    item.hidesSharedBackground = true
                    candidate.navigationItem.rightBarButtonItem = item
                    self.item = item
                    itemOwner = candidate
                    associateCatalogScrollView()
                    break
                }
                owner = candidate.parent
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            associateCatalogScrollView()
        }

        private func associateCatalogScrollView() {
            guard let owner = itemOwner,
                let rootView = owner.viewIfLoaded,
                let scrollView = Self.contentScrollView(in: rootView),
                owner.contentScrollView(for: .top) !== scrollView else { return }
            // Native bar tracking only. Never set offsets, insets or scroll delegates.
            owner.setContentScrollView(scrollView, for: .top)
        }

        private static func contentScrollView(in view: UIView) -> UIScrollView? {
            if let scrollView = view as? UIScrollView { return scrollView }
            for child in view.subviews {
                if let scrollView = contentScrollView(in: child) { return scrollView }
            }
            return nil
        }

        static func dismantle(_ host: ToolbarHost) {
            if host.itemOwner?.navigationItem.rightBarButtonItem === host.item {
                host.itemOwner?.navigationItem.rightBarButtonItem = nil
            }
            host.button.removeFromSuperview()
        }
    }

    static func dismantleUIViewController(_ host: ToolbarHost, coordinator: ()) {
        ToolbarHost.dismantle(host)
    }
}
