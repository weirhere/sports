import XCTest

/// App Store screenshot capture — a sibling of ScreenshotTests, but instead
/// of walking the current week (empty in the offseason) it navigates to a
/// full regular-season Saturday so the shots show the app at its best.
/// Run on the store-required 6.9" device (iPhone 17 Pro Max) and export the
/// attachments from the xcresult with `xcresulttool export attachments`.
final class AppStoreScreenshots: XCTestCase {
    @MainActor
    func testCaptureStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.scoresGrouping", "conference",
                                // Seed follows so the Following section leads
                                // with content (argument-domain array syntax).
                                "-following.teamIds", "(61, 130, 251)"]
        app.launch()

        // In the offseason ESPN's "current" season is the upcoming one —
        // all 0-0 records and TBD kickoffs. Switch to the completed 2025
        // season so every shot shows real scores and a Top 25 section.
        XCTAssertTrue(selectSeason(2025, in: app),
                      "Season menu should switch to 2025")

        // Then walk the week strip to a regular-season Saturday.
        let weekTen = app.buttons["Week 10"]
        // The strip's HStack isn't lazy, so every week button exists in the
        // hierarchy even when scrolled offscreen — find the strip by content.
        let strip = app.scrollViews.containing(.button, identifier: "Week 10").firstMatch
        XCTAssertTrue(strip.waitForExistence(timeout: 15), "Week strip should load")
        XCTAssertTrue(scrollToAndTap(weekTen, in: strip, within: app.windows.firstMatch),
                      "Week 10 should be reachable in the strip")

        // Scores: wait for game rows, expand nothing — Following and Top 25
        // are open by default, which is the hero shot. A completed week's
        // rows carry "Final" in their labels (scheduled rows say " at ").
        let gameLink = app.scrollViews.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@", "final")).firstMatch
        XCTAssertTrue(gameLink.waitForExistence(timeout: 15),
                      "Week 10 should show completed game rows")
        snapshot(app, "01-scores")

        // Game detail off the first visible game.
        gameLink.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        // Let line score / leaders finish loading before the shot.
        _ = app.staticTexts["Total"].waitForExistence(timeout: 8)
        snapshot(app, "02-game-detail")
        app.navigationBars.buttons.firstMatch.tap()

        // Rankings.
        XCTAssertTrue(openRankingsPoll(in: app),
                      "The Top 25 row should push a poll with a ranked #1")
        snapshot(app, "03-rankings")

        // Teams browse.
        XCTAssertTrue(openTab("Teams", in: app, until: app.staticTexts["ACC"]),
                      "Teams browse should load")
        snapshot(app, "04-teams")

        // A team page, via search.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Georgia Bulldogs")
        let row = app.staticTexts["Georgia"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        _ = app.buttons.matching(NSPredicate(
            format: "label IN %@", ["Follow", "Following"])).firstMatch
            .waitForExistence(timeout: 10)
        snapshot(app, "05-team-page")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
