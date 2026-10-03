import XCTest
import SwiftUI
import RocoDomain
import RocoContent
@testable import RocoNative

/// App-hosted integration tests use the real system navigation controller on Simulator.
/// Programmatic interruption does not substitute for a finger tapping during zoom.
final class NavigationLifetimeTests: XCTestCase {
    @MainActor
    func testFixedTeamImageCropRecognition() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1625, height: 747))
        let image = renderer.image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1625, height: 747))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 22), .foregroundColor: UIColor.black]
            for top in [22, 270, 518] {
                for x in [334, 970] {
                    ("ALPHA" as NSString).draw(at: CGPoint(x: x + 3, y: top + 4), withAttributes: attributes)
                    ("BRAVE" as NSString).draw(at: CGPoint(x: x + 181, y: top + 55), withAttributes: attributes)
                    for offset in [0, 85, 169, 254] { ("MOVE" as NSString).draw(at: CGPoint(x: x + offset + 1, y: top + 179), withAttributes: attributes) }
                }
            }
            ("TEAM" as NSString).draw(at: CGPoint(x: 1383, y: 523), withAttributes: attributes)
        }
        let decoded = try await TeamImageOCR.decode(XCTUnwrap(image.pngData()))
        XCTAssertLessThanOrEqual(decoded.width, 1625)
        let result = try await TeamImageOCR.read(decoded, templates: [])
        XCTAssertEqual(result.slots.count, 6)
        XCTAssertTrue(result.slots.allSatisfy { $0.text[0] == "ALPHA" && $0.text[1] == "BRAVE" && $0.typeID == nil })
        XCTAssertEqual(result.name, "TEAM")
        XCTAssertTrue(result.slots.allSatisfy { $0.text.dropFirst(3).allSatisfy { $0 == "MOVE" } })
    }

    @MainActor
    func testCoordinatorOwnershipEndsWithNavigation() async throws {
        var (coordinator, pets): (AlignedNavigation.Coordinator?, [Pet]) = try await fixture()
        var nav: UINavigationController? = try XCTUnwrap(coordinator).makeNavigation(pets: pets)
        weak let releasedCoordinator = coordinator
        weak let releasedNavigation = nav
        let window = try makeWindow(XCTUnwrap(nav))
        nav?.view.layoutIfNeeded()
        coordinator = nil
        XCTAssertNotNil(releasedCoordinator, "The root's action keeps its local coordinator alive")
        window.isHidden = true
        window.rootViewController = nil
        nav = nil
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            releasedCoordinator == nil && releasedNavigation == nil
        }, object: nil)
        let result = await XCTWaiter.fulfillment(of: [released], timeout: 3)
        XCTAssertEqual(result, .completed)
    }
    @MainActor
    func testImmediateProgrammaticPopAndReuse() async throws {
        let (coordinator, pets) = try await fixture()
        let nav = coordinator.makeNavigation(pets: pets)
        let window = try makeWindow(nav)
        defer { window.isHidden = true; window.rootViewController = nil }
        nav.view.layoutIfNeeded()
        let observer = NavigationObserver(forwarding: coordinator)
        nav.delegate = observer
        let root = try XCTUnwrap(nav.viewControllers.first)
        let visiblePets = visibleCatalogPets(pets)
        XCTAssertGreaterThanOrEqual(visiblePets.count, 2)
        for index in 0..<10 {
            let pet = visiblePets[index % 2]
            let origin = PortraitOrigin(petID: pet.petId, instance: "encyclopedia-grid")
            await observer.perform(expecting: { $0 === root }) {
                coordinator.open(pet, origin)
                // Same main-actor turn, before awaiting push completion.
                let popped = nav.popViewController(animated: true)
                print("IMMEDIATE index=\(index) accepted=\(popped != nil) stack=\(nav.viewControllers.count)")
                XCTAssertNotNil(popped, "System must accept the immediate programmatic pop")
            }
            XCTAssertEqual(nav.viewControllers.count, 1)
            XCTAssertTrue(nav.view.isUserInteractionEnabled)
            let source = try XCTUnwrap(coordinator.anchors.source(for: origin))
            XCTAssertFalse(source.isHidden)
            XCTAssertGreaterThan(source.alpha, 0.99)
            XCTAssertFalse(source.transitionImageView.isHidden)
            XCTAssertGreaterThan(source.transitionImageView.alpha, 0.99)
            await observer.perform(expecting: { ($0 as? UIHostingController<RocoNative.PetDetail>)?.rootView.pet.petId == pet.petId }) {
                coordinator.open(pet, origin)
            }
            let detail = try XCTUnwrap(nav.topViewController as? UIHostingController<RocoNative.PetDetail>)
            XCTAssertTrue(detail.rootView.image === source.image)
            await observer.perform(expecting: { $0 === root }) {
                nav.popViewController(animated: true)
            }
            XCTAssertEqual(nav.viewControllers.count, 1)
        }
    }

    @MainActor
    func testDetailAndBitmapLifetime() async throws {
        let (coordinator, pets) = try await fixture()
        let nav = coordinator.makeNavigation(pets: pets)
        let window = try makeWindow(nav)
        defer { window.isHidden = true; window.rootViewController = nil }
        nav.view.layoutIfNeeded()
        let pet = try XCTUnwrap(visibleCatalogPets(pets).first)
        let origin = PortraitOrigin(petID: pet.petId, instance: "encyclopedia-grid")
        let source = try XCTUnwrap(coordinator.anchors.source(for: origin))
        coordinator.open(pet, origin)
        await finishTransition(nav)
        weak let releasedDetail = nav.topViewController
        weak let releasedHero = coordinator.anchors.hero
        XCTAssertNotNil(releasedHero)
        XCTAssertTrue(coordinator.anchors.hero?.image === source.image)
        nav.popViewController(animated: true)
        await finishTransition(nav)
        // Let UIKit release the transition coordinator on the next main queue turn, not a timer.
        await nextMainTurn()
        XCTAssertNil(releasedDetail)
        XCTAssertNil(coordinator.anchors.hero)
        XCTAssertNil(releasedHero?.window, "A framework-retained detached view must not remain visible")
        XCTAssertTrue(coordinator.anchors.source(for: origin)?.image === source.image)
        XCTAssertFalse(source.isHidden)
        XCTAssertFalse(source.transitionImageView.isHidden)
        XCTAssertGreaterThan(source.transitionImageView.alpha, 0.99)
    }

    // Focused P1 checks: no scrolling matrix, repeated UI automation, or interactive-pop rewrite.
    @MainActor
    func testRealContentLazyPortraitsAndKnownMissing() async throws {
        let (coordinator, pets) = try await fixture()
        let portraits = coordinator.portraits
        XCTAssertEqual(pets.count, 721)
        XCTAssertEqual(pets.map(\.petId), coordinator.content.orderedPets.map(\.petId))
        XCTAssertEqual(pets.first?.petId.rawValue, 16000004)
        XCTAssertEqual(portraits.decodeCount, 0, "Initializing the store must not decode any images")
        XCTAssertEqual(portraits.placeholderCreationCount, 0)
        let pet = try XCTUnwrap(coordinator.content.pet(PetID(rawValue: 3001)))
        XCTAssertEqual(pet.nameZh, "喵喵")
        let image = try portraits.image(for: pet)
        XCTAssertTrue(try portraits.image(for: pet) === image)
        XCTAssertEqual(portraits.decodeCount, 1)
        XCTAssertLessThanOrEqual(image.cgImage?.width ?? 0, 512)
        XCTAssertLessThanOrEqual(image.cgImage?.height ?? 0, 512)
        let a = try XCTUnwrap(coordinator.content.pet(PetID(rawValue: 3784)))
        let b = try XCTUnwrap(coordinator.content.pet(PetID(rawValue: 3785)))
        let placeholder = try portraits.image(for: a)
        XCTAssertTrue(try portraits.image(for: b) === placeholder)
        XCTAssertTrue(try portraits.image(for: a) === placeholder)
        XCTAssertEqual(portraits.placeholderCreationCount, 1)
        XCTAssertEqual(portraits.decodeCount, 1, "Known missing never decode a fabricated file")
    }

    @MainActor
    func testRealContentSourceAndHeroShareBitmap() async throws {
        let (coordinator, pets) = try await fixture()
        let nav = coordinator.makeNavigation(pets: pets)
        let window = try makeWindow(nav)
        defer { window.isHidden = true; window.rootViewController = nil }
        nav.view.layoutIfNeeded()
        await nextMainTurn()
        let pet = try XCTUnwrap(visibleCatalogPets(pets).first)
        let origin = PortraitOrigin(petID: pet.petId, instance: "encyclopedia-grid")
        let source = try XCTUnwrap(coordinator.anchors.source(for: origin))
        let image = try XCTUnwrap(source.image)
        XCTAssertLessThan(coordinator.portraits.decodeCount, pets.count, "Lazy first render must not decode the catalog")
        print("FOCUSED_GRID pets=\(pets.count) initialDecoded=\(coordinator.portraits.decodeCount)")
        coordinator.open(pet, origin)
        let detail = try XCTUnwrap(nav.topViewController as? UIHostingController<RocoNative.PetDetail>)
        XCTAssertTrue(detail.rootView.image === image)
        XCTAssertEqual(detail.rootView.pet.petId, pet.petId)
        XCTAssertEqual(detail.rootView.content.pets.count, 721)
        await finishTransition(nav)
        XCTAssertTrue(coordinator.anchors.hero?.image === image)
        nav.popViewController(animated: false)
        await nextMainTurn()
    }

    private func visibleCatalogPets(_ pets: [Pet]) -> [Pet] {
        PetCatalogPresentation.collapseDuplicateLeaderConfigurations(pets.filter { $0.implemented && $0.publicVisible })
            .sorted(by: PetCatalogPresentation.handbookOrder)
    }

    @MainActor
    private func fixture() async throws -> (AlignedNavigation.Coordinator, [Pet]) {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "ContentResources", withExtension: "bundle"))
        let content = try await ContentStore.loadInBackground(bundleURL: url)
        let portraits = PortraitStore(resolver: content.assetResolver)
        return (AlignedNavigation.Coordinator(content: content, portraits: portraits), content.orderedPets)
    }
    @MainActor
    private func makeWindow(_ nav: UINavigationController) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = nav
        window.makeKeyAndVisible()
        return window
    }
    @MainActor
    private func finishTransition(_ nav: UINavigationController) async {
        guard let transition = nav.transitionCoordinator else { return }
        await withCheckedContinuation { continuation in
            let registered = transition.animate(alongsideTransition: nil) { _ in continuation.resume() }
            if !registered { continuation.resume() }
        }
    }
    @MainActor
    private func nextMainTurn() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

/// Test-only observer: wait for the actual didShow contract, including queued pops.
/// No navigation state, timers, or production lifecycle hooks are added.
@MainActor
private final class NavigationObserver: NSObject, UINavigationControllerDelegate {
    let forwarding: AlignedNavigation.Coordinator
    private var pending: ((UIViewController) -> Bool)?
    private var shown: XCTestExpectation?
    init(forwarding: AlignedNavigation.Coordinator) { self.forwarding = forwarding }

    func perform(expecting predicate: @escaping (UIViewController) -> Bool, action: () -> Void) async {
        let event = XCTestExpectation(description: "UIKit didShow expected controller")
        pending = predicate
        shown = event
        action()
        let result = await XCTWaiter.fulfillment(of: [event], timeout: 4)
        pending = nil
        shown = nil
        XCTAssertEqual(result, .completed)
    }
    func navigationController(_ nav: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        forwarding.navigationController(nav, willShow: viewController, animated: animated)
    }
    func navigationController(_ nav: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        forwarding.navigationController(nav, didShow: viewController, animated: animated)
        if pending?(viewController) == true, let event = shown {
            pending = nil
            // Resume after this delegate callback returns to UIKit.
            DispatchQueue.main.async { event.fulfill() }
        }
    }
}
