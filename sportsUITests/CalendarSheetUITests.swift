import XCTest

/// The calendar jump sheet and the league-qualified team routing — the two
/// pieces of navigation added 2026-09-06, both driven end to end.
final class CalendarSheetUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        // The slate filter persists by design, so pin it (see CLAUDE.md).
        app.launchArguments += ["-ui.scoreFilter", "none", "-ui.liveOnly", "NO"]
        app.launch()
        return app
    }

    /// The header button opens the sheet, and picking a day moves the strip.
    func testCalendarSheetJumpsToADay() {
        let app = launch()
        let calendar = app.buttons["scores-calendar-button"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 20),
                      "The Scores header should carry a calendar button")
        calendar.tap()

        // The sheet's own title, so we know we're in it and not on Scores.
        XCTAssertTrue(app.navigationBars["Jump to a day"].waitForExistence(timeout: 10),
                      "The calendar button should open the jump sheet")

        // Any day cell will do — they're labelled with their full date, so
        // the first one visible is a real, tappable day of the season.
        let cell = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@", ",")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10),
                      "The sheet should render day cells")
        let chosen = cell.label
        cell.tap()

        // Picking a day dismisses the sheet and lands the strip on it.
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.navigationBars["Jump to a day"])
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed,
                       "Picking a day should close the sheet")
        XCTAssertTrue(calendar.waitForExistence(timeout: 10),
                      "and land back on Scores. Chose: \(chosen)")
    }

    /// The sheet opens on the month the strip is already on — Andy's
    /// 2026-09-12 report, where it opened on July whatever day was showing.
    ///
    /// Encodes no calendar fact: it scrolls somewhere the sheet didn't open
    /// on, picks whatever day is there, and asserts the *reopened* sheet
    /// shows that day's month. Whichever months those are is the app's
    /// business, not the test's.
    func testCalendarSheetOpensOnTheSelectedMonth() throws {
        let app = launch()
        let calendar = app.buttons["scores-calendar-button"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 20))
        calendar.tap()
        XCTAssertTrue(app.navigationBars["Jump to a day"].waitForExistence(timeout: 10))

        // Well past the month it opened on — the season spans a year, so
        // there is always somewhere else to be. The sheet is modal, so an
        // app-level swipe lands in it.
        for _ in 0..<4 { app.swipeUp() }

        let cell = dayCells(in: app).first { $0.isHittable }
        let label = try XCTUnwrap(cell?.label, "The sheet should render day cells")
        // "Saturday, November 14" — the month is what follows the comma.
        let month = try XCTUnwrap(
            label.split(separator: ",").last?.trimmingCharacters(in: .whitespaces)
                .split(separator: " ").first.map(String.init),
            "Day cells speak their whole date")
        cell?.tap()

        XCTAssertTrue(calendar.waitForExistence(timeout: 10), "Picking a day closes the sheet")
        calendar.tap()
        XCTAssertTrue(app.navigationBars["Jump to a day"].waitForExistence(timeout: 10))

        // The month header for the day just picked, on screen without a
        // scroll. A sheet that opened at the season's start fails here.
        let header = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", month)).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10) && header.isHittable,
                      "Reopening should land on \(month) — the month of the selected day")
    }

    /// Day cells speak their whole date ("Saturday, November 14"), which is
    /// the one label in the sheet carrying a comma.
    private func dayCells(in app: XCUIApplication) -> [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", "))
            .allElementsBoundByIndex
    }

    /// The reported bug, end to end: searching a team whose ESPN id a
    /// college program also holds must open that team, not the college one.
    /// The Browns and UAB are both id 5.
    func testSearchingTheBrownsOpensTheBrowns() {
        let app = launch()
        // The search tab is the last one — a circle on iOS 26, a tab on 18.
        let searchTab = app.tabBars.buttons.element(boundBy: app.tabBars.buttons.count - 1)
        XCTAssertTrue(searchTab.waitForExistence(timeout: 20))
        searchTab.tap()

        let field = app.searchFields.firstMatch.exists
            ? app.searchFields.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Search needs a field")
        field.tap()
        field.typeText("Browns")

        // The result row, then the page it lands on.
        let result = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@", "Cleveland")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15),
                      "Searching Browns should offer Cleveland")
        result.tap()

        // UAB is what the bug used to open. Assert against it by name so a
        // regression reads as exactly the bug it is.
        let uab = app.staticTexts["UAB"]
        let cleveland = app.staticTexts["Cleveland"]
        XCTAssertTrue(cleveland.waitForExistence(timeout: 15),
                      "Tapping the Browns should open Cleveland's page")
        XCTAssertFalse(uab.exists,
                       "Tapping the Browns must never open UAB (both are ESPN id 5)")
    }
}
