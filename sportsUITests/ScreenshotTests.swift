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
                                "-ui.liveOnly", "NO", "-ui.tightOnly", "NO",
                                "-ui.scoreFilter", ""]
        app.launch()

        // Scores: the day's slate as a stack of accordions — college
        // football's conferences, the NFL's one section, any followed
        // table above them. Which are on screen depends on the day, so the
        // shot waits on whichever is there rather than naming it.
        let anyLeague = app.anyScoresSection
        XCTAssertTrue(anyLeague.waitForExistence(timeout: 20))
        // Expand only when the header says it is shut. It publishes its own
        // state as an accessibility value, so this needs no guessing.
        //
        // The old shape asked a *row* whether it existed the instant the
        // header appeared — before any row is realized — and tapped when it
        // didn't, which toggled an already-open section closed. Accordion
        // expansion persists in UserDefaults, so that collapse outlived the
        // run and every later run on the same simulator started shut: a
        // test that broke itself, then stayed broken.
        if (anyLeague.value as? String) == "collapsed" {
            anyLeague.tap()
        }
        // By identifier, not by prose. "X at Y" is what a row says *before
        // kickoff*; once a game starts it says "Denver 7, Kansas City 14,
        // half" instead. Matching on " at " therefore quietly required the
        // slate to hold a game nobody had played yet, and on a Sunday night
        // in September there is no such game — the walk failed at the first
        // screen for a reason that had nothing to do with screens.
        let gameLink = app.scrollViews.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "scores-game-")).firstMatch
        XCTAssertTrue(gameLink.waitForExistence(timeout: 20),
                      "An expanded section should reveal game rows")
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

        // Leagues. The tab tap follows a navigation pop, so it needs the
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
