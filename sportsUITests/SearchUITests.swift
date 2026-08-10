import XCTest

/// Live-network smoke for app-wide search: open the search tab, find a
/// team, land on its page.
///
/// The search tab's field carries the `search.appWide` identifier because
/// the Teams tab keeps its own pinned search field — `searchFields
/// .firstMatch` would be ambiguous whenever both are in the hierarchy.
///
/// No game-result assertions: which games exist is a calendar fact, and the
/// team directory is the one calendar-independent corpus.
final class SearchUITests: XCTestCase {
    @MainActor
    func testSearchTabLandsOnTeamPage() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES"]
        app.launch()

        // Tab(role: .search) renders as a circular accessory beside the
        // floating tab bar on iOS 26 — still a tab-bar button to XCUITest.
        let searchTab = app.tabBars.buttons["Search"].firstMatch
        XCTAssertTrue(searchTab.waitForExistence(timeout: 15),
                      "The tab bar should carry the search tab")
        searchTab.tap()

        let field = app.searchFields["search.appWide"]
        XCTAssertTrue(field.waitForExistence(timeout: 5),
                      "The search tab should present its field")
        // focusOnAppear should have the keyboard up already; tapping anyway
        // costs nothing and deflakes the focus timing.
        field.tap()
        field.typeText("Georgia Bulldogs")

        let result = app.buttons["Georgia Bulldogs"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10),
                      "Search should surface Georgia in team results")
        result.tap()

        // The Router intent switches to the Teams tab and lands on the team
        // page; Follow may already read Following from a prior run.
        let landed = app.buttons["Follow"].firstMatch.waitForExistence(timeout: 10)
            || app.buttons["Following"].firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(landed, "A team result should land on its team page")
    }

    @MainActor
    func testSearchConferenceResultLandsOnStandingsPage() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES"]
        app.launch()

        let searchTab = app.tabBars.buttons["Search"].firstMatch
        XCTAssertTrue(searchTab.waitForExistence(timeout: 15),
                      "The tab bar should carry the search tab")
        searchTab.tap()

        let field = app.searchFields["search.appWide"]
        XCTAssertTrue(field.waitForExistence(timeout: 5),
                      "The search tab should present its field")
        field.tap()
        field.typeText("Mountain West")

        let result = app.buttons["Mountain West"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10),
                      "Search should surface the Mountain West in conference results")
        result.tap()

        // The intent lands on the conference's standings page (rows or the
        // offseason "Standings TBA" — both valid year-round).
        XCTAssertTrue(app.navigationBars["Mountain West"].waitForExistence(timeout: 10),
                      "A conference result should land on its standings page")
        let content = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ OR label == %@", " overall", "Standings TBA")).firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 15),
                      "The standings page should render rows or the TBA state")
    }
}
