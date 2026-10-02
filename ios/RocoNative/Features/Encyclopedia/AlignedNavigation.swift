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
            if let transition = navigationController.transitionCoordinator, transition.isInteractive {
                transition.notifyWhenInteractionChanges { [logger] context in
                    logger.notice("zoom interactive cancelled=\(context.isCancelled) completion=\(context.percentComplete)")
                }
            }
#endif
        }

        func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
#if DEBUG
            NavigationBarDiagnostics.log(navigationController, controller: viewController, phase: "didShow")
#endif
            // Observe UIKit's actual stack, never maintain a second navigation state.
            if let detail = viewController as? UIHostingController<PetDetail> {
#if DEBUG
                let origin = PortraitOrigin(petID: detail.rootView.pet.petId, instance: "encyclopedia-grid")
                let source = anchors.source(for: origin)
                logger.notice("zoom shown detail pet=\(origin.petID.rawValue) stack=\(navigationController.viewControllers.count) sameBitmap=\(source?.image === detail.rootView.image)")
#endif
            } else if navigationController.viewControllers.count == 1, navigationController.topViewController === viewController {
                // Completed pop, never cancelled pop. A framework-retained detached Hero
                // must not be resolved by a later route.
#if DEBUG
                logPopCompletion()
#endif
                anchors.hero = nil
            }
        }

        func open(_ pet: Pet, _ origin: PortraitOrigin) {
            guard let nav = navigation, nav.viewControllers.count == 1 else { return }
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

/// UIKit owns bar/title state. Select the actual SwiftUI content ScrollView through
/// the public controller contract instead of the container's subview-search heuristic.
/// This does not change offsets/insets, force layout, or schedule a post-transition refresh.
private final class NavigationContentHost<Content: View>: UIHostingController<Content> {
    private weak var registeredContentScrollView: UIScrollView?
#if DEBUG
    private var lastLayoutSnapshot: String?
#endif
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let scroll = firstContentScrollView(in: view), registeredContentScrollView !== scroll {
            // SwiftUI materializes its UIScrollView during layout. Bind each actual
            // instance once, so UIKit observes scroll-edge changes from its creation.
            registeredContentScrollView = scroll
            setContentScrollView(scroll, for: .top)
        }
#if DEBUG
        guard let nav = navigationController else { return }
        let snapshot = NavigationBarDiagnostics.snapshot(nav, controller: self)
        if snapshot != lastLayoutSnapshot {
            lastLayoutSnapshot = snapshot
            NavigationBarDiagnostics.log(nav, controller: self, phase: "layoutChanged", snapshot: snapshot)
        }
#endif
    }
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
            scroll = "offset=\(actual.contentOffset) inset=\(actual.contentInset) adjusted=\(actual.adjustedContentInset) safe=\(actual.safeAreaInsets) frame=\(rect(actual.frame)) bounds=\(rect(actual.bounds)) tracking=\(actual.isTracking) dragging=\(actual.isDragging) topAssociationMatches=\(actual === tracked)"
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
