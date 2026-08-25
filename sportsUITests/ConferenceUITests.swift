import XCTest

/// Live-network walk of the conference standings flow: the Teams header's
/// context menu pushes ConferencePage (the trailing standings icon came
/// off browse headers in the P1 review), the follow pill toggles, and the
/// Scores headers keep their standings button.
///
/// Live-data rules apply (see CLAUDE.md): standings are a calendar fact —
/// preseason serves 0-0 rows and an offseason conference can be empty — so
/// the page assertion accepts either real rows or "Standings TBA", and
/// never a specific team, record, or row count.
final class ConferenceUITests: XCTestCase {
    @MainActor
    func testStandingsPageAndConferenceFollow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.scoresGrouping", "conference"]
        app.launch()

        // Teams tab: the first conference group's header reaches standings
        // through its context menu. ACC, not SEC — the browse list is a
        // LazyVStack, so a section below the fold doesn't exist as an
        // element yet, and ACC sorts first under tier-then-name (the
        // existing smoke test leans on it the same way).
        XCTAssertTrue(openTab("Teams", in: app, until: app.staticTexts["ACC"]),
                      "Teams should show the ACC conference header")
        let accHeader = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@", "ACC,")).firstMatch
        XCTAssertTrue(accHeader.waitForExistence(timeout: 5),
                      "The ACC header toggle should exist")
        accHeader.press(forDuration: 1.0)
        let standingsItem = app.buttons["View ACC standings"].firstMatch
        XCTAssertTrue(standingsItem.waitForExistence(timeout: 5),
                      "The ACC header's context menu should offer standings")
        standingsItem.tap()

        // ConferencePage: hero, follow pill, and standings-or-TBA. The name
        // lives in the hero (TeamPage template), so the pill marks the
        // page. Rows collapse to one element (a button, via
        // NavigationLink), so query any descendant by label like
        // UITestSupport's topRankedRow does.
        let conferencePill = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@",
            "Follow conference", "Following conference")).firstMatch
        XCTAssertTrue(conferencePill.waitForExistence(timeout: 10),
                      "The standings item should push the ACC page")
        let anyRow = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ OR label == %@", " overall", "Standings TBA")).firstMatch
        XCTAssertTrue(anyRow.waitForExistence(timeout: 15),
                      "The page should show standings rows or the TBA state")

        // Follow round-trip: flip on, flip back off so the simulator's
        // persisted state stays clean for other tests. Follows persist on
        // the simulator, so normalize an already-following leftover first.
        let leftover = app.buttons["Following conference"].firstMatch
        if leftover.waitForExistence(timeout: 2) {
            leftover.tap()
        }
        let follow = app.buttons["Follow conference"].firstMatch
        XCTAssertTrue(follow.waitForExistence(timeout: 5),
                      "The page should offer a conference follow pill")
        follow.tap()
        let following = app.buttons["Following conference"].firstMatch
        XCTAssertTrue(following.waitForExistence(timeout: 5),
                      "Follow should flip to Following")
        following.tap()
        XCTAssertTrue(app.buttons["Follow conference"].firstMatch.waitForExistence(timeout: 5),
                      "Unfollow should flip back")

        // Scores headers carry the same affordance. Which conferences have
        // games is a calendar fact, but the section stack always renders
        // some conference during the season and the preseason slate; assert
        // any standings button rather than a specific conference's.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(openTab("Scores", in: app, until: app.seasonChip),
                      "Scores should render its header")
        // A followed conference pins a whole slate into Following, and Top
        // 25 stacks another ~20 games under it — the first conference
        // header can sit beyond any reasonable swipe budget. Collapsing
        // the two headline sections brings the conferences into reach;
        // their headers are always at the top and the collapse persists
        // exactly like a user's tap would.
        for prefix in ["Following,", "Top 25,"] {
            let header = app.buttons.matching(NSPredicate(
                format: "label BEGINSWITH %@ AND value == %@", prefix, "expanded")).firstMatch
            if header.waitForExistence(timeout: 3) {
                header.tap()
            }
        }
        let scoresStandings = app.buttons.matching(NSPredicate(
            format: "label ENDSWITH %@", " standings")).firstMatch
        XCTAssertTrue(scrollUntilExists(scoresStandings, in: app),
                      "A Scores conference header should carry a standings button")
    }

    @MainActor
    func testRankingsListsTop25RowAndConferences() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES"]
        app.launch()

        // The root is the list: Top 25 row first, conferences right below.
        XCTAssertTrue(openTab("Rankings", in: app, until: app.top25Row),
                      "Rankings should lead with the Top 25 row")

        // An ACC row exists year-round (the list renders offseason, teasers
        // or not); its label is either bare "ACC" or "ACC, led by …".
        let accRow = app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ OR label BEGINSWITH %@", "ACC", "ACC, led by")).firstMatch
        XCTAssertTrue(scrollUntilExists(accRow, in: app, maxSwipes: 4, timeout: 5),
                      "Rankings should list the ACC near the root")
        accRow.tap()
        XCTAssertTrue(app.navigationBars["ACC"].waitForExistence(timeout: 10),
                      "Tapping the conference row should push its standings page")

        // And the Top 25 row pushes the poll.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.top25Row.waitForExistence(timeout: 5),
                      "Popping back should land on the Rankings list")
        app.top25Row.tap()
        XCTAssertTrue(app.topRankedRow.waitForExistence(timeout: 15),
                      "The Top 25 row should push a poll with a ranked #1")
    }
}
