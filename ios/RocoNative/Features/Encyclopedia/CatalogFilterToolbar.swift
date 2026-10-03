import SwiftUI
import RocoContent

/// The bar reserves a 44pt anchor; one glass surface lives above the bar and grid
/// so it can grow down and left without navigation-bar clipping or a popover.
struct CatalogFilterToolbar: UIViewControllerRepresentable {
    let content: ContentStore
    @Binding var query: PetCatalogQuery
    @Binding var ascending: Bool

    func makeUIViewController(context: Context) -> ToolbarHost {
        ToolbarHost(button: CatalogFilterButton(content: content, query: $query, ascending: $ascending))
    }

    func updateUIViewController(_ host: ToolbarHost, context: Context) {
        host.updateButton(CatalogFilterButton(content: content, query: $query, ascending: $ascending))
    }

    final class ToolbarHost: UIViewController {
        private let anchor = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        private let overlay = TouchSurface()
        private let button: UIView & UIContentView
        private var definition: CatalogFilterButton
        private weak var itemOwner: UIViewController?
        private var item: UIBarButtonItem?
        private var lastAnchor: CGRect?

        init(button: CatalogFilterButton) {
            definition = button
            self.button = UIHostingConfiguration { button }.margins(.all, 0).makeContentView()
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            anchor.isUserInteractionEnabled = false
            overlay.backgroundColor = .clear
            button.backgroundColor = .clear
            button.translatesAutoresizingMaskIntoConstraints = false
            overlay.addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: overlay.topAnchor),
                button.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
                button.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),
                button.leadingAnchor.constraint(equalTo: overlay.leadingAnchor)
            ])
            overlay.onLayout = { [weak self] in self?.refreshAnchor() }
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            var owner = parent
            while let candidate = owner {
                if let navigation = candidate.navigationController {
                    let item = UIBarButtonItem(customView: anchor)
                    item.hidesSharedBackground = true
                    candidate.navigationItem.rightBarButtonItem = item
                    self.item = item
                    itemOwner = candidate
                    if overlay.superview !== navigation.view {
                        overlay.removeFromSuperview()
                        overlay.translatesAutoresizingMaskIntoConstraints = false
                        navigation.view.addSubview(overlay)
                        NSLayoutConstraint.activate([
                            overlay.topAnchor.constraint(equalTo: navigation.view.topAnchor),
                            overlay.trailingAnchor.constraint(equalTo: navigation.view.trailingAnchor),
                            overlay.bottomAnchor.constraint(equalTo: navigation.view.bottomAnchor),
                            overlay.leadingAnchor.constraint(equalTo: navigation.view.leadingAnchor)
                        ])
                    }
                    overlay.isHidden = false
                    navigation.view.bringSubviewToFront(overlay)
                    refreshAnchor()
                    associateCatalogScrollView()
                    break
                }
                owner = candidate.parent
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            overlay.isHidden = true
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            refreshAnchor()
            associateCatalogScrollView()
        }

        func updateButton(_ definition: CatalogFilterButton) {
            self.definition = definition
            refreshConfiguration()
        }

        private func refreshAnchor() {
            guard anchor.window != nil, overlay.bounds.width > 0 else { return }
            let rect = anchor.convert(anchor.bounds, to: overlay)
            guard lastAnchor != rect else { return }
            lastAnchor = rect
            overlay.anchorFrame = rect
            refreshConfiguration()
        }

        private func refreshConfiguration() {
            var control = definition
            let rect = lastAnchor ?? CGRect(x: overlay.bounds.width - 60, y: 0, width: 44, height: 44)
            control.topInset = max(0, rect.minY)
            control.trailingInset = max(0, overlay.bounds.width - rect.maxX)
            control.onPresentationChange = { [weak self] expanded in self?.overlay.expanded = expanded }
            button.configuration = UIHostingConfiguration { control }.margins(.all, 0)
        }

        private func associateCatalogScrollView() {
            guard let owner = itemOwner,
                let rootView = owner.viewIfLoaded,
                let scrollView = Self.contentScrollView(in: rootView),
                owner.contentScrollView(for: .top) !== scrollView else { return }
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
            host.overlay.removeFromSuperview()
        }

        /// When collapsed, every point outside the icon passes through to the app.
        private final class TouchSurface: UIView {
            var anchorFrame = CGRect.zero
            var expanded = false
            var onLayout: (() -> Void)?

            override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
                expanded ? super.point(inside: point, with: event) : anchorFrame.contains(point)
            }

            override func layoutSubviews() {
                super.layoutSubviews()
                onLayout?()
            }
        }
    }

    static func dismantleUIViewController(_ host: ToolbarHost, coordinator: ()) {
        ToolbarHost.dismantle(host)
    }
}
