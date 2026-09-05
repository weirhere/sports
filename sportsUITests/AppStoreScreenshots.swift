import XCTest

/// App Store screenshot capture — a sibling of ScreenshotTests, but aimed at
/// the store rather than design review. It shoots the current week live, so
/// the slate carries the app's whole argument: green live dots and running
/// clocks next to the finals, with the followed teams on top.
///
/// Run on the store devices (iPhone 17 Pro Max for 6.9", 16 Plus for 6.5")
/// with `-parallel-testing-enabled NO`, and export the attachments from the
/// xcresult with `xcresulttool export attachments`. Set the status bar first:
///
///     xcrun simctl status_bar <udid> override --time "9:41" \
///       --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
///
/// Out of season the current week is empty (and Week 1 is a slate of FCS
/// blowouts against preseason 0-0 records) — pass
/// `TEST_RUNNER_SCREENSHOT_SEASON=2025`
/// and `TEST_RUNNER_SCREENSHOT_WEEK="Week 10"` to shoot a completed Saturday.
final class AppStoreScreenshots: XCTestCase {
    @MainActor
    func testCaptureStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.scoresGrouping", "conference",
                                "-ui.liveOnly", "NO",
                                "-ui.scoreFilter", "",
                                // Seed follows so the Following section leads
                                // with content (argument-domain array syntax).
                                "-following.teamIds", "(61, 130, 251)"]
        app.launch()

        let env = ProcessInfo.processInfo.environment
        if let year = env["SCREENSHOT_SEASON"].flatMap(Int.init) {
            XCTAssertTrue(selectSeason(year, in: app),
                          "Season menu should switch to \(year)")
        }
        if let week = env["SCREENSHOT_WEEK"] {
            let chip = app.buttons[week]
            // The strip's HStack isn't lazy, so every week button exists in the
            // hierarchy even when scrolled offscreen — find the strip by content.
            let strip = app.scrollViews.containing(.button, identifier: week).firstMatch
            XCTAssertTrue(strip.waitForExistence(timeout: 15), "Week strip should load")
            XCTAssertTrue(scrollToAndTap(chip, in: strip, within: app.windows.firstMatch),
                          "\(week) should be reachable in the strip")
        }

        // Scores: expand nothing — Following and Top 25 are open by default,
        // which is the hero shot. Wait for a row that has a score on it, so
        // the slate isn't a screen of kickoff times.
        let played = app.scrollViews.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", " left", "final"))
        XCTAssertTrue(played.firstMatch.waitForExistence(timeout: 20),
                      "The week should show games with scores")
        snapshot(app, "01-scores")

        // Game detail, off a completed game where there is one. The live
        // treatment is already the Scores shot's job; what the detail and box
        // score need is a game with a full stat line behind it, and a game in
        // the first quarter has almost nothing to show.
        let final = app.scrollViews.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@", "final")).firstMatch
        let game = final.exists ? final : played.firstMatch
        game.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        // Let line score / leaders finish loading before the shot.
        _ = app.staticTexts["Total"].waitForExistence(timeout: 8)
        snapshot(app, "02-game-detail")

        // Box score — 1.4.0's headline. The tab row is hidden entirely when a
        // game ships no player stats, so this shot is conditional.
        let boxScore = app.buttons["Box score"]
        if boxScore.waitForExistence(timeout: 5) {
            boxScore.tap()
            _ = app.staticTexts["Passing"].waitForExistence(timeout: 8)
            snapshot(app, "03-box-score")
        } else {
            XCTFail("No box score on \(game.label) — reshoot against a game with player stats")
        }
        app.navigationBars.buttons.firstMatch.tap()

        // Rankings.
        XCTAssertTrue(openRankingsPoll(in: app),
                      "The Top 25 row should push a poll with a ranked #1")
        snapshot(app, "04-rankings")

        // Teams browse.
        XCTAssertTrue(openTab("Teams", in: app, until: app.staticTexts["ACC"]),
                      "Teams browse should load")
        snapshot(app, "05-teams")

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
        snapshot(app, "06-team-page")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
