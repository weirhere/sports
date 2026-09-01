import XCTest

/// A conference page's Games tab fetches its season slate exactly once per
/// (conference, year) and never polls — right for a page that is mostly
/// history, wrong for the three hours a week it isn't. Without a merge
/// against the polling scoreboard, a game that is live when the page opens
/// freezes at whatever score it held then. TeamPage's schedule had the same
/// bug and was fixed alone (Andy, 2026-08-29); this is the sibling.
///
/// Runs against `FixtureScoresClient`, whose `fx-hold` (SEC) is live
/// forever and moves its score every third fetch — so a frozen slate and a
/// merged one are trivially distinguishable in a few seconds.
final class ConferenceLiveMergeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testConferenceGamesTrackTheLiveScoreboard() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui.onboardingSeen", "YES",
            "-ui.liveOnly", "NO",
            "-ui.followPromptDismissed", "YES",
            "-ui.scoresGrouping", "conference",
            "-data.provider", "fixture",
            "-poll.interval", "0.5",
        ]
        app.launch()

        // The accordion header's conference name is its own button (Andy,
        // 2026-08-25) and pushes the conference page.
        let sec = app.buttons["SEC standings"]
        XCTAssertTrue(scrollUntilExists(sec, in: app), "SEC section never appeared")
        sec.tap()

        let games = app.buttons["Games"]
        XCTAssertTrue(games.waitForExistence(timeout: 10), "conference page never presented")
        games.tap()

        // The live fixture game's row, matched on the away team's name —
        // the rest of the label is the score, which is the point.
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Alpha State"))
            .firstMatch
        XCTAssertTrue(scrollUntilExists(row, in: app),
                      "the live game never appeared on the conference page")

        let before = row.label
        // fx-hold moves its score every third fetch; at a 0.5s poll that is
        // ~1.5s, so this covers several changes even if a fetch is dropped.
        Thread.sleep(forTimeInterval: 8)
        let after = row.label
        XCTAssertNotEqual(before, after,
                          "the conference slate froze — it is not merging the live scoreboard")
    }
}
