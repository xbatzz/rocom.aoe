import XCTest
import UIKit

final class NavigationTests: XCTestCase {
    @MainActor
    func testEncyclopediaHostedThumbnails() {
        let app = XCUIApplication()
        app.launchArguments = ["--visual-review", "grid", "--reduce-motion"]
        app.launch()
        let pet = app.buttons["pet-3001"]
        XCTAssertTrue(pet.waitForExistence(timeout: 8)); pet.tap()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.images.matching(NSPredicate(format: "label CONTAINS '缺少缩略图缓存'")).firstMatch.exists)
        app.segmentedControls["pet-detail-tabs"].buttons["技能"].tap()
        XCTAssertTrue(app.segmentedControls["pet-skill-tabs"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.images.matching(NSPredicate(format: "label CONTAINS '缺少缩略图缓存'")).firstMatch.exists)
        attach("encyclopedia-hosted-thumbnails", app)
    }

    @MainActor
    func testGrassRecordsStayLiveAcrossLocationAndModeChanges() {
        let app = XCUIApplication()
        app.launchArguments = ["--visual-review", "grass", "--visual-fixture", "--grass-performance-fixture", "--reduce-motion"]
        app.launch()
        let progress = app.progressIndicators["当前地点目标"]
        XCTAssertTrue(progress.waitForExistence(timeout: 8))
        XCTAssertEqual(progress.value as? String, "601 / 210")
        let status = app.buttons["grass-status-pet:3001"].firstMatch
        for _ in 0..<5 where !status.isHittable { app.swipeUp() }
        XCTAssertTrue(status.isHittable)
        status.tap(); app.buttons["未点亮"].firstMatch.tap()
        for _ in 0..<5 where !app.buttons["grass-location"].isHittable { app.swipeDown() }
        XCTAssertEqual(progress.value as? String, "600 / 210", "Edits must invalidate the location snapshot")
        app.buttons["grass-location"].tap()
        app.buttons["记忆中的普拉塔草原"].firstMatch.tap()
        XCTAssertEqual(progress.value as? String, "0 / 199", "Locations must keep independent records")
        app.buttons["grass-location"].tap()
        app.buttons["记忆中的索米亚草原"].firstMatch.tap()
        XCTAssertEqual(progress.value as? String, "600 / 210")
        app.segmentedControls.buttons["家族奖牌"].tap()
        let medals = app.progressIndicators["家族奖牌"]
        XCTAssertTrue(medals.waitForExistence(timeout: 3))
        XCTAssertEqual(medals.value as? String, "0 / 192", "Footprints must not imply family medals")
        app.segmentedControls.buttons["地点足迹"].tap()
        XCTAssertEqual(progress.value as? String, "600 / 210")
        attach("grass-records-performance", app)
    }

    @MainActor
    func testPaginationInLargeSkillAndPetResults() {
        let app = XCUIApplication()
        for route in ["pet-many-skills", "skill-many-pets", "advanced", "team-many-skills"] {
            app.launchArguments = ["--visual-review", route, "--reduce-motion"]
            app.launch()
            if route == "pet-many-skills" {
                let tabs = app.segmentedControls["pet-detail-tabs"]
                XCTAssertTrue(tabs.waitForExistence(timeout: 8)); tabs.buttons["技能"].tap()
                app.segmentedControls["pet-skill-tabs"].buttons["技能石"].tap()
            } else if route == "skill-many-pets" {
                let tabs = app.segmentedControls["skill-detail-tabs"]
                XCTAssertTrue(tabs.waitForExistence(timeout: 8)); tabs.buttons["获得方式"].tap()
            } else if route == "team-many-skills" {
                XCTAssertTrue(app.navigationBars["队伍编辑"].waitForExistence(timeout: 8))
                app.buttons.matching(NSPredicate(format: "label CONTAINS '学院呱呱'")).firstMatch.tap()
                XCTAssertTrue(app.navigationBars["槽位草稿"].waitForExistence(timeout: 3))
                app.buttons["选择精灵"].firstMatch.tap()
                let pickerNext = app.buttons["pagination-next"].firstMatch
                XCTAssertTrue(pickerNext.waitForExistence(timeout: 3)); pickerNext.tap()
                XCTAssertTrue(app.staticTexts["pagination-range"].firstMatch.label.hasPrefix("第 25–"))
                app.navigationBars.buttons.element(boundBy: 0).tap()
            } else {
                XCTAssertTrue(app.navigationBars["高级筛选"].waitForExistence(timeout: 8))
            }
            let next = app.buttons["pagination-next"].firstMatch
            // Form rows below the initial viewport enter the accessibility tree lazily.
            for _ in 0..<14 where !next.exists || !next.isHittable { app.swipeUp() }
            XCTAssertTrue(next.waitForExistence(timeout: 3), route)
            XCTAssertTrue(next.isHittable, route); next.tap()
            XCTAssertTrue(app.staticTexts["pagination-range"].firstMatch.label.hasPrefix("第 25–"), route)
            XCTAssertTrue(next.isHittable, "\(route) must scroll back to the first row")
            app.buttons["pagination-previous"].firstMatch.tap()
            XCTAssertTrue(app.staticTexts["pagination-range"].firstMatch.label.hasPrefix("第 1–"), route)
            XCTAssertFalse(app.buttons["pagination-previous"].firstMatch.isEnabled, route)
            attach("pagination-large-\(route)", app)
            app.terminate()
        }
    }

    @MainActor
    func testCatalogPaginationAndSearchReset() {
        let app = XCUIApplication()
        for route in ["skills", "hero", "grass", "shiny"] {
            app.launchArguments = ["--visual-review", route, "--visual-fixture", "--reduce-motion"]
            app.launch()
            if route == "shiny" {
                // The current season has 19 slots; all seasons exercise multiple pages.
                let season = app.buttons["shiny-season"]
                XCTAssertTrue(season.waitForExistence(timeout: 8)); season.tap()
                app.buttons["全部赛季"].firstMatch.tap()
            }
            let next = app.buttons["pagination-next"].firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 8), route)
            for _ in 0..<6 where !next.isHittable { app.swipeUp() }
            XCTAssertTrue(next.isHittable, route)
            next.tap()
            let range = app.staticTexts["pagination-range"].firstMatch
            XCTAssertTrue(range.label.hasPrefix("第 25–"), "\(route): \(range.label)")
            XCTAssertTrue(next.isHittable, "Page changes must return to the list controls")
            app.buttons["pagination-previous"].firstMatch.tap()
            XCTAssertTrue(range.label.hasPrefix("第 1–"), route)
            next.tap()
            let search = app.searchFields.firstMatch
            for _ in 0..<8 where !search.isHittable { app.swipeDown() }
            XCTAssertTrue(search.isHittable, route)
            search.tap(); search.typeText("不存在的精灵技能")
            XCTAssertFalse(app.buttons["pagination-next"].firstMatch.exists, "Empty searches must not retain a stale page")
            let clear = search.buttons.firstMatch
            XCTAssertTrue(clear.exists)
            clear.tap()
            XCTAssertTrue(range.waitForExistence(timeout: 3))
            XCTAssertTrue(range.label.hasPrefix("第 1–"), "Clearing the search resets to page 1: \(route)")
            if route == "hero" {
                // A direct jump exercises the final boundary and disabled next control.
                search.typeText("\n")
                let menu = app.buttons["pagination-page"].firstMatch
                for _ in 0..<5 where !menu.isHittable { app.swipeUp() }
                menu.tap(); app.buttons["第 8 / 8 页"].firstMatch.tap()
                XCTAssertTrue(range.label.hasPrefix("第 169–192"))
                XCTAssertFalse(app.buttons["pagination-next"].firstMatch.isEnabled)
                menu.tap(); app.buttons["第 1 / 8 页"].firstMatch.tap()
            }
            attach("pagination-\(route)", app)
            app.terminate()
        }
    }

    @MainActor
    func testCollectionEntryPortraitAndWhitespaceNavigation() {
        let app = XCUIApplication(); app.launchArguments = ["--visual-review", "home"]
        app.launch()
        XCTAssertTrue(app.navigationBars["洛克工具"].waitForExistence(timeout: 8))
        for (identifier, title) in [("home-shiny", "异色收集"), ("home-grass", "草系徽章"), ("home-hero", "命定勇者")] {
            for (x, y) in [(0.08, 0.5), (0.60, 0.84), (0.88, 0.5)] {
                let entry = app.buttons[identifier].firstMatch
                for _ in 0..<5 where !entry.isHittable || entry.frame.maxY > app.frame.maxY - 45 { app.swipeUp() }
                XCTAssertTrue(entry.isHittable, title)
                entry.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
                XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 3), "\(title) should open from x=\(x)")
                app.navigationBars.buttons.element(boundBy: 0).tap()
                XCTAssertTrue(app.navigationBars["洛克工具"].waitForExistence(timeout: 3))
            }
        }
        attach("collection-entry-hit-targets", app)
    }

    @MainActor
    func testPaginatedEncyclopediaReturnAndLargeText() {
        let app = XCUIApplication(); app.launchArguments = ["--visual-review", "grid", "--reduce-motion"]
        app.launch()
        let next = app.buttons["pagination-next"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        for _ in 0..<5 where !next.isHittable { app.swipeUp() }
        next.tap()
        let cell = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'pet-'")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 3)); cell.tap()
        XCTAssertTrue(app.scrollViews.matching(NSPredicate(format: "identifier BEGINSWITH 'detail-'")).firstMatch.waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["pagination-range"].firstMatch.label.hasPrefix("第 25–"))
        attach("pagination-grid-return", app)
        app.terminate()
        app.launchArguments = ["--visual-review", "hero", "--reduce-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        for _ in 0..<8 where !next.isHittable { app.swipeUp() }
        XCTAssertTrue(next.isHittable); next.tap()
        XCTAssertTrue(app.staticTexts["pagination-range"].firstMatch.label.hasPrefix("第 25–"))
        XCTAssertTrue(next.isHittable)
        attach("pagination-accessibility-text", app)
    }

    @MainActor
    func testSavedDarkAppearanceReachesRoot() throws {
        let app = XCUIApplication(); app.launchArguments = ["--visual-review", "version", "--visual-fixture"]
        app.launch()
        XCTAssertTrue(app.navigationBars["数据版本"].waitForExistence(timeout: 8))
        app.buttons.matching(NSPredicate(format: "label CONTAINS '跟随系统'")).firstMatch.tap()
        app.buttons["深色"].firstMatch.tap()
        let screenshot = app.screenshot()
        let cg = try XCTUnwrap(UIImage(data: screenshot.pngRepresentation)?.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cg, in: CGRect(x: -CGFloat(cg.width) * 0.025, y: -CGFloat(cg.height) * 0.4, width: CGFloat(cg.width), height: CGFloat(cg.height)))
        }
        XCTAssertLessThan(pixel[0], 80); XCTAssertLessThan(pixel[1], 80); XCTAssertLessThan(pixel[2], 80)
        attach("selected-dark-root", app)
    }

    @MainActor
    func testSelectedParityScreensAndLargeTextControls() {
        let app = XCUIApplication()
        let pages: [(String, String)] = [("advanced", "高级筛选"), ("skill", ""), ("types-coverage", "属性克制"), ("grass", "草系徽章"), ("shiny", "异色收集"), ("pvp-filled", "PVP 助手"), ("version", "数据版本")]
        for (route, title) in pages {
            app.launchArguments = ["--visual-review", route, "--visual-fixture", "--reduce-motion"]
            if route == "advanced" || route == "version" { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
            app.launch()
            if !title.isEmpty { XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8)) }
            else {
                XCTAssertTrue(app.segmentedControls["skill-detail-tabs"].waitForExistence(timeout: 8))
                app.segmentedControls["skill-detail-tabs"].buttons["获得方式"].tap()
                XCTAssertTrue(app.staticTexts["筛选获得关系"].waitForExistence(timeout: 8))
            }
            if route == "grass" {
                app.buttons["家族奖牌"].firstMatch.tap()
                XCTAssertTrue(app.staticTexts["家族奖牌单独保存，与地点足迹、命定勇者分别统计。"].waitForExistence(timeout: 3))
            }
            if route == "version" {
                let theme = app.buttons.matching(NSPredicate(format: "label CONTAINS '跟随系统'")).firstMatch
                XCTAssertTrue(theme.isHittable); theme.tap()
                app.buttons["深色"].firstMatch.tap()
            }
            attach("selected-\(route)", app); app.terminate()
        }
    }

    @MainActor
    func testSelectedParityDetailAndDraftProtection() {
        let app = XCUIApplication(); app.launchArguments = ["--visual-review", "pet"]
        app.launch()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 8))
        app.segmentedControls["pet-detail-tabs"].buttons["进化"].tap()
        let related = app.staticTexts["喵呜"].firstMatch
        for _ in 0..<8 where !related.isHittable { app.swipeUp() }
        XCTAssertTrue(related.isHittable); related.tap()
        XCTAssertTrue(app.scrollViews["detail-3025"].waitForExistence(timeout: 4))
        attach("selected-related-pet", app)
        app.terminate(); app.launchArguments = ["--visual-review", "team-draft"]; app.launch()
        XCTAssertTrue(app.navigationBars["队伍编辑"].waitForExistence(timeout: 8))
        let name = app.textFields["队伍名称"].firstMatch; name.tap(); name.typeText("测试草稿")
        app.buttons["取消"].firstMatch.tap()
        XCTAssertTrue(app.buttons["继续编辑"].waitForExistence(timeout: 3)); app.buttons["继续编辑"].tap()
        XCTAssertTrue(name.exists)
        attach("selected-team-draft-protection", app)
    }

    @MainActor
    func testPetDetailQuickSectionsAndSkillFilters() {
        let app = XCUIApplication(); app.launchArguments = ["--visual-review", "pet"]
        app.launch()
        let detail = app.scrollViews["detail-3001"]
        XCTAssertTrue(detail.waitForExistence(timeout: 8))
        let tabs = app.segmentedControls["pet-detail-tabs"]
        tabs.buttons["技能"].tap()
        XCTAssertTrue(app.staticTexts["筛选自有与学习技能"].waitForExistence(timeout: 3))
        app.staticTexts["筛选自有与学习技能"].tap()
        let keyword = app.textFields["技能名称或描述"]
        XCTAssertTrue(keyword.isHittable); keyword.tap(); keyword.typeText("不存在的技能")
        XCTAssertTrue(app.staticTexts["没有符合筛选条件的技能"].waitForExistence(timeout: 3))
        tabs.buttons["介绍"].tap()
        XCTAssertTrue(app.staticTexts["精灵资料"].waitForExistence(timeout: 3))
        XCTAssertLessThan(app.staticTexts["精灵资料"].frame.minY, tabs.frame.maxY + 80, "Short sections should open immediately below the fixed tabs")
        attach("quick-pet-profile", app)
        tabs.buttons["技能"].tap()
        // Reopen the filter if its transient disclosure state was reset.
        if !keyword.isHittable { app.staticTexts["筛选自有与学习技能"].tap() }
        XCTAssertEqual(keyword.value as? String, "不存在的技能")
        app.buttons["重置筛选"].tap()
        detail.swipeUp(); detail.swipeUp()
        XCTAssertTrue(tabs.buttons["介绍"].isHittable, "Section controls must remain reachable after scrolling")
        let sources = app.segmentedControls["pet-skill-tabs"]
        sources.buttons["血脉技能"].tap()
        XCTAssertFalse(keyword.exists)
        sources.buttons["技能石"].tap()
        sources.buttons["技能池"].tap()
        attach("quick-pet-skills", app)
        tabs.buttons["进化"].tap()
        XCTAssertTrue(app.staticTexts["喵呜"].firstMatch.isHittable)
        attach("quick-pet-evolution", app)
        tabs.buttons["概览"].tap()
        XCTAssertTrue(app.staticTexts["喵喵"].isHittable)
        attach("quick-pet-overview", app)
    }

    @MainActor
    func testPVPQuickSectionsAndPreparation() {
        let app = XCUIApplication(); app.launchArguments = ["--visual-review", "pvp-filled"]
        app.launch()
        let tabs = app.segmentedControls["pvp-tabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 8))
        for _ in 0..<2 {
            tabs.buttons["能力比较"].tap()
            XCTAssertTrue(app.staticTexts["速度比较"].isHittable)
            app.swipeUp()
            tabs.buttons["对战分析"].tap()
            XCTAssertTrue(app.staticTexts["我方 → 对方"].isHittable)
            tabs.buttons["双方构筑"].tap()
            XCTAssertTrue(app.staticTexts["对战构筑"].isHittable)
        }
        tabs.buttons["对战分析"].tap()
        attach("quick-pvp-analysis", app)
        app.staticTexts["我方 → 对方"].tap()
        XCTAssertTrue(app.segmentedControls["damage-tabs"].waitForExistence(timeout: 3))
        app.segmentedControls["damage-tabs"].buttons["一击线"].tap()
        XCTAssertTrue(app.staticTexts["基础纸面一击威力线 · 目标生命 100%"].isHittable)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(tabs.buttons["对战分析"].isSelected)
        app.terminate(); app.launchArguments = ["--visual-review", "pvp"]; app.launch()
        XCTAssertTrue(tabs.waitForExistence(timeout: 8))
        tabs.buttons["对战分析"].tap()
        XCTAssertTrue(app.buttons["选择双方精灵"].isHittable)
        app.buttons["选择双方精灵"].tap()
        XCTAssertTrue(tabs.buttons["双方构筑"].isSelected)
    }

    @MainActor
    func testDamageQuickSectionsRetainSelection() {
        let app = XCUIApplication(); app.launchArguments = ["--visual-review", "damage", "--reduce-motion"]
        app.launch()
        let tabs = app.segmentedControls["damage-tabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 8))
        let chosenSkill = app.buttons["选择固定威力攻击技能"].value as? String
        XCTAssertNotNil(chosenSkill)
        XCTAssertTrue(app.staticTexts["纸面伤害"].exists)
        app.swipeUp()
        tabs.buttons["属性关系"].tap()
        XCTAssertTrue(app.staticTexts["攻击方技能属性 → 防守方承伤"].isHittable)
        attach("quick-damage-types", app)
        tabs.buttons["一击线"].tap()
        XCTAssertTrue(app.staticTexts["基础纸面一击威力线 · 目标生命 100%"].isHittable)
        attach("quick-damage-one-hit", app)
        tabs.buttons["伤害计算"].tap()
        XCTAssertEqual(app.buttons["选择固定威力攻击技能"].value as? String, chosenSkill)
        XCTAssertTrue(app.buttons["选择固定威力攻击技能"].isHittable)
        XCTAssertTrue(app.staticTexts["纸面伤害"].exists)
        attach("quick-damage-result", app)
    }

    @MainActor
    func testQuickSectionsWithAccessibilityText() {
        let app = XCUIApplication()
        app.launchArguments = ["--visual-review", "pet", "--reduce-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.scrollViews["detail-3001"].waitForExistence(timeout: 8))
        let menu = app.buttons.matching(NSPredicate(format: "label CONTAINS '概览'")).firstMatch
        XCTAssertTrue(menu.isHittable); menu.tap()
        app.buttons["介绍"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["精灵资料"].isHittable)
        attach("quick-pet-accessibility-profile", app)
        let profileMenu = app.buttons.matching(NSPredicate(format: "label CONTAINS '介绍'")).firstMatch
        profileMenu.tap(); app.buttons["技能"].firstMatch.tap()
        let sourceMenu = app.buttons.matching(NSPredicate(format: "label CONTAINS '技能池'")).firstMatch
        XCTAssertTrue(sourceMenu.isHittable); sourceMenu.tap()
        app.buttons["血脉技能"].firstMatch.tap()
        attach("quick-pet-accessibility-bloodline", app)
    }

    @MainActor
    func testSkillDetailSectionsRetainAcquisitionFilters() {
        let app = XCUIApplication(); app.launchArguments = ["--visual-review", "skill"]
        app.launch()
        let tabs = app.segmentedControls["skill-detail-tabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 8))
        tabs.buttons["获得方式"].tap()
        app.staticTexts["筛选获得关系"].tap()
        let keyword = app.textFields["成员名称、图鉴编号或配置 ID"]
        keyword.tap(); keyword.typeText("不存在的成员")
        XCTAssertTrue(app.staticTexts["没有符合条件的获得关系"].exists)
        tabs.buttons["技能资料"].tap()
        XCTAssertTrue(app.staticTexts["技能效果"].isHittable)
        attach("quick-skill-detail", app)
        tabs.buttons["获得方式"].tap()
        app.staticTexts["筛选获得关系"].tap()
        XCTAssertEqual(keyword.value as? String, "不存在的成员")
        attach("quick-skill-acquisition-filter", app)
    }

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
        app.launchArguments = ["--visual-review", "grid"]
        app.launch()
        let cell = app.buttons["pet-3001"]
        XCTAssertTrue(cell.waitForExistence(timeout: 8))
        // The full catalog can start with this pet below the viewport. Capture
        // the source position after bringing it onscreen, before XCTest's tap.
        for _ in 0..<8 where !cell.isHittable { app.swipeUp() }
        XCTAssertTrue(cell.isHittable)
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
