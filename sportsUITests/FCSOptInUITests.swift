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
            "-ui.liveOnly", "NO", "-ui.tightOnly", "NO",
            "-ui.followPromptDismissed", "YES",
            // Pin the slate filter: it persists across launches by design
            // (2026-08-29), so without this a suite inherits whatever the
            // last run — or the person using this simulator — left
            // selected, and every row query goes looking in a filtered
            // slate. Safe as an argument-domain override because
            // UIStateStore reads the key once at init; "none" parses to
            // no filter.
            "-ui.scoreFilter", "none",
            "-data.provider", "fixture",
            "-poll.interval", "0.5",
        ]
        app.launch()
        return app
    }

    @MainActor
    func testOptingIntoFCSWidensTheFetch() throws {
        throw XCTSkip("""
            There is no longer anything to opt in with. #79 took the slate \
            filter off Scores on purpose — "Scores' header keeps Live and \
            nothing else" — deleting ScoreFilterChip and ScoreFilterSheet, \
            and the wiring went with the control: `UIStateStore.scoreFilter` \
            is now assigned only from defaults in init and read by no view, \
            while `ScoreFilter.init(token:)` deliberately refuses to restore \
            a saved conference filter rather than narrow the slate with \
            nothing on screen able to clear it. So this test has driven a \
            dead surface since #79 and cannot be repaired by a better query.

            Kept rather than deleted because what it asserts is still E8 \
            scope (b) — FCS games absent from the default slate and present \
            the moment someone asks — and the fixture it leans on (fx-fcs, \
            group 81 only) is still the right instrument. It needs a new \
            opt-in surface to point at, which is a product decision, not a \
            test fix. See BACKLOG E8 and E19.
            """)
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

        // The conference stack came back on 2026-09-06, so the FCS slate
        // arrives as its own section rather than inside a league one.
        // Sections start open; a stored collapse still has to be undone.
        let league = app.scoresSection("Missouri Valley")
        XCTAssertTrue(league.waitForExistence(timeout: 10),
                      "opting into FCS left no Missouri Valley section")
        if league.value as? String == "collapsed" {
            league.tap()
        }

        // And its games are real: `fx-fcs` lives ONLY in the fixture's
        // group-81 payload, so finding it proves the store widened its
        // fetch rather than re-filtering games it already had. That the
        // default slate does NOT carry it is covered by DivisionOptInTests
        // and ScoreboardStoreTests, without a 20-swipe scroll to prove a
        // negative.
        let fcsRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Lima A&M"))
            .firstMatch
        XCTAssertTrue(scrollUntilExists(fcsRow, in: app),
                      "the FCS slate's games never rendered")
    }
}
