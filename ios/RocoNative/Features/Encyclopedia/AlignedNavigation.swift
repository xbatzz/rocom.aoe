import SwiftUI
import RocoDomain
import RocoContent
import os

/// Frozen P0 architecture: UIKit owns standard navigation and interruptible zoom;
/// all content remains SwiftUI. No custom animator, gesture recognizer, or navigation stack.
struct AlignedNavigation: UIViewControllerRepresentable {
    let content: ContentStore
    let portraits: PortraitStore

    func makeCoordinator() -> Coordinator { Coordinator(content: content, portraits: portraits) }
    func makeUIViewController(context: Context) -> UINavigationController {
        context.coordinator.makeNavigation(pets: content.orderedPets)
    }
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UINavigationControllerDelegate {
        let anchors = PortraitAnchors()
        let content: ContentStore
        let portraits: PortraitStore
        weak var navigation: UINavigationController?
        private var interactivePop: InteractivePopSession?

        /// An input lease for one UIKit transition, not another navigation stack/path.
        private final class InteractivePopSession {
            let transitionID: ObjectIdentifier
            let gridView: UIView
            let scrollView: UIScrollView?
            let interactionWasEnabled: Bool
            let scrollingWasEnabled: Bool?

            init(transitionID: ObjectIdentifier, gridView: UIView, scrollView: UIScrollView?) {
                self.transitionID = transitionID
                self.gridView = gridView
                self.scrollView = scrollView
                interactionWasEnabled = gridView.isUserInteractionEnabled
                scrollingWasEnabled = scrollView?.isScrollEnabled
                scrollView?.isScrollEnabled = false
                gridView.isUserInteractionEnabled = false
            }
            func restoreInput() {
                if let scrollingWasEnabled { scrollView?.isScrollEnabled = scrollingWasEnabled }
                gridView.isUserInteractionEnabled = interactionWasEnabled
            }
        }
        init(content: ContentStore, portraits: PortraitStore) { self.content = content; self.portraits = portraits; super.init() }
#if DEBUG
        private let logger = Logger(subsystem: "top.aoe.rocom.prototype", category: "navigation")
        // Scalar telemetry only; does not retain views or drive navigation/layout.
        private struct ZoomMeasurement {
            let origin: PortraitOrigin
            let sourceIdentity: ObjectIdentifier?
            var targetWindowRect: CGRect?
        }
        private var zoomMeasurement: ZoomMeasurement?

        private static func windowRect(_ view: UIView?) -> CGRect? {
            guard let view, let window = view.window else { return nil }
            return view.convert(view.bounds, to: window)
        }
        private func logPopCompletion() {
            guard let measurement = zoomMeasurement else { return }
            let source = anchors.source(for: measurement.origin)
            let actual = Self.windowRect(source)
            let sameSource = source.map { ObjectIdentifier($0) == measurement.sourceIdentity } ?? false
            let delta: String
            if let target = measurement.targetWindowRect, let actual {
                delta = "center=(\(actual.midX - target.midX),\(actual.midY - target.midY)) width=\(actual.width - target.width) height=\(actual.height - target.height)"
            } else {
                delta = "unavailable"
            }
            logger.notice("zoom pop completion pet=\(measurement.origin.petID.rawValue) sameSource=\(sameSource) targetWindow=\(measurement.targetWindowRect.map { NSCoder.string(for: $0) } ?? "unavailable", privacy: .public) gridImageWindow=\(actual.map { NSCoder.string(for: $0) } ?? "unavailable", privacy: .public) targetDelta=\(delta, privacy: .public)")
            zoomMeasurement = nil
        }
#endif

        func makeNavigation(pets: [Pet]) -> UINavigationController {
            let root = NavigationContentHost(rootView: AlignedPetGrid(pets: pets, portraits: portraits, anchors: anchors, open: open))
            root.title = "图鉴"
            root.navigationItem.largeTitleDisplayMode = .always
            let nav = UINavigationController(rootViewController: root)
            nav.navigationBar.prefersLargeTitles = true
            navigation = nav
            nav.delegate = self
            return nav
        }

        func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
#if DEBUG
            NavigationBarDiagnostics.log(navigationController, controller: viewController, phase: "willShow")
#endif
            guard animated, let transition = navigationController.transitionCoordinator,
                let grid = navigationController.viewControllers.first, viewController === grid,
                transition.viewController(forKey: .from) !== grid else { return }
            let transitionID = ObjectIdentifier(transition)
            // Keep the destination Grid inert for the entire pop, not just while
            // UIKit reports the transition as interactive. Fluid zoom keeps using
            // the live source view during its settling animation, so moving the
            // ScrollView before didShow can move the zoom target under UIKit.
            if interactivePop == nil, let gridView = grid.viewIfLoaded {
                interactivePop = InteractivePopSession(transitionID: transitionID, gridView: gridView,
                    scrollView: firstContentScrollView(in: gridView))
            }
#if DEBUG
            logPopPhase(navigationController, context: transition, phase: "popBegin")
#endif
            // A finish/cancel decision starts a remaining, non-interactive animation.
            // This callback must NEVER restore input, clear Hero, or rebind scroll tracking.
            transition.notifyWhenInteractionChanges { [weak self, weak navigationController] context in
#if DEBUG
                guard let self, let navigationController else { return }
                self.logPopPhase(navigationController, context: context, phase: "interactionChanged")
#endif
            }
            // Do not release the input lease from a transition-coordinator callback.
            // With the system fluid zoom, the source view can remain part of the
            // visual settling/handoff after the interaction itself has ended. The
            // navigation controller's didShow callback is our single release point.
        }

        private func completeInteractivePop(_ nav: UINavigationController, transitionID: ObjectIdentifier,
            visible: UIViewController?, cancelled: Bool) {
            guard let session = interactivePop, session.transitionID == transitionID else { return }
            // didShow is the only release boundary. Do not rebind navigation-bar
            // scroll tracking here: SwiftUI/UIHostingController already own that
            // relationship, and binding a transformed destination ScrollView into
            // UIKit's bar observation path can leave scroll-edge geometry stale.
            if !cancelled {
#if DEBUG
                logPopCompletion()
#endif
                anchors.hero = nil
            }
            // Cancel keeps the displayed Detail/Hero alive. Both paths release the
            // Grid input lease, restoring precisely the pre-transition settings.
            session.restoreInput()
            interactivePop = nil
#if DEBUG
            if let visible { NavigationBarDiagnostics.log(nav, controller: visible, phase: "completionInputRestored cancelled=\(cancelled)") }
#endif
        }
#if DEBUG
        private func logPopPhase(_ nav: UINavigationController, context: any UIViewControllerTransitionCoordinatorContext, phase: String) {
            let state = "\(phase) initiallyInteractive=\(context.initiallyInteractive) interactive=\(context.isInteractive) cancelled=\(context.isCancelled) percent=\(context.percentComplete) gridInputLocked=\(interactivePop != nil)"
            if let from = context.viewController(forKey: .from) { NavigationBarDiagnostics.log(nav, controller: from, phase: state + " from") }
            if let to = context.viewController(forKey: .to) { NavigationBarDiagnostics.log(nav, controller: to, phase: state + " to") }
        }
#endif

        func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
#if DEBUG
            NavigationBarDiagnostics.log(navigationController, controller: viewController, phase: "didShow")
#endif
            var completedPopSession = false
            if let session = interactivePop {
                let cancelled = viewController !== navigationController.viewControllers.first
                completeInteractivePop(navigationController, transitionID: session.transitionID,
                    visible: viewController, cancelled: cancelled)
                completedPopSession = true
            }
            // Observe UIKit's actual stack, never maintain a second navigation state.
            if let detail = viewController as? UIHostingController<PetDetail> {
#if DEBUG
                let origin = PortraitOrigin(petID: detail.rootView.pet.petId, instance: "encyclopedia-grid")
                let source = anchors.source(for: origin)
                logger.notice("zoom shown detail pet=\(origin.petID.rawValue) stack=\(navigationController.viewControllers.count) sameBitmap=\(source?.image === detail.rootView.image)")
#endif
            } else if navigationController.viewControllers.count == 1, navigationController.topViewController === viewController {
                // A pop session already performed final cleanup above. For nonanimated
                // or otherwise sessionless pops, keep the existing fallback cleanup.
                guard !completedPopSession else { return }
                // Completed pop, never cancelled pop. A framework-retained detached Hero
                // must not be resolved by a later route.
#if DEBUG
                logPopCompletion()
#endif
                anchors.hero = nil
            }
        }

        func open(_ pet: Pet, _ origin: PortraitOrigin) {
            guard interactivePop == nil, let nav = navigation, nav.viewControllers.count == 1 else { return }
            // The route/hosting view retains this exact bitmap even if the bounded cache evicts it.
            guard let image = anchors.source(for: origin)?.image else { return }
            let detail = NavigationContentHost(rootView: PetDetail(pet: pet, content: content, image: image, anchors: anchors))
            detail.title = pet.nameZh
            detail.navigationItem.largeTitleDisplayMode = .never
#if DEBUG
            zoomMeasurement = nil
#endif
            if !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.arguments.contains("--reduce-motion") {
#if DEBUG
                zoomMeasurement = ZoomMeasurement(origin: origin, sourceIdentity: anchors.source(for: origin).map(ObjectIdentifier.init))
#endif
                let options = UIViewController.Transition.ZoomOptions()
                options.alignmentRectProvider = { [weak self, weak anchors] context in
                    guard let hero = anchors?.hero, hero.isDescendant(of: context.zoomedViewController.view) else { return nil }
                    // Align the registered images; UIKit manages transition visibility.
                    guard hero.bounds.width > 0, hero.bounds.height > 0 else { return nil }
                    let rect = hero.convert(hero.bounds, to: context.zoomedViewController.view)
#if DEBUG
                    if self?.zoomMeasurement?.origin == origin {
                        self?.zoomMeasurement?.targetWindowRect = Self.windowRect(context.sourceView)
                    }
#endif
                    return rect
                }
                // System resolves identity again on dismissal, never a stored cell/index path.
                detail.preferredTransition = .zoom(options: options) { [weak self, weak anchors] _ in
                    let source = anchors?.source(for: origin)?.transitionImageView
#if DEBUG
                    if self?.zoomMeasurement?.origin == origin {
                        self?.zoomMeasurement?.targetWindowRect = Self.windowRect(source)
                    }
#endif
                    return source
                }
            }
#if DEBUG
            if let grid = nav.topViewController {
                NavigationBarDiagnostics.log(nav, controller: grid, phase: "beforePush")
            }
#endif
            nav.pushViewController(detail, animated: !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.arguments.contains("--reduce-motion"))
        }
    }
}

/// Keep the hosting controller deliberately plain. UIKit/SwiftUI own navigation-bar
/// scroll-edge tracking; the zoom bridge must not register SwiftUI's internal
/// UIScrollView with setContentScrollView(_:for:) or mutate that relationship during
/// a transition. The view hierarchy is still inspected read-only in DEBUG diagnostics.
private final class NavigationContentHost<Content: View>: UIHostingController<Content> {
#if DEBUG
    private var lastLayoutSnapshot: String?
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let nav = navigationController else { return }
        let snapshot = NavigationBarDiagnostics.snapshot(nav, controller: self)
        if snapshot != lastLayoutSnapshot {
            lastLayoutSnapshot = snapshot
            NavigationBarDiagnostics.log(nav, controller: self, phase: "layoutChanged", snapshot: snapshot)
        }
    }
#endif
}

private func firstContentScrollView(in view: UIView) -> UIScrollView? {
    if let scroll = view as? UIScrollView { return scroll }
    for child in view.subviews {
        if let scroll = firstContentScrollView(in: child) { return scroll }
    }
    return nil
}

#if DEBUG
/// Read-only measurements. No private selectors, layout mutation, touch handlers,
/// timing workarounds, or persistent navigation state.
private enum NavigationBarDiagnostics {
    private static let logger = Logger(subsystem: "com.batzz.rocom", category: "navigation-bar")

    static func snapshot(_ nav: UINavigationController, controller: UIViewController) -> String {
        let bar = nav.navigationBar
        let actual = controller.viewIfLoaded.flatMap { firstContentScrollView(in: $0) }
        let tracked = controller.contentScrollView(for: .top)
        func rect(_ value: CGRect) -> String { NSCoder.string(for: value) }
        func appearance(_ value: UINavigationBarAppearance?) -> String {
            guard let value else { return "nil(default inheritance)" }
            return "background=\(String(describing: value.backgroundColor)) effect=\(String(describing: value.backgroundEffect)) shadow=\(String(describing: value.shadowColor))"
        }
        let scroll: String
        if let actual {
            scroll = "offset=\(actual.contentOffset) inset=\(actual.contentInset) adjusted=\(actual.adjustedContentInset) safe=\(actual.safeAreaInsets) frame=\(rect(actual.frame)) bounds=\(rect(actual.bounds)) tracking=\(actual.isTracking) dragging=\(actual.isDragging) scrollEnabled=\(actual.isScrollEnabled) controllerInputEnabled=\(controller.viewIfLoaded?.isUserInteractionEnabled ?? false) topAssociationMatches=\(actual === tracked)"
        } else { scroll = "no materialized content ScrollView" }
        // Public UIView hierarchy access is only used to read the background/effect/
        // hairline geometry. Internal class names are labels, never API dependencies.
        var layers: [String] = []
        func inspect(_ view: UIView, depth: Int) {
            guard depth < 6 else { return }
            let name = String(describing: type(of: view))
            if name.contains("Background") || view is UIVisualEffectView || (view.bounds.height <= 1 && view.bounds.width > 20) {
                layers.append("\(name) frame=\(rect(view.frame)) barRect=\(rect(view.convert(view.bounds, to: bar))) hidden=\(view.isHidden) alpha=\(view.alpha)")
            }
            for child in view.subviews { inspect(child, depth: depth + 1) }
        }
        inspect(bar, depth: 0)
        return "controller=\(controller.title ?? "nil") stack=\(nav.viewControllers.count) barFrame=\(rect(bar.frame)) barBounds=\(rect(bar.bounds)) controllerSafe=\(controller.viewIfLoaded.map { String(describing: $0.safeAreaInsets) } ?? "unloaded") largePreferred=\(bar.prefersLargeTitles) controllerTitleMode=\(controller.navigationItem.largeTitleDisplayMode.rawValue) topTitle=\(bar.topItem?.title ?? "nil") topTitleMode=\(bar.topItem?.largeTitleDisplayMode.rawValue ?? -1) scroll={\(scroll)} standard={\(appearance(bar.standardAppearance))} scrollEdge={\(appearance(bar.scrollEdgeAppearance))} itemStandard={\(appearance(controller.navigationItem.standardAppearance))} itemScrollEdge={\(appearance(controller.navigationItem.scrollEdgeAppearance))} layers={\(layers.joined(separator: "; "))}"
    }
    static func log(_ nav: UINavigationController, controller: UIViewController, phase: String, snapshot: String? = nil) {
        let value = snapshot ?? self.snapshot(nav, controller: controller)
        logger.notice("nav-bar phase=\(phase, privacy: .public) \(value, privacy: .public)")
    }
}
#endif
