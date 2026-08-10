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
        // persisted state stays clean for other tests.
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
        let scoresStandings = app.buttons.matching(NSPredicate(
            format: "label ENDSWITH %@", " standings")).firstMatch
        XCTAssertTrue(scoresStandings.waitForExistence(timeout: 15),
                      "A Scores conference header should carry a standings button")
    }
}
