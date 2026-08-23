import XCTest

/// Live-network smoke test: every tab renders real data, and following a
/// team from browse makes the Following section appear on Scores.
final class SmokeUITests: XCTestCase {
    @MainActor
    func testTabsAndFollowFlow() throws {
        let app = XCUIApplication()
        // A fresh simulator would otherwise get the pick-your-teams sheet;
        // the arg lands in UserDefaults' argument domain and marks it seen.
        // Grouping is pinned to conference the same way — the test asserts
        // conference headers, and the sim may have "by date" persisted.
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.scoresGrouping", "conference"]
        app.launch()

        // Scores loads a real slate. A followed conference can push SEC
        // screens below the fold, so be willing to scroll for it.
        XCTAssertTrue(scrollUntilExists(app.staticTexts["SEC"], in: app),
                      "Scores should show the SEC section header")

        // Grouping toggle: by date swaps conference sections for day
        // sections; toggling back restores the conference stack. The chip
        // lives in the fixed header, so it stays hittable after scrolling.
        let groupingChip = app.buttons["Group games by date"]
        XCTAssertTrue(groupingChip.waitForExistence(timeout: 5),
                      "The By date chip should be in the header")
        groupingChip.tap()
        let dayHeader = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@", "(Mon|Tues|Wednes|Thurs|Fri|Satur|Sun)day.*")).firstMatch
        XCTAssertTrue(scrollUntilExists(dayHeader, in: app, timeout: 5),
                      "Date grouping should show a day section header")
        snapshot(app, "scores-by-date")
        groupingChip.tap()
        XCTAssertTrue(scrollUntilExists(app.staticTexts["SEC"], in: app, timeout: 5),
                      "Toggling back should restore conference sections")

        // Rankings leads with the Top 25 row; the poll itself is one tap
        // down. Which poll depends on the calendar — the AP preseason Top
        // 25 doesn't drop until mid-August.
        XCTAssertTrue(openRankingsPoll(in: app),
                      "The Top 25 row should push a poll with a ranked #1")
        snapshot(app, "rankings")

        // Teams browse + search + follow.
        app.tabBars.buttons["Teams"].tap()
        XCTAssertTrue(app.staticTexts["ACC"].waitForExistence(timeout: 15),
                      "Teams should show the ACC conference header")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Georgia Bulldogs")
        let row = app.staticTexts["Georgia"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Search should surface Georgia")
        row.tap()

        // Team page: follow (tolerate an already-followed state from a
        // previous run — follows persist on the simulator).
        let follow = app.buttons["Follow"].firstMatch
        if follow.waitForExistence(timeout: 10) {
            follow.tap()
        }
        XCTAssertTrue(app.buttons["Following"].firstMatch.waitForExistence(timeout: 5),
                      "Follow should flip to Following")
        snapshot(app, "team-page")

        // Scores now leads with the Following section — but the list kept
        // its scroll position from the SEC hunt above, and on a full slate
        // Following sits screens higher, outside the LazyVStack's realized
        // range. Scroll back up to it.
        app.tabBars.buttons["Scores"].tap()
        XCTAssertTrue(scrollUntilExists(app.staticTexts["Following"], in: app,
                                        revealing: .above, timeout: 10),
                      "Following section should appear once a team is followed")
        snapshot(app, "scores-following")

        // Into a game detail from the (already expanded) Following section.
        let gameLink = app.buttons.containing(.staticText, identifier: "Georgia").firstMatch
        XCTAssertTrue(gameLink.waitForExistence(timeout: 5), "Following should list a Georgia game row")
        gameLink.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10),
                      "Tapping a game row should push the game detail")
        snapshot(app, "game-detail")

        // Header team column pushes the team page. Asserting on the Following
        // pill (Georgia was followed above), not the schedule — the schedule
        // section is calendar-dependent.
        let teamButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Georgia")).firstMatch
        XCTAssertTrue(teamButton.waitForExistence(timeout: 10),
                      "Game detail header should have a Georgia team button")
        teamButton.tap()
        XCTAssertTrue(app.buttons["Following"].firstMatch.waitForExistence(timeout: 10),
                      "Team header tap should push the team page")
        snapshot(app, "team-page-from-game")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
