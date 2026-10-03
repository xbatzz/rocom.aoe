import UIKit

/// The home stack may pop only while the local encyclopedia stack shows its grid.
/// No navigation bar or portrait geometry changes during a pet transition.
@MainActor
final class CatalogNavigationController: UINavigationController, UIGestureRecognizerDelegate {
    private weak var homeNavigation: UINavigationController?
    private weak var originalEdgeDelegate: (any UIGestureRecognizerDelegate)?
    private var originalEdgeEnabled: Bool?
    private var originalContentEnabled: Bool?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if homeNavigation == nil {
            var ancestor = parent
            while let controller = ancestor {
                if let navigation = controller.navigationController, navigation !== self {
                    homeNavigation = navigation
                    originalEdgeDelegate = navigation.interactivePopGestureRecognizer?.delegate
                    originalEdgeEnabled = navigation.interactivePopGestureRecognizer?.isEnabled
                    originalContentEnabled = navigation.interactiveContentPopGestureRecognizer?.isEnabled
                    break
                }
                ancestor = controller.parent
            }
        }
        setHomeReturnEnabled(viewControllers.count == 1)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        homeNavigation?.interactivePopGestureRecognizer?.delegate = originalEdgeDelegate
        if let originalEdgeEnabled {
            homeNavigation?.interactivePopGestureRecognizer?.isEnabled = originalEdgeEnabled
        }
        if let originalContentEnabled {
            homeNavigation?.interactiveContentPopGestureRecognizer?.isEnabled = originalContentEnabled
        }
    }

    func setHomeReturnEnabled(_ enabled: Bool) {
        // The parent bar is hidden because the local stack owns its bar. Its default
        // gesture delegate rejects that configuration, so allow only the system edge
        // recognizer at the grid. Restore the original delegate when leaving this page.
        homeNavigation?.interactivePopGestureRecognizer?.delegate = self
        homeNavigation?.interactivePopGestureRecognizer?.isEnabled = enabled
        homeNavigation?.interactiveContentPopGestureRecognizer?.isEnabled = false
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === homeNavigation?.interactivePopGestureRecognizer,
            viewControllers.count == 1,
            let homeNavigation, homeNavigation.viewControllers.count > 1,
            homeNavigation.transitionCoordinator == nil else { return false }
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        return pan.velocity(in: pan.view).x > 0
    }
}
