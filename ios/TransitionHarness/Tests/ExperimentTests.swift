import XCTest

final class ExperimentTests: XCTestCase {
    @MainActor func testAImage() { run("A-image") }
    @MainActor func testAEqual() { run("A-equal") }
    @MainActor func testAClear() { run("A-clear-source") }
    @MainActor func testBParity() { run("B-parity") }
    @MainActor func testBClear() { run("B-clear-hero") }
    @MainActor func testBTransparent() { run("B-explicit-transparent") }
    @MainActor func testBHeroMarker() { run("B-hero-magenta") }
    @MainActor func testBPageMarker() { run("B-page-green") }
    @MainActor func testBNoAlignment() { run("B-no-alignment") }
    @MainActor func testCContainer() { run("C-black-container") }
    @MainActor func testCBlackConfiguration() { run("C-black-source-config") }

    @MainActor private func run(_ variant: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--variant", variant]
        app.launch()
        XCTAssertTrue(app.buttons["open-pet"].waitForExistence(timeout: 5))
        attach(variant + "-grid", app)
        for cycle in 0..<3 {
            app.buttons["open-pet"].tap()
            XCTAssertTrue(app.staticTexts["Transparent PNG · black detail"].waitForExistence(timeout: 5))
            attach(variant + "-detail-\(cycle)", app)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["open-pet"].isHittable)
            XCTAssertFalse(app.staticTexts["Transparent PNG · black detail"].exists)
            attach(variant + "-returned-\(cycle)", app)
        }
        app.buttons["export"].tap()
    }
    @MainActor private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
