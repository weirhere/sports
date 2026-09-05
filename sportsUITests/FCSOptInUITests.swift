import XCTest

/// E8 scope (b) end to end: FCS games are absent from the default slate
/// and present the moment someone asks for them. The fixture's `fx-fcs`
/// (Lima A&M at Mike College, Missouri Valley) exists only in the group-81
/// payload, so it can't appear unless the opt-in actually widened the
/// fetch — no amount of client-side filtering would conjure it.
final class FCSOptInUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchFixtureApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui.onboardingSeen", "YES",
            "-ui.liveOnly", "NO",
            "-ui.followPromptDismissed", "YES",
            // Pin the slate filter: it persists across launches by design
            // (2026-08-29), so without this a suite inherits whatever the
            // last run — or the person using this simulator — left
            // selected, and every row query goes looking in a filtered
            // slate. Safe as an argument-domain override because
            // UIStateStore reads the key once at init; "none" parses to
            // no filter.
            "-ui.scoreFilter", "none",
            "-ui.league", "cfb",
            "-ui.scoresGrouping", "conference",
            "-data.provider", "fixture",
            "-poll.interval", "0.5",
        ]
        app.launch()
        return app
    }

    @MainActor
    func testOptingIntoFCSWidensTheFetch() throws {
        let app = launchFixtureApp()

        let funnel = app.buttons["Filter games"]
        XCTAssertTrue(funnel.waitForExistence(timeout: 10), "filter chip missing")
        funnel.tap()

        // The FCS section sits below all 11 FBS conferences, so the sheet
        // has to be scrolled before the row is realized.
        let choice = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Missouri Valley"))
            .firstMatch
        XCTAssertTrue(scrollUntilExists(choice, in: app),
                      "the sheet never offered an FCS conference")
        choice.tap()

        // The selection landed and the sheet dismissed: the chip names it.
        XCTAssertTrue(app.buttons["Filtered to Missouri Valley"].waitForExistence(timeout: 10),
                      "the FCS conference was never actually selected")

        // The section exists at all — conference accordions start
        // collapsed on Scores (only Following and Top 25 open by default),
        // so this header, whose label carries the game count, is the first
        // proof the slate widened.
        let section = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@",
                                  "Missouri Valley", "game"))
            .firstMatch
        XCTAssertTrue(scrollUntilExists(section, in: app),
                      "opting into FCS produced no section for it")
        section.tap()

        // And its games are real: `fx-fcs` lives ONLY in the fixture's
        // group-81 payload, so finding it proves the store widened its
        // fetch rather than re-filtering games it already had. That the
        // default slate does NOT carry it is covered by DivisionOptInTests
        // and ScoreboardStoreTests, without a 20-swipe scroll to prove a
        // negative — which also left the header scrolled off screen.
        let fcsRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Lima A&M"))
            .firstMatch
        XCTAssertTrue(scrollUntilExists(fcsRow, in: app),
                      "the FCS section's games never rendered")
    }
}
