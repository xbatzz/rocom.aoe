import SwiftUI
import RocoDomain
import RocoContent
import os

/// UIKit owns navigation; SwiftUI owns content.
///
/// This bridge intentionally does NOT use UIViewController.Transition.zoom.
/// System zoom scales/composes the whole destination controller, which is the
/// behavior that made the encyclopedia page and navigation bar visually shrink
/// and rebound during interactive pop. Instead, navigation remains ordinary
/// UIKit and only the registered portrait image participates in the custom
/// shared-element animation.
struct AlignedNavigation: UIViewControllerRepresentable {
    let content: ContentStore
    let portraits: PortraitStore
    var returnToHome: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content, portraits: portraits, returnToHome: returnToHome)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        context.coordinator.makeNavigation(pets: content.orderedPets)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        context.coordinator.returnToHome = returnToHome
    }

    @MainActor
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
        let anchors = PortraitAnchors()
        let content: ContentStore
        let portraits: PortraitStore
        var returnToHome: (() -> Void)?

        weak var navigation: UINavigationController?
        private weak var edgePan: UIScreenEdgePanGestureRecognizer?

        private var activeOrigin: PortraitOrigin?
        private var activeImage: UIImage?

        private var interactiveDriver: UIPercentDrivenInteractiveTransition?
        private var inputLease: InputLease?

#if DEBUG
        private let logger = Logger(subsystem: "com.batzz.rocom", category: "navigation")
#endif

        /// Prevents the live Grid/source cell from moving while a pop transition
        /// (including the post-release settling animation) is still using it.
        private final class InputLease {
            let gridView: UIView
            let scrollView: UIScrollView?
            let interactionWasEnabled: Bool
            let scrollingWasEnabled: Bool?

            init(gridView: UIView, scrollView: UIScrollView?) {
                self.gridView = gridView
                self.scrollView = scrollView
                interactionWasEnabled = gridView.isUserInteractionEnabled
                scrollingWasEnabled = scrollView?.isScrollEnabled

                scrollView?.isScrollEnabled = false
                gridView.isUserInteractionEnabled = false
            }

            func restore() {
                if let scrollingWasEnabled {
                    scrollView?.isScrollEnabled = scrollingWasEnabled
                }
                gridView.isUserInteractionEnabled = interactionWasEnabled
            }
        }

        init(content: ContentStore, portraits: PortraitStore, returnToHome: (() -> Void)? = nil) {
            self.content = content
            self.portraits = portraits
            self.returnToHome = returnToHome
            super.init()
        }

        func makeNavigation(pets: [Pet]) -> UINavigationController {
            let root = NavigationContentHost(
                rootView: AlignedPetGrid(
                    pets: pets,
                    content: content,
                    portraits: portraits,
                    anchors: anchors,
                    open: open
                )
            )
            root.title = "图鉴"
            root.navigationItem.largeTitleDisplayMode = .always

            if returnToHome != nil {
                let back = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain,
                    target: self, action: #selector(returnToFeatureHome))
                back.accessibilityLabel = "返回"
                back.accessibilityIdentifier = "catalog-back"
                root.navigationItem.leftBarButtonItem = back
            }
            let nav = returnToHome == nil ? UINavigationController(rootViewController: root)
                : CatalogNavigationController(rootViewController: root)
            nav.navigationBar.prefersLargeTitles = true
            nav.hidesBarsOnSwipe = true
            nav.delegate = self
            navigation = nav

            // The system fluid/content pop is tied to the system zoom presentation.
            // For image-only shared-element motion we drive one ordinary edge-pan
            // interaction ourselves and let UIPercentDrivenInteractiveTransition
            // scrub the same custom animator used by the back button.
            nav.interactivePopGestureRecognizer?.isEnabled = false
            nav.interactiveContentPopGestureRecognizer?.isEnabled = false

            let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
            edge.edges = .left
            edge.delegate = self
            nav.view.addGestureRecognizer(edge)
            edgePan = edge

            return nav
        }

        @objc private func returnToFeatureHome() {
            guard navigation?.viewControllers.count == 1,
                navigation?.transitionCoordinator == nil else { return }
            returnToHome?()
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === edgePan,
                  let nav = navigation,
                  nav.viewControllers.count > 1,
                  nav.transitionCoordinator == nil,
                  interactiveDriver == nil,
                  activeOrigin != nil,
                  activeImage != nil
            else {
                return false
            }
            return true
        }

        @objc
        private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard let nav = navigation else { return }

            let width = max(nav.view.bounds.width, 1)
            let progress = min(max(gesture.translation(in: nav.view).x / width, 0), 1)

            switch gesture.state {
            case .began:
                guard interactiveDriver == nil, nav.viewControllers.count > 1 else { return }

                let driver = UIPercentDrivenInteractiveTransition()
                driver.completionCurve = .easeOut
                driver.completionSpeed = 0.95
                interactiveDriver = driver

                if nav.popViewController(animated: true) == nil {
                    interactiveDriver = nil
                    inputLease?.restore()
                    inputLease = nil
                }

            case .changed:
                interactiveDriver?.update(progress)

            case .ended:
                guard let driver = interactiveDriver else { return }
                let velocity = gesture.velocity(in: nav.view).x
                if progress >= 0.34 || velocity >= 700 {
                    driver.finish()
                } else {
                    driver.cancel()
                }

            case .cancelled, .failed:
                interactiveDriver?.cancel()

            default:
                break
            }
        }

        func navigationController(
            _ navigationController: UINavigationController,
            animationControllerFor operation: UINavigationController.Operation,
            from fromVC: UIViewController,
            to toVC: UIViewController
        ) -> UIViewControllerAnimatedTransitioning? {
            guard let origin = activeOrigin, let image = activeImage else { return nil }

            switch operation {
            case .push:
                guard toVC is UIHostingController<PetDetail> else { return nil }
            case .pop:
                guard fromVC is UIHostingController<PetDetail> else { return nil }
            default:
                return nil
            }

            // Each related detail carries its own source/hero pair. The frozen
            // animator and edge interaction are reused without changing their behavior.
            let detail = (operation == .push ? toVC : fromVC) as? UIHostingController<PetDetail>
            return PortraitNavigationAnimator(
                operation: operation,
                origin: detail?.rootView.transitionOrigin ?? origin,
                image: detail?.rootView.image ?? image,
                anchors: detail?.rootView.anchors ?? anchors
            )
        }

        func navigationController(
            _ navigationController: UINavigationController,
            interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
        ) -> UIViewControllerInteractiveTransitioning? {
            interactiveDriver
        }

        func navigationController(
            _ navigationController: UINavigationController,
            willShow viewController: UIViewController,
            animated: Bool
        ) {
            let showingCatalogGrid = viewController === navigationController.viewControllers.first
            navigationController.hidesBarsOnSwipe = showingCatalogGrid
            navigationController.setToolbarHidden(!showingCatalogGrid, animated: animated)
            (navigationController as? CatalogNavigationController)?.setHomeReturnEnabled(false)
#if DEBUG
            NavigationBarDiagnostics.log(navigationController, controller: viewController, phase: "willShow")
#endif
            guard animated,
                  viewController === navigationController.viewControllers.first,
                  let gridView = navigationController.viewControllers.first?.viewIfLoaded,
                  inputLease == nil
            else {
                return
            }

            inputLease = InputLease(
                gridView: gridView,
                scrollView: firstContentScrollView(in: gridView)
            )
        }

        func navigationController(
            _ navigationController: UINavigationController,
            didShow viewController: UIViewController,
            animated: Bool
        ) {
            (navigationController as? CatalogNavigationController)?.setHomeReturnEnabled(
                navigationController.viewControllers.count == 1)
            inputLease?.restore()
            inputLease = nil
            interactiveDriver = nil

#if DEBUG
            NavigationBarDiagnostics.log(navigationController, controller: viewController, phase: "didShow")
#endif

            if let detail = viewController as? UIHostingController<PetDetail> {
#if DEBUG
                let origin = PortraitOrigin(
                    petID: detail.rootView.pet.petId,
                    instance: "encyclopedia-grid"
                )
                let source = anchors.source(for: origin)
                logger.notice(
                    "portrait shown detail pet=\(origin.petID.rawValue) stack=\(navigationController.viewControllers.count) sameBitmap=\(source?.image === detail.rootView.image)"
                )
#endif
                return
            }

            if navigationController.viewControllers.count == 1,
               navigationController.topViewController === viewController {
                anchors.hero = nil
                activeOrigin = nil
                activeImage = nil
            }
        }

        private func openRelated(_ pet: Pet, origin: PortraitOrigin, anchors: PortraitAnchors) {
            guard let nav = navigation,
                  interactiveDriver == nil,
                  nav.transitionCoordinator == nil,
                  nav.topViewController is UIHostingController<PetDetail>
            else { return }
            let image = anchors.source(for: origin)?.image ?? UIImage(systemName: "photo")!

            let detail = NavigationContentHost(rootView: PetDetail(
                pet: pet, content: content, image: image, anchors: anchors,
                transitionOrigin: origin, portraits: portraits,
                openRelated: { [weak self] pet, origin, anchors in
                    self?.openRelated(pet, origin: origin, anchors: anchors)
                }
            ))
            detail.title = ""
            detail.navigationItem.largeTitleDisplayMode = .never
            nav.pushViewController(detail, animated: !UIAccessibility.isReduceMotionEnabled &&
                !ProcessInfo.processInfo.arguments.contains("--reduce-motion"))
        }

        func open(_ pet: Pet, _ origin: PortraitOrigin) {
            guard let nav = navigation,
                  interactiveDriver == nil,
                  nav.transitionCoordinator == nil,
                  nav.viewControllers.count == 1,
                  let image = anchors.source(for: origin)?.image
            else {
                return
            }

            activeOrigin = origin
            activeImage = image

            let detail = NavigationContentHost(
                rootView: PetDetail(
                    pet: pet,
                    content: content,
                    image: image,
                    anchors: anchors,
                    portraits: portraits,
                    openRelated: { [weak self] pet, origin, anchors in
                        self?.openRelated(pet, origin: origin, anchors: anchors)
                    }
                )
            )
            // Keep the detail navigation bar for the system back button, but
            // remove the centered pet title. The pet name is already rendered in
            // the SwiftUI detail content below.
            detail.title = ""
            detail.navigationItem.largeTitleDisplayMode = .never

            nav.pushViewController(
                detail,
                animated: !UIAccessibility.isReduceMotionEnabled &&
                    !ProcessInfo.processInfo.arguments.contains("--reduce-motion")
            )
        }
    }
}

/// The shared portrait is the only visual element whose geometry changes between
/// the two pages. Neither page view is scaled.
@MainActor
private final class PortraitNavigationAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let operation: UINavigationController.Operation
    private let origin: PortraitOrigin
    private let image: UIImage
    private let anchors: PortraitAnchors

    private var runningAnimator: UIViewPropertyAnimator?

    private static let offscreenPopStartGap: CGFloat = 1

    init(
        operation: UINavigationController.Operation,
        origin: PortraitOrigin,
        image: UIImage,
        anchors: PortraitAnchors
    ) {
        self.operation = operation
        self.origin = origin
        self.image = image
        self.anchors = anchors
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.38
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let animator = interruptibleAnimator(using: transitionContext)
        animator.startAnimation()
    }

    func interruptibleAnimator(
        using transitionContext: UIViewControllerContextTransitioning
    ) -> UIViewImplicitlyAnimating {
        if let runningAnimator {
            return runningAnimator
        }

        guard let fromVC = transitionContext.viewController(forKey: .from),
              let toVC = transitionContext.viewController(forKey: .to),
              let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to)
        else {
            let animator = UIViewPropertyAnimator(duration: 0, curve: .linear) {
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
            runningAnimator = animator
            return animator
        }

        let container = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)

        switch operation {
        case .push:
            toView.frame = transitionContext.finalFrame(for: toVC)
            if toView.superview == nil {
                container.addSubview(toView)
            } else {
                container.bringSubviewToFront(toView)
            }

        case .pop:
            toView.frame = transitionContext.finalFrame(for: toVC)
            if toView.superview == nil {
                container.insertSubview(toView, belowSubview: fromView)
            } else {
                container.insertSubview(toView, belowSubview: fromView)
            }

        default:
            break
        }

        // Force only normal layout. This is required so the destination
        // UIViewRepresentable has registered its hero/source before we measure it.
        container.layoutIfNeeded()
        toVC.view.layoutIfNeeded()
        fromVC.view.layoutIfNeeded()

        let source = anchors.source(for: origin)
        let hero = anchors.hero

        guard let source,
              let hero,
              source.window != nil,
              hero.window != nil,
              source.bounds.width > 0,
              source.bounds.height > 0,
              hero.bounds.width > 0,
              hero.bounds.height > 0
        else {
            return makeFallbackAnimator(
                transitionContext: transitionContext,
                fromView: fromView,
                toView: toView,
                duration: duration
            )
        }

        // Put the moving portrait above page content but *below* UINavigationBar.
        // When the detail has been scrolled, the real Hero is naturally occluded by
        // the bar. Adding the transition image directly to containerView lifts it
        // above that occlusion for the first interactive-pop frame, which causes the
        // visible "jump in front of the title bar".
        //
        // A navigation-level transparent overlay inserted immediately below the bar
        // preserves the exact z-order while still letting the shared portrait move
        // independently of both page views.
        let portraitHost: UIView
        let ownsPortraitHost: Bool
        if let navigationBar = fromVC.navigationController?.navigationBar,
           let barParent = navigationBar.superview {
            // On newer iOS releases UINavigationBar is not guaranteed to be a
            // direct child of UINavigationController.view. The previous version
            // required exactly that relationship, so it could silently fall back
            // to containerView and put the transition portrait above the bar.
            //
            // Insert into the bar's *actual* parent, immediately below the bar.
            // This guarantees the same occlusion relationship as normal scrolling
            // regardless of UIKit's private wrapper hierarchy.
            let overlay = UIView(frame: barParent.bounds)
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.backgroundColor = .clear
            overlay.isUserInteractionEnabled = false
            barParent.insertSubview(overlay, belowSubview: navigationBar)
            portraitHost = overlay
            ownsPortraitHost = true
        } else {
            portraitHost = container
            ownsPortraitHost = false
        }

        let sourceFrame = source.convert(source.bounds, to: portraitHost)
        var heroFrame = hero.convert(hero.bounds, to: portraitHost)
        if operation == .pop,
           let visibleRect = visibleContentRect(of: hero, in: fromVC, coordinateView: portraitHost),
           heroFrame.maxY <= visibleRect.minY {
            // Bound the start distance without scrolling or changing the real Hero.
            // A partially visible Hero always retains its actual frame.
            heroFrame.origin.y = visibleRect.minY - Self.offscreenPopStartGap - heroFrame.height
        }

        let sourceWasHidden = source.isHidden
        let heroWasHidden = hero.isHidden

        source.isHidden = true
        hero.isHidden = true

        let movingPortrait = UIImageView(image: image)
        movingPortrait.contentMode = .scaleAspectFit
        movingPortrait.backgroundColor = .clear
        movingPortrait.isOpaque = false
        movingPortrait.isUserInteractionEnabled = false

        switch operation {
        case .push:
            movingPortrait.frame = sourceFrame
            toView.alpha = 0
            portraitHost.addSubview(movingPortrait)

        case .pop:
            movingPortrait.frame = heroFrame
            fromView.alpha = 1
            toView.alpha = 1
            portraitHost.addSubview(movingPortrait)

        default:
            break
        }

        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeInOut)

        animator.addAnimations {
            switch self.operation {
            case .push:
                toView.alpha = 1
                movingPortrait.frame = heroFrame

            case .pop:
                fromView.alpha = 0
                movingPortrait.frame = sourceFrame

            default:
                break
            }
        }

        animator.addCompletion { [weak self] _ in
            guard let self else { return }

            let cancelled = transitionContext.transitionWasCancelled

            source.isHidden = sourceWasHidden
            hero.isHidden = heroWasHidden
            movingPortrait.removeFromSuperview()
            if ownsPortraitHost {
                portraitHost.removeFromSuperview()
            }

            fromView.alpha = 1
            toView.alpha = 1

            transitionContext.completeTransition(!cancelled)
            self.runningAnimator = nil
        }

        runningAnimator = animator
        return animator
    }

    private func visibleContentRect(
        of hero: UIView,
        in detail: UIViewController,
        coordinateView: UIView
    ) -> CGRect? {
        guard let detailView = detail.viewIfLoaded, hero.isDescendant(of: detailView) else { return nil }
        // Exclude the navigation bar and intersect the actual scroll/clipping viewport.
        var visibleRect = detailView.bounds.intersection(detailView.safeAreaLayoutGuide.layoutFrame)
        if let navigationView = detail.navigationController?.view {
            visibleRect = visibleRect.intersection(navigationView.convert(navigationView.bounds, to: detailView))
        }
        if let window = hero.window {
            visibleRect = visibleRect.intersection(window.convert(window.bounds, to: detailView))
        }
        var ancestor = hero.superview
        while let view = ancestor {
            if let scroll = view as? UIScrollView {
                let viewport = scroll.bounds.inset(by: scroll.adjustedContentInset)
                visibleRect = visibleRect.intersection(scroll.convert(viewport, to: detailView))
            } else if view.clipsToBounds {
                visibleRect = visibleRect.intersection(view.convert(view.bounds, to: detailView))
            }
            if view === detailView { break }
            ancestor = view.superview
        }
        guard !visibleRect.isNull, !visibleRect.isEmpty else { return nil }
        return detailView.convert(visibleRect, to: coordinateView)
    }

    private func makeFallbackAnimator(
        transitionContext: UIViewControllerContextTransitioning,
        fromView: UIView,
        toView: UIView,
        duration: TimeInterval
    ) -> UIViewImplicitlyAnimating {
        switch operation {
        case .push:
            toView.alpha = 0
        case .pop:
            fromView.alpha = 1
            toView.alpha = 1
        default:
            break
        }

        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeInOut)

        animator.addAnimations {
            switch self.operation {
            case .push:
                toView.alpha = 1
            case .pop:
                fromView.alpha = 0
            default:
                break
            }
        }

        animator.addCompletion { [weak self] _ in
            let cancelled = transitionContext.transitionWasCancelled
            fromView.alpha = 1
            toView.alpha = 1
            transitionContext.completeTransition(!cancelled)
            self?.runningAnimator = nil
        }

        runningAnimator = animator
        return animator
    }
}

/// Deliberately plain hosting controller. The bridge never takes ownership of
/// SwiftUI's internal ScrollView/navigation-bar tracking relationship.
private final class NavigationContentHost<Content: View>: UIHostingController<Content> {
#if DEBUG
    private var lastLayoutSnapshot: String?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let nav = navigationController else { return }

        let snapshot = NavigationBarDiagnostics.snapshot(nav, controller: self)
        if snapshot != lastLayoutSnapshot {
            lastLayoutSnapshot = snapshot
            NavigationBarDiagnostics.log(
                nav,
                controller: self,
                phase: "layoutChanged",
                snapshot: snapshot
            )
        }
    }
#endif
}

private func firstContentScrollView(in view: UIView) -> UIScrollView? {
    if let scroll = view as? UIScrollView {
        return scroll
    }

    for child in view.subviews {
        if let scroll = firstContentScrollView(in: child) {
            return scroll
        }
    }

    return nil
}

#if DEBUG
private enum NavigationBarDiagnostics {
    private static let logger = Logger(
        subsystem: "com.batzz.rocom",
        category: "navigation-bar"
    )

    static func snapshot(_ nav: UINavigationController, controller: UIViewController) -> String {
        let bar = nav.navigationBar
        let actual = controller.viewIfLoaded.flatMap { firstContentScrollView(in: $0) }
        let tracked = controller.contentScrollView(for: .top)

        func rect(_ value: CGRect) -> String {
            NSCoder.string(for: value)
        }

        func appearance(_ value: UINavigationBarAppearance?) -> String {
            guard let value else {
                return "nil(default inheritance)"
            }

            return "background=\(String(describing: value.backgroundColor)) effect=\(String(describing: value.backgroundEffect)) shadow=\(String(describing: value.shadowColor))"
        }

        let scroll: String
        if let actual {
            scroll =
                "offset=\(actual.contentOffset) inset=\(actual.contentInset) adjusted=\(actual.adjustedContentInset) safe=\(actual.safeAreaInsets) frame=\(rect(actual.frame)) bounds=\(rect(actual.bounds)) tracking=\(actual.isTracking) dragging=\(actual.isDragging) scrollEnabled=\(actual.isScrollEnabled) controllerInputEnabled=\(controller.viewIfLoaded?.isUserInteractionEnabled ?? false) topAssociationMatches=\(actual === tracked)"
        } else {
            scroll = "no materialized content ScrollView"
        }

        return "controller=\(controller.title ?? "nil") stack=\(nav.viewControllers.count) barFrame=\(rect(bar.frame)) barBounds=\(rect(bar.bounds)) controllerSafe=\(controller.viewIfLoaded.map { String(describing: $0.safeAreaInsets) } ?? "unloaded") largePreferred=\(bar.prefersLargeTitles) controllerTitleMode=\(controller.navigationItem.largeTitleDisplayMode.rawValue) topTitle=\(bar.topItem?.title ?? "nil") topTitleMode=\(bar.topItem?.largeTitleDisplayMode.rawValue ?? -1) scroll={\(scroll)} standard={\(appearance(bar.standardAppearance))} scrollEdge={\(appearance(bar.scrollEdgeAppearance))}"
    }

    static func log(
        _ nav: UINavigationController,
        controller: UIViewController,
        phase: String,
        snapshot: String? = nil
    ) {
        let value = snapshot ?? self.snapshot(nav, controller: controller)
        logger.notice(
            "nav-bar phase=\(phase, privacy: .public) \(value, privacy: .public)"
        )
    }
}
#endif
