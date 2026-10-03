import SwiftUI
import UIKit

/// Keeps system bars mounted; scrolling changes only their system items.
struct CompanionScrollChrome: UIViewControllerRepresentable {
    @Binding var query: String
    let visible: Bool
    let prompt: String
    let searchLabel: String
    let identifier: String
    let returnToParent: () -> Void
    let makeMenu: () -> UIMenu
    let filterValue: String
    var chromeEnabled = true
    var keepLeadingWhenDisabled = false

    func makeUIViewController(context: Context) -> Host {
        Host(configuration: self)
    }

    func updateUIViewController(_ host: Host, context: Context) {
        if host.configuration.chromeEnabled != chromeEnabled {
            host.trackedScrollView = nil
        }
        host.configuration = self
        host.refresh()
    }

    static func dismantleUIViewController(_ host: Host, coordinator: ()) {
        host.detach()
    }

    @MainActor
    final class Host: UIViewController, UISearchResultsUpdating, UISearchBarDelegate, UISearchControllerDelegate, UIGestureRecognizerDelegate {
        var configuration: CompanionScrollChrome
        private weak var owner: UIViewController?
        private let search = UISearchController(searchResultsController: nil)
        private let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        private var leading: UIBarButtonItem?
        private var trailing: UIBarButtonItem?
        private var searchItem: UIBarButtonItem?
        private var originalLeading: UIBarButtonItem?
        private var originalTrailing: UIBarButtonItem?
        private var originalToolbar: [UIBarButtonItem]?
        private var originalHidesBack = false
        private var synchronizing = false
        private var isLeavingPage = false
        private var isRefreshing = false
        fileprivate weak var trackedScrollView: UIScrollView?
        private weak var returnNavigation: UINavigationController?
        private weak var originalEdgeDelegate: (any UIGestureRecognizerDelegate)?
        private var originalEdgeEnabled: Bool?


        init(configuration: CompanionScrollChrome) {
            self.configuration = configuration
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            search.searchResultsUpdater = self
            search.searchBar.delegate = self
            search.delegate = self
            search.obscuresBackgroundDuringPresentation = false
            search.searchBar.autocapitalizationType = .none
            search.searchBar.autocorrectionType = .no
            search.searchBar.returnKeyType = .search
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            isLeavingPage = false
            refresh(allowTransitionSetup: true)
            mountBars(animated: owner?.navigationController?.transitionCoordinator?.isAnimated ?? animated)
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Also runs after a cancelled interactive pop.
            isLeavingPage = false
            refresh()
            mountBars(animated: false)
            if configuration.chromeEnabled {
                installEdgeReturn()
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            refresh()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            isLeavingPage = true
            // Child appearance callbacks may receive animated=false even while
            // their hosting controller is in an interactive navigation transition.
            // Let UIKit coordinate toolbar motion with that transition.
            if let navigation = owner?.navigationController {
                let transition = navigation.transitionCoordinator
                navigation.setToolbarHidden(true, animated: transition?.isAnimated ?? animated)
            }
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            // Never disable or replace the recognizer during its active gesture.
            restoreEdgeReturn()
        }

        private func mountBars(animated: Bool) {
            guard let owner, let navigation = owner.navigationController,
                  navigation.topViewController === owner else { return }
            navigation.hidesBarsOnSwipe = false
            if navigation.isNavigationBarHidden {
                navigation.setNavigationBarHidden(false, animated: animated)
            }
            if navigation.isToolbarHidden {
                navigation.setToolbarHidden(false, animated: animated)
            }
        }

        func refresh(allowTransitionSetup: Bool = false) {
            guard !isLeavingPage, !isRefreshing else { return }
            isRefreshing = true
            defer { isRefreshing = false }
            var candidate = parent
            while let current = candidate, current.navigationController == nil { candidate = current.parent }
            guard let candidate else { return }
            if owner !== candidate {
                detach()
                owner = candidate
                originalLeading = candidate.navigationItem.leftBarButtonItem
                originalTrailing = candidate.navigationItem.rightBarButtonItem
                originalToolbar = candidate.toolbarItems
                originalHidesBack = candidate.navigationItem.hidesBackButton
                leading = originalLeading
                if leading == nil, (candidate.navigationController?.viewControllers.count ?? 0) > 1 {
                    leading = UIBarButtonItem(title: nil, image: UIImage(systemName: "chevron.backward"), primaryAction: UIAction { [weak self] _ in
                        self?.configuration.returnToParent()
                    }, menu: nil)
                    leading?.accessibilityLabel = "返回"
                    leading?.accessibilityIdentifier = "\(configuration.identifier)-back"
                }
                candidate.navigationItem.hidesBackButton = true
                trailing = UIBarButtonItem(title: nil, image: UIImage(systemName: "line.3.horizontal.decrease"), primaryAction: nil, menu: UIMenu(children: [
                    // Build the latest filter actions only when the menu opens.
                    // Keyboard layout must not repeatedly replace a UIKit menu.
                    UIDeferredMenuElement.uncached { [weak self] completion in
                        completion(self?.configuration.makeMenu().children ?? [])
                    }
                ]))
                trailing?.accessibilityLabel = "筛选"
                trailing?.accessibilityIdentifier = "\(configuration.identifier)-filter-button"
                candidate.navigationItem.setLeftBarButton(leading, animated: false)
                candidate.navigationItem.setRightBarButton(trailing, animated: false)
                candidate.definesPresentationContext = true
                candidate.navigationItem.searchController = search
                candidate.navigationItem.preferredSearchBarPlacement = .integrated
                candidate.navigationItem.searchBarPlacementAllowsToolbarIntegration = true
                candidate.navigationItem.hidesSearchBarWhenScrolling = false
                searchItem = candidate.navigationItem.searchBarPlacementBarButtonItem
                if let searchItem { candidate.toolbarItems = [searchItem, spacer] }
            }
            // An offscreen page must not overwrite the detail page's bar state.
            guard candidate.navigationController?.topViewController === candidate,
                  allowTransitionSetup || candidate.navigationController?.transitionCoordinator == nil else { return }
            if search.searchBar.placeholder != configuration.prompt {
                search.searchBar.placeholder = configuration.prompt
            }
            search.searchBar.accessibilityLabel = configuration.searchLabel
            search.searchBar.accessibilityIdentifier = "\(configuration.identifier)-search-field"
            searchItem?.accessibilityLabel = configuration.searchLabel
            searchItem?.accessibilityIdentifier = "\(configuration.identifier)-search-button"
            if trailing?.accessibilityValue != configuration.filterValue {
                trailing?.accessibilityValue = configuration.filterValue
            }
            if !configuration.chromeEnabled && search.isActive {
                search.isActive = false
            }
            if search.searchBar.text != configuration.query {
                synchronizing = true
                search.searchBar.text = configuration.query
                synchronizing = false
            }
            if configuration.chromeEnabled {
                if view.window != nil { installEdgeReturn() }
            } else {
                restoreEdgeReturn()
            }
            if trackedScrollView == nil || trackedScrollView?.window !== view.window {
                trackedScrollView = Self.contentScrollView(in: candidate.view)
            }
            if let scroll = trackedScrollView, candidate.contentScrollView(for: .top) !== scroll {
                candidate.setContentScrollView(scroll, for: .top)
            }
            applyVisibility(allowTransitionSetup: allowTransitionSetup)
        }

        private func applyVisibility(allowTransitionSetup: Bool = false) {
            guard !isLeavingPage, let owner,
                  let navigation = owner.navigationController,
                  navigation.topViewController === owner,
                  allowTransitionSetup || navigation.transitionCoordinator == nil,
                  let searchItem else { return }

            let showChrome = configuration.chromeEnabled &&
                (configuration.visible || search.isActive || !configuration.query.isEmpty)
            let showLeading = configuration.chromeEnabled
                ? showChrome
                : configuration.keepLeadingWhenDisabled
            let animated = !UIAccessibility.isReduceMotionEnabled

            if owner.navigationItem.leftBarButtonItem !== (showLeading ? leading : nil) {
                owner.navigationItem.setLeftBarButton(showLeading ? leading : nil, animated: animated)
            }
            if owner.navigationItem.rightBarButtonItem !== (showChrome ? trailing : nil) {
                owner.navigationItem.setRightBarButton(showChrome ? trailing : nil, animated: animated)
            }
            if (owner.toolbarItems?.contains(where: { $0 === searchItem }) == true) != showChrome {
                owner.setToolbarItems(showChrome ? [searchItem, spacer] : [spacer], animated: animated)
            }

            navigation.toolbar.alpha = configuration.chromeEnabled ? 1 : 0
            navigation.toolbar.isUserInteractionEnabled = configuration.chromeEnabled
            search.searchBar.isUserInteractionEnabled = showChrome
            search.searchBar.accessibilityElementsHidden = !showChrome
        }

        func updateSearchResults(for searchController: UISearchController) {
            guard !synchronizing else { return }
            let text = searchController.searchBar.text ?? ""
            if configuration.query != text { configuration.query = text }
            applyVisibility()
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) { configuration.query = "" }
        func didPresentSearchController(_ searchController: UISearchController) { applyVisibility() }
        func didDismissSearchController(_ searchController: UISearchController) { applyVisibility() }

        private func installEdgeReturn() {
            guard returnNavigation == nil, let owner,
                  let navigation = owner.navigationController,
                  navigation.topViewController === owner,
                  navigation.viewControllers.count > 1,
                  let edge = navigation.interactivePopGestureRecognizer else { return }
            // SwiftUI hides its built-in back button because this page owns a
            // scroll-aware system item. UIKit's default delegate rejects that
            // configuration, so temporarily allow its existing edge recognizer.
            returnNavigation = navigation
            originalEdgeDelegate = edge.delegate
            originalEdgeEnabled = edge.isEnabled
            edge.delegate = self
            edge.isEnabled = true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard configuration.chromeEnabled,
                  let navigation = returnNavigation,
                  gestureRecognizer === navigation.interactivePopGestureRecognizer,
                  navigation.topViewController === owner,
                  navigation.viewControllers.count > 1,
                  navigation.transitionCoordinator == nil else { return false }
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            return pan.velocity(in: pan.view).x > 0
        }

        private func restoreEdgeReturn() {
            guard let navigation = returnNavigation else { return }
            if navigation.interactivePopGestureRecognizer?.delegate === self {
                navigation.interactivePopGestureRecognizer?.delegate = originalEdgeDelegate
                if let originalEdgeEnabled {
                    navigation.interactivePopGestureRecognizer?.isEnabled = originalEdgeEnabled
                }
            }
            returnNavigation = nil
            originalEdgeDelegate = nil
            originalEdgeEnabled = nil
        }

        private static func contentScrollView(in view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            for child in view.subviews {
                if let scroll = contentScrollView(in: child) { return scroll }
            }
            return nil
        }

        func detach() {
            trackedScrollView = nil
            restoreEdgeReturn()
            guard let owner else { return }
            search.isActive = false
            owner.navigationItem.setLeftBarButton(originalLeading, animated: false)
            owner.navigationItem.setRightBarButton(originalTrailing, animated: false)
            owner.navigationItem.hidesBackButton = originalHidesBack
            if owner.navigationItem.searchController === search { owner.navigationItem.searchController = nil }
            owner.toolbarItems = originalToolbar
            owner.navigationController?.toolbar.alpha = 1
            owner.navigationController?.toolbar.isUserInteractionEnabled = true
            self.owner = nil
        }
    }
}
