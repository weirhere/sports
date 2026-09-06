import XCTest

/// Not a test of behavior — a camera. Walks every screen and attaches a
/// screenshot of each, for design review. Appearance comes from the
/// simulator (`xcrun simctl ui <udid> appearance dark`); run with
/// `-parallel-testing-enabled NO` so the walk runs on the device that
/// got the appearance change (clones don't inherit it), and name the
/// shots via `TEST_RUNNER_SNAPSHOT_PREFIX=dark`.
final class ScreenshotTests: XCTestCase {
    @MainActor
    func testWalkAndSnapshotEveryScreen() throws {
        let prefix = ProcessInfo.processInfo.environment["SNAPSHOT_PREFIX"] ?? "shot"
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.liveOnly", "NO",
                                "-ui.scoreFilter", ""]
        app.launch()

        // Scores: the day's slate, one accordion per league. Which leagues
        // are playing depends on the day, so the shot waits on whichever
        // one is there rather than naming it.
        let anyLeague = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
            "College Football,", "NFL,")).firstMatch
        XCTAssertTrue(anyLeague.waitForExistence(timeout: 20))
        let gameLink = app.scrollViews.buttons.matching(NSPredicate(
            format: "label CONTAINS %@", " at ")).firstMatch
        if !gameLink.exists {
            anyLeague.tap()
        }
        XCTAssertTrue(gameLink.waitForExistence(timeout: 10),
                      "An expanded league should reveal game rows")
        snapshot(app, "\(prefix)-scores")

        // The view-options sheet retired on 2026-09-06 — Live and Top 25
        // are header chips and the season rides the day strip, so there is
        // no sheet left to shoot.

        // Game detail off the expanded league section.
        XCTAssertTrue(gameLink.waitForExistence(timeout: 5))
        gameLink.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        snapshot(app, "\(prefix)-game-detail")
        app.navigationBars.buttons.firstMatch.tap()

        // Tables. The tab tap follows a navigation pop, so it needs the
        // retry — see openTab.
        XCTAssertTrue(openRankingsPoll(in: app),
                      "The Top 25 row should push a poll with a ranked #1")
        snapshot(app, "\(prefix)-rankings")

        // Teams: the follow list, then a team page via the search tab.
        XCTAssertTrue(openTab("Teams", in: app, until: app.buttons["Add teams"]),
                      "Teams should load")
        snapshot(app, "\(prefix)-teams")
        XCTAssertTrue(openAddTeamsSheet(in: app),
                      "Teams should offer the Add teams sheet")
        snapshot(app, "\(prefix)-teams-add")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(openTeamPage("Georgia Bulldogs", in: app),
                      "Search should land on the Georgia team page")
        snapshot(app, "\(prefix)-team-page")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
