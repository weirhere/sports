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
                                "-ui.scoresGrouping", "conference",
                                "-ui.liveOnly", "NO",
                                "-ui.scoreFilter", "",
                                // The cold-launch auto-pick opens on
                                // whichever league is live, so every
                                // live-ESPN suite pins one or it drifts.
                                "-ui.league", "cfb"]
        app.launch()

        // Scores, conference grouping — expand SEC so rows are visible.
        let sec = app.staticTexts["SEC"]
        XCTAssertTrue(sec.waitForExistence(timeout: 15))
        let gameLink = app.scrollViews.buttons.matching(NSPredicate(
            format: "label CONTAINS %@", " at ")).firstMatch
        if !gameLink.exists {
            sec.tap()
        }
        XCTAssertTrue(gameLink.waitForExistence(timeout: 5),
                      "Expanding SEC should reveal game rows")
        snapshot(app, "\(prefix)-scores-conference")

        // Scores, date grouping — the toggle lives in the filter sheet.
        XCTAssertTrue(setScoresGrouping(byDate: true, in: app))
        _ = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@", "(Mon|Tues|Wednes|Thurs|Fri|Satur|Sun)day.*"))
            .firstMatch.waitForExistence(timeout: 5)
        snapshot(app, "\(prefix)-scores-by-date")
        XCTAssertTrue(setScoresGrouping(byDate: false, in: app))

        // Game detail off the expanded SEC section.
        XCTAssertTrue(gameLink.waitForExistence(timeout: 5))
        gameLink.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        snapshot(app, "\(prefix)-game-detail")
        app.navigationBars.buttons.firstMatch.tap()

        // Rankings. The tab tap follows a navigation pop, so it needs the
        // retry — see openTab.
        XCTAssertTrue(openRankingsPoll(in: app),
                      "The Top 25 row should push a poll with a ranked #1")
        snapshot(app, "\(prefix)-rankings")

        // Teams browse, then a team page via search.
        XCTAssertTrue(openTab("Teams", in: app, until: app.staticTexts["ACC"]),
                      "Teams browse should load")
        snapshot(app, "\(prefix)-teams")
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
