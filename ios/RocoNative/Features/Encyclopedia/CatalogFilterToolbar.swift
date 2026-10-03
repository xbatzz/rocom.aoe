import SwiftUI
import RocoContent

/// Mount only this control in the existing UIKit navigation bar. The system
/// owns its placement during large-title collapse; no scroll observer moves it.
struct CatalogFilterToolbar: UIViewControllerRepresentable {
    let content: ContentStore
    @Binding var query: PetCatalogQuery
    @Binding var ascending: Bool

    func makeUIViewController(context: Context) -> ToolbarHost {
        ToolbarHost(button: CatalogFilterButton(content: content, query: $query, ascending: $ascending))
    }

    func updateUIViewController(_ host: ToolbarHost, context: Context) {
        host.button.rootView = CatalogFilterButton(content: content, query: $query, ascending: $ascending)
    }

    final class ToolbarHost: UIViewController {
        let button: UIHostingController<CatalogFilterButton>
        private weak var itemOwner: UIViewController?
        private var item: UIBarButtonItem?

        init(button: CatalogFilterButton) {
            self.button = UIHostingController(rootView: button)
            self.button.safeAreaRegions = []
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            button.view.backgroundColor = .clear
            button.view.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            var owner = parent
            while let candidate = owner {
                if let navigation = candidate.navigationController {
                    if button.parent !== navigation {
                        button.willMove(toParent: nil)
                        button.removeFromParent()
                        navigation.addChild(button)
                    }
                    let item = UIBarButtonItem(customView: button.view)
                    // The SwiftUI view already supplies its own interactive glass.
                    item.hidesSharedBackground = true
                    candidate.navigationItem.rightBarButtonItem = item
                    button.didMove(toParent: navigation)
                    self.item = item
                    itemOwner = candidate
                    break
                }
                owner = candidate.parent
            }
        }

        static func dismantle(_ host: ToolbarHost) {
            if host.itemOwner?.navigationItem.rightBarButtonItem === host.item {
                host.itemOwner?.navigationItem.rightBarButtonItem = nil
            }
            host.button.willMove(toParent: nil)
            host.button.view.removeFromSuperview()
            host.button.removeFromParent()
        }
    }

    static func dismantleUIViewController(_ host: ToolbarHost, coordinator: ()) {
        ToolbarHost.dismantle(host)
    }
}
