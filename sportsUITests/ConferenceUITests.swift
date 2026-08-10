import XCTest

/// Live-network walk of the conference standings flow: the Teams header's
/// standings button pushes ConferencePage, the follow pill toggles, and the
/// Scores headers carry the same affordance.
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

        // Teams tab: the first conference group's header carries a standings
        // button. ACC, not SEC — the browse list is a LazyVStack, so a
        // section below the fold doesn't exist as an element yet, and ACC
        // sorts first (the existing smoke test leans on it the same way).
        XCTAssertTrue(openTab("Teams", in: app, until: app.staticTexts["ACC"]),
                      "Teams should show the ACC conference header")
        let standingsButton = app.buttons["ACC standings"].firstMatch
        XCTAssertTrue(standingsButton.waitForExistence(timeout: 5),
                      "The ACC header should carry a standings button")
        standingsButton.tap()

        // ConferencePage: title, follow pill, and standings-or-TBA. Rows
        // collapse to one element (a button, via NavigationLink), so query
        // any descendant by label like UITestSupport's topRankedRow does.
        XCTAssertTrue(app.navigationBars["ACC"].waitForExistence(timeout: 10),
                      "The standings button should push the ACC page")
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
        // The section stack is a LazyVStack, and a followed conference can
        // swell Following to a whole slate — the first conference header
        // may sit screens below the fold, where its elements don't exist
        // yet. Scroll until one materializes.
        let scoresStandings = app.buttons.matching(NSPredicate(
            format: "label ENDSWITH %@", " standings")).firstMatch
        _ = scoresStandings.waitForExistence(timeout: 15)
        for _ in 0..<12 where !scoresStandings.exists {
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(scoresStandings.exists,
                      "A Scores conference header should carry a standings button")
    }

    @MainActor
    func testRankingsListsConferencesBelowThePoll() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES"]
        app.launch()

        XCTAssertTrue(openTab("Rankings", in: app, until: app.topRankedRow),
                      "Rankings should show a ranked #1")

        // The CONFERENCES card sits below the 25 poll rows in a LazyVStack,
        // so its rows don't exist as elements until scrolled near. An ACC
        // row exists year-round (the list renders offseason, teasers or
        // not); its label is either bare "ACC" or "ACC, led by …".
        let accRow = app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ OR label BEGINSWITH %@", "ACC", "ACC, led by")).firstMatch
        for _ in 0..<12 where !accRow.exists {
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(accRow.waitForExistence(timeout: 5),
                      "Rankings should list the ACC below the poll")
        accRow.tap()
        XCTAssertTrue(app.navigationBars["ACC"].waitForExistence(timeout: 10),
                      "Tapping the conference row should push its standings page")
    }
}
