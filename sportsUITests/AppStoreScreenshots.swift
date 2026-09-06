import XCTest

/// App Store screenshot capture — a sibling of ScreenshotTests, but aimed at
/// the store rather than design review. It shoots the current day live, so
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
/// Out of season today is empty — pass `TEST_RUNNER_SCREENSHOT_SEASON=2025`
/// and `TEST_RUNNER_SCREENSHOT_DAY="Saturday, November 8"` (the day chip's
/// spoken label) to shoot a completed Saturday.
final class AppStoreScreenshots: XCTestCase {
    @MainActor
    func testCaptureStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.liveOnly", "NO",
                                "-ui.scoreFilter", "",
                                // Seed follows so the Following section leads
                                // with content (argument-domain array syntax).
                                // League-qualified since the namespacing
                                // migration — a bare id reads as nobody.
                                "-following.teamKeys",
                                "(cfb:61, cfb:130, cfb:251)"]
        app.launch()

        let env = ProcessInfo.processInfo.environment
        if let year = env["SCREENSHOT_SEASON"].flatMap(Int.init) {
            XCTAssertTrue(selectSeason(year, in: app),
                          "Season menu should switch to \(year)")
        }
        if let day = env["SCREENSHOT_DAY"] {
            // Chips are addressed by their spoken label ("Saturday,
            // November 8"); the strip's HStack isn't lazy, so every day
            // button exists in the hierarchy even scrolled offscreen.
            let chip = app.buttons[day]
            let strip = app.scrollViews.containing(.button, identifier: day).firstMatch
            XCTAssertTrue(strip.waitForExistence(timeout: 15), "Day strip should load")
            XCTAssertTrue(scrollToAndTap(chip, in: strip, within: app.windows.firstMatch),
                          "\(day) should be reachable in the strip")
        }

        // Scores: expand nothing — Following and the league accordions are
        // open by default, which is the hero shot. Wait for a row that has
        // a score on it, so the slate isn't a screen of kickoff times.
        let played = app.scrollViews.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", " left", "final"))
        XCTAssertTrue(played.firstMatch.waitForExistence(timeout: 20),
                      "The day should show games with scores")
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

        // Tables.
        XCTAssertTrue(openRankingsPoll(in: app),
                      "The Top 25 row should push a poll with a ranked #1")
        snapshot(app, "04-rankings")

        // Teams: the seeded follows, one card each.
        XCTAssertTrue(openTab("Teams", in: app, until: app.buttons["Add teams"]),
                      "Teams should load")
        snapshot(app, "05-teams")

        // A team page, via the app-wide search tab.
        XCTAssertTrue(openTeamPage("Georgia Bulldogs", in: app),
                      "Search should land on the Georgia team page")
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
