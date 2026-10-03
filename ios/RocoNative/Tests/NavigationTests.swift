import XCTest

final class NavigationTests: XCTestCase {
    @MainActor
    func testHomeStartupAndFeatureNavigation() {
        let app = XCUIApplication()
        // Exercise the production home with an isolated database, including a fresh process relaunch.
        app.launchArguments = ["--visual-review", "home"]
        for _ in 0..<2 {
            app.launch()
            XCTAssertTrue(app.navigationBars["洛克工具"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["正在加载内容…"].exists)
            app.staticTexts["技能查询"].firstMatch.tap()
            XCTAssertTrue(app.navigationBars["技能查询"].waitForExistence(timeout: 3))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            app.staticTexts["异色收集"].firstMatch.tap()
            XCTAssertTrue(app.navigationBars["异色收集"].waitForExistence(timeout: 3))
            app.terminate()
        }
    }

    @MainActor
    func testCrossFadePrototype() {
        let app = XCUIApplication()
        app.launchArguments = ["--swiftui-cross-fade"]
        app.launch()
        attach("cross-fade-grid", app)
        app.buttons["pet-3001"].tap()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 4))
        attach("cross-fade-hero", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["pet-3001"].isHittable)
    }
    @MainActor
    func testImmediateTouchReturnAndRapidReuse() async throws {
        let app = XCUIApplication()
        app.launch()
        let expected = XCTExpectedFailure.Options()
        expected.issueMatcher = { $0.compactDescription.contains("System Back touch at") }
        XCTExpectFailure("P0 unclosed: early raw Back touches during system zoom do not complete a pop on iOS 27 (reproduced)", options: expected)
        // Locate the system Back button once; the following event records contain
        // both taps and never wait for quiescence between opening and returning.
        app.buttons["pet-3001"].tap()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 4))
        let back = app.navigationBars.buttons.element(boundBy: 0)
        let backPoint = CGPoint(x: back.frame.midX, y: back.frame.midY)
        back.tap()
        for (index, delay) in [0.30, 0.15, 0.08].enumerated() {
            let id = index.isMultiple(of: 2) ? 3001 : 3002
            let cell = app.buttons["pet-\(id)"]
            let point = CGPoint(x: cell.frame.midX, y: cell.frame.midY)
            try await sendTouchTracks([[point], [backPoint]], times: [[0], [NSNumber(value: delay)]], releases: [0.01, NSNumber(value: delay + 0.01)])
            attach("immediate-\(index)-\(delay)", app)
            let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.scrollViews["detail-\(id)"])
            if await XCTWaiter.fulfillment(of: [returned], timeout: 4) != .completed {
                XCTFail("System Back touch at \(delay)s did not return during opening")
                app.navigationBars.buttons.element(boundBy: 0).tap()
                XCTAssertFalse(app.scrollViews["detail-\(id)"].exists)
            }
            XCTAssertTrue(app.buttons["pet-3001"].isHittable)
            XCTAssertTrue(app.buttons["pet-3002"].isHittable)
        }
    }
    @MainActor
    func testImmediateInteractiveReturnAndReuse() async throws {
        let app = XCUIApplication()
        app.launch()
        let expected = XCTExpectedFailure.Options()
        expected.issueMatcher = { $0.compactDescription.contains("Immediate interactive return did not complete") }
        XCTExpectFailure("P0 unclosed: early raw drag during opening system zoom does not start interactive return on iOS 27 (reproduced)", options: expected)
        for id in [3001, 3002] {
            let cell = app.buttons["pet-\(id)"]
            let point = CGPoint(x: cell.frame.midX, y: cell.frame.midY)
            // Grab the still-expanding image, rather than the future full-screen edge.
            let start = point
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.80)).screenPoint
            try await sendTouchTracks([[point], [start, end]], times: [[0], [0.15, 0.45]], releases: [0.01, 0.47])
            attach("immediate-interactive-\(id)", app)
            let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.scrollViews["detail-\(id)"])
            if await XCTWaiter.fulfillment(of: [returned], timeout: 4) != .completed {
                XCTFail("Immediate interactive return did not complete")
                app.navigationBars.buttons.element(boundBy: 0).tap()
                XCTAssertFalse(app.scrollViews["detail-\(id)"].exists)
            }
            XCTAssertTrue(app.buttons["pet-3001"].isHittable)
            XCTAssertTrue(app.buttons["pet-3002"].isHittable)
        }
    }
    @MainActor
    func testHalfDistanceReverseCancellation() async throws {
        try await checkReverseCancellation(at: 0.53)
    }
    @MainActor
    func testEightyPercentDistanceReverseCancellation() async throws {
        try await checkReverseCancellation(at: 0.83)
    }
    @MainActor
    private func checkReverseCancellation(at distance: Double) async throws {
        let app = XCUIApplication()
        app.launch()
        let cell = app.buttons["pet-3001"]
        let original = cell.frame
        cell.tap()
        let detail = app.scrollViews["detail-3001"]
        XCTAssertTrue(detail.waitForExistence(timeout: 4))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.45)).screenPoint
        let far = app.coordinate(withNormalizedOffset: CGVector(dx: distance, dy: 0.45)).screenPoint
        let near = app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.45)).screenPoint
        try await sendTouchTracks([[start, far, far, near]], times: [[0, 0.60, 0.85, 1.10]], releases: [1.12])
        XCTAssertTrue(detail.exists, "Continuous reversal must cancel the interactive pop")
        attach("reverse-cancel-\(distance)", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(cell.isHittable)
        XCTAssertEqual(cell.frame.minY, original.minY, accuracy: 2)
        attach("reverse-returned-\(distance)", app)
        for id in [3001, 3002] {
            app.buttons["pet-\(id)"].tap()
            XCTAssertTrue(app.scrollViews["detail-\(id)"].waitForExistence(timeout: 4))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(cell.isHittable)
        }
    }
    @MainActor
    private func sendTouchTracks(_ tracks: [[CGPoint]], times: [[NSNumber]], releases: [NSNumber]) async throws {
        let points = tracks.map { $0.map { NSValue(cgPoint: $0) } }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                P0SendTouchTracks(points, times, releases) { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
        } catch let error as NSError where error.domain == "P0TouchDriver" && error.code == 1 {
            throw XCTSkip(error.localizedDescription)
        }
    }
    @MainActor
    func testCancellationRecoveryAcrossPets() {
        let app = XCUIApplication()
        app.launch()
        let original = app.buttons["pet-3001"]
        let before = original.frame
        for id in [3001, 3001, 3002] {
            let cell = app.buttons["pet-\(id)"]
            XCTAssertTrue(cell.isHittable)
            cell.tap()
            let detail = app.scrollViews["detail-\(id)"]
            XCTAssertTrue(detail.waitForExistence(timeout: 4))
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.45))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.45))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
            XCTAssertTrue(detail.exists)
            XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).isHittable)
            attach("recovery-cancel-\(id)", app)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertFalse(detail.exists)
            XCTAssertTrue(original.isHittable)
            XCTAssertTrue(app.buttons["pet-3002"].isHittable)
            XCTAssertEqual(original.frame.minY, before.minY, accuracy: 2)
            attach("recovery-grid-\(id)", app)
        }
    }
    @MainActor
    func testRapidSequentialReturn() {
        let app = XCUIApplication()
        app.launch()
        // No explicit waits/sleeps between actions. XCTest itself still waits for app idleness;
        // this test cannot prove a tap during the opening transition.
        for id in [3001, 3002, 3001, 3002, 3001, 3002] {
            app.buttons["pet-\(id)"].tap()
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertFalse(app.scrollViews["detail-\(id)"].exists)
            XCTAssertTrue(app.buttons["pet-3001"].isHittable)
            XCTAssertTrue(app.buttons["pet-3002"].isHittable)
        }
        attach("rapid-returned", app)
    }
    @MainActor
    func testAccessibilityGridAndDetail() throws {
        let app = XCUIApplication()
        app.launch()
        let cell = app.buttons["pet-3001"]
        XCTAssertTrue(cell.waitForExistence(timeout: 4))
        XCTAssertGreaterThanOrEqual(cell.frame.width, 44)
        XCTAssertGreaterThanOrEqual(cell.frame.height, 44)
        XCTAssertTrue(cell.label.contains("喵喵"))
        attach("accessibility-grid", app)
        try app.performAccessibilityAudit()
        cell.tap()
        let detail = app.scrollViews["detail-3001"]
        XCTAssertTrue(detail.waitForExistence(timeout: 4))
        attach("accessibility-detail", app)
        try app.performAccessibilityAudit()
        XCTAssertTrue(app.staticTexts["喵喵"].exists)
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertGreaterThanOrEqual(back.frame.width, 44)
        XCTAssertGreaterThanOrEqual(back.frame.height, 44)
        for _ in 0..<6 where !app.staticTexts["特性"].isHittable { detail.swipeUp() }
        attach("accessibility-detail-scrolled", app)
        try app.performAccessibilityAudit { issue in
            if let element = issue.element {
                print("SCROLLED-AUDIT type=\(issue.auditType) element=\(element.label) frame=\(element.frame) viewport=\(detail.frame) hittable=\(element.isHittable)")
            }
            return false
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(cell.isHittable)
    }
    @MainActor
    func testDetailBottomAccessibility() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["pet-3001"].tap()
        let detail = app.scrollViews["detail-3001"]
        XCTAssertTrue(detail.waitForExistence(timeout: 4))
        for _ in 0..<6 { detail.swipeUp() }
        attach("accessibility-bottom", app)
        try app.performAccessibilityAudit { issue in
            if let element = issue.element {
                print("BOTTOM-AUDIT type=\(issue.auditType) element=\(element.label) frame=\(element.frame) viewport=\(detail.frame) hittable=\(element.isHittable)")
            }
            return false
        }
    }
    @MainActor
    func testTopMiddleBottomAndRepeat() {
        let app = XCUIApplication()
        app.launch()
        for id in [3001, 3015, 3785] {
            let cell = app.buttons["pet-\(id)"]
            for _ in 0..<18 where !cell.isHittable { app.swipeUp() }
            XCTAssertTrue(cell.isHittable)
            let before = cell.frame
            cell.tap()
            XCTAssertTrue(app.scrollViews["detail-\(id)"].waitForExistence(timeout: 4))
            attach("detail-\(id)", app)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(cell.waitForExistence(timeout: 4))
            XCTAssertTrue(cell.isHittable)
            XCTAssertEqual(cell.frame.minY, before.minY, accuracy: 2)
            attach("return-\(id)", app)
        }
        for _ in 0..<30 {
            let cell = app.buttons["pet-3585"]
            cell.tap()
            XCTAssertTrue(app.scrollViews["detail-3585"].waitForExistence(timeout: 4))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(cell.waitForExistence(timeout: 4))
            XCTAssertTrue(cell.isHittable)
        }
    }
    @MainActor
    func testHeroInspection() {
        let app = XCUIApplication()
        app.launch()
        let cell = app.buttons["pet-3001"]
        XCTAssertTrue(cell.waitForExistence(timeout: 4))
        attach("grid", app)
        cell.tap()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 4))
        attach("hero", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(cell.waitForExistence(timeout: 4))
        attach("returned", app)
    }
    @MainActor
    func testShortInteractiveCancellation() {
        let app = XCUIApplication()
        app.launch()
        let cell = app.buttons["pet-3001"]
        cell.tap()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 4))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.45))
        let far = app.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: far, withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(app.scrollViews["detail-3001"].exists, "Short low-velocity return must cancel")
        attach("cancelled", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(cell.waitForExistence(timeout: 4))
        cell.tap()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 4))
    }
    @MainActor
    func testAdjustedSwiftUIComposition() {
        let app = XCUIApplication()
        app.launchArguments = ["--swiftui-zoom"]
        app.launch()
        app.buttons["pet-3001"].tap()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 4))
        attach("swiftui-adjusted-hero", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["pet-3001"].waitForExistence(timeout: 4))
    }
    @MainActor
    func testReduceMotionStaticNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--reduce-motion"]
        app.launch()
        app.buttons["pet-3001"].tap()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 4))
        attach("reduce-motion", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["pet-3001"].waitForExistence(timeout: 4))
    }
    @MainActor
    func testScrolledDetailReturnsToSource() {
        let app = XCUIApplication()
        app.launch()
        let cell = app.buttons["pet-3001"]
        let before = cell.frame
        cell.tap()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 4))
        app.scrollViews["detail-3001"].swipeUp()
        attach("detail-scrolled", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(cell.waitForExistence(timeout: 4))
        XCTAssertEqual(cell.frame.minY, before.minY, accuracy: 2)
    }
    @MainActor
    func testSystemReduceMotionNavigation() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["pet-3001"].tap()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 4))
        attach("system-reduce-motion", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["pet-3001"].waitForExistence(timeout: 4))
    }
    @MainActor
    func testMissingPortraitNavigation() {
        let app = XCUIApplication()
        app.launch()
        for id in [3784, 3785] {
            let cell = app.buttons["pet-\(id)"]
            for _ in 0..<18 where !cell.isHittable { app.swipeUp() }
            XCTAssertTrue(cell.isHittable)
            cell.tap()
            XCTAssertTrue(app.scrollViews["detail-\(id)"].waitForExistence(timeout: 4))
            attach("missing-\(id)", app)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(cell.waitForExistence(timeout: 4))
        }
    }
    @MainActor private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
