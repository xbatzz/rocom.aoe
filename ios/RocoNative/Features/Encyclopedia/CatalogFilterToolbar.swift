import SwiftUI
import RocoContent

/// The navigation bar owns only a real 44pt anchor. The interactive glass surface
/// is hosted above the navigation view so it can expand down and left without
/// being clipped by UINavigationBar.
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
        private let anchor = BarAnchorView()
        private let overlay = TouchSurface()
        private let button: UIView & UIContentView
        private var definition: CatalogFilterButton
        private weak var itemOwner: UIViewController?
        private weak var navigation: UINavigationController?
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

            anchor.backgroundColor = .clear
            anchor.isUserInteractionEnabled = false
            anchor.onLayout = { [weak self] in
                DispatchQueue.main.async { self?.refreshAnchor() }
            }

            overlay.backgroundColor = .clear
            button.backgroundColor = .clear
            button.isHidden = false
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
                    self.navigation = navigation

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

                    // UIBarButtonItem lays out its custom view after assignment. Do not
                    // guess a fallback position before that layout has happened.
                    navigation.navigationBar.setNeedsLayout()
                    navigation.navigationBar.layoutIfNeeded()
                    refreshAnchor()
                    DispatchQueue.main.async { [weak self, weak navigation] in
                        navigation?.navigationBar.layoutIfNeeded()
                        self?.refreshAnchor()
                    }

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
            guard overlay.bounds.width > 0,
                  anchor.bounds.width > 1,
                  anchor.bounds.height > 1,
                  anchor.superview != nil,
                  overlay.superview != nil else {
                refreshConfiguration()
                return
            }

            let rect = anchor.convert(anchor.bounds, to: overlay)
            guard rect.width > 1, rect.height > 1 else {
                refreshConfiguration()
                return
            }

            let normalized = CGRect(
                x: rect.midX - 22,
                y: rect.midY - 22,
                width: 44,
                height: 44
            )

            if lastAnchor != normalized {
                lastAnchor = normalized
                overlay.anchorFrame = normalized
            }
            refreshConfiguration()
        }

        private func fallbackAnchor() -> CGRect {
            guard let navigation, overlay.bounds.width > 0 else {
                return CGRect(x: max(0, overlay.bounds.width - 60), y: 0, width: 44, height: 44)
            }
            let barFrame = navigation.navigationBar.convert(navigation.navigationBar.bounds, to: overlay)
            return CGRect(
                x: max(0, overlay.bounds.width - navigation.view.safeAreaInsets.right - 60),
                y: max(0, barFrame.minY),
                width: 44,
                height: 44
            )
        }

        private func refreshConfiguration() {
            let rect = lastAnchor ?? fallbackAnchor()
            overlay.anchorFrame = rect

            var control = definition
            control.topInset = max(0, rect.minY)
            control.trailingInset = max(0, overlay.bounds.width - rect.maxX)
            control.onPresentationChange = { [weak self] expanded in
                self?.overlay.expanded = expanded
            }
            button.configuration = UIHostingConfiguration { control }.margins(.all, 0)
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

        /// A plain UIView has no intrinsic size. UINavigationBar is free to collapse
        /// such a custom view, which previously produced a zero/stale anchor and made
        /// the overlay icon appear in the wrong place and reject taps.
        private final class BarAnchorView: UIView {
            var onLayout: (() -> Void)?

            override init(frame: CGRect) {
                super.init(frame: frame)
            }

            convenience init() {
                self.init(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            }

            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            override var intrinsicContentSize: CGSize {
                CGSize(width: 44, height: 44)
            }

            override func layoutSubviews() {
                super.layoutSubviews()
                onLayout?()
            }
        }

        /// When collapsed, every point outside the actual bar-button target passes
        /// through to the catalog. When expanded, the surface owns the screen so taps
        /// outside the panel can dismiss it.
        private final class TouchSurface: UIView {
            var anchorFrame = CGRect.zero
            var expanded = false
            var onLayout: (() -> Void)?

            override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
                if expanded {
                    return super.point(inside: point, with: event)
                }
                return anchorFrame.insetBy(dx: -4, dy: -4).contains(point)
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
