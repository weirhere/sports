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
    func testCalendarSheetJumpsToADay() throws {
        let app = launch()
        let calendar = app.buttons["scores-calendar-button"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 20),
                      "The Scores header should carry a calendar button")
        calendar.tap()

        // The sheet's own title, so we know we're in it and not on Scores.
        XCTAssertTrue(app.navigationBars["Jump to a day"].waitForExistence(timeout: 10),
                      "The calendar button should open the jump sheet")

        let target = try XCTUnwrap(reachableCell(daysFromToday: 1, or: -1, in: app),
                                   "The sheet should offer the day next to today")
        let chosen = target.label
        target.tap()

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
    /// Encodes no calendar fact: it goes somewhere the sheet cannot have
    /// opened on — 45 days out, which outruns the longest month and so is
    /// always a different one — picks the day there, and asserts the *reopened*
    /// sheet shows that day's month. Which month that is stays the app's
    /// business, and the date is computed, never written down.
    func testCalendarSheetOpensOnTheSelectedMonth() throws {
        let app = launch()
        let calendar = app.buttons["scores-calendar-button"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 20))
        calendar.tap()
        XCTAssertTrue(app.navigationBars["Jump to a day"].waitForExistence(timeout: 10))

        let target = try XCTUnwrap(reachableCell(daysFromToday: 45, or: -45, in: app),
                                   "The sheet should reach a month and a half out")
        // "Saturday, November 14" — the month is what follows the comma.
        let month = try XCTUnwrap(
            target.label.split(separator: ",").last?.trimmingCharacters(in: .whitespaces)
                .split(separator: " ").first.map(String.init),
            "Day cells speak their whole date")
        target.tap()

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

    // MARK: - Reaching a day cell
    //
    // Two rules govern every query below, both learned from this file being
    // red for a week.
    //
    // 1. Address a cell, never enumerate. `allElementsBoundByIndex` over the
    //    ~108 realized cells, then asking each one where it is, races the
    //    sheet's own scroll animation: the indices move under the query and
    //    it dies on "no matches found for element at index 77". That passed
    //    run-alone and failed in a full suite, which is the worst shape a
    //    test can have. One identifier is one resolution and cannot race.
    //
    // 2. Never match a cell by its label. The cells speak their whole date
    //    ("Sunday, September 14") and so does every chip in the day strip —
    //    a season of them, still in the tree behind the sheet. A label match
    //    found a strip chip at x = −7377 and tapped nothing at all.

    /// The cell `days` from today, scrolled into reach; `fallback` covers
    /// the season's edges, where one direction runs off the end of it.
    private func reachableCell(daysFromToday days: Int, or fallback: Int,
                               in app: XCUIApplication) -> XCUIElement? {
        if let cell = reveal(Self.dayCellId(daysFromToday: days),
                             scrollingForward: days > 0, in: app) { return cell }
        return reveal(Self.dayCellId(daysFromToday: fallback),
                      scrollingForward: fallback > 0, in: app)
    }

    /// Scrolls the sheet until the cell is genuinely tappable.
    ///
    /// `isHittable` alone is not enough: a cell scrolled up under the
    /// sticky header still reports itself hittable from behind it, and the
    /// tap then lands on the header. The first such cell measured y = 48
    /// against chrome reaching y = 132 — the sheet stayed open, and the
    /// test read that as the app refusing to dismiss.
    /// The sheet is lazy — it realizes roughly three months around wherever
    /// it is sitting, so a cell two months out does not exist yet and no
    /// amount of waiting will conjure it. `scrollingForward` says which way
    /// to go looking; once the cell exists, its own frame steers the rest.
    private func reveal(_ identifier: String, scrollingForward forward: Bool,
                        in app: XCUIApplication) -> XCUIElement? {
        let cell = app.buttons[identifier]
        let window = app.windows.firstMatch.frame
        for _ in 0..<14 {
            guard cell.exists else {
                forward ? app.swipeUp() : app.swipeDown()
                continue
            }
            let frame = cell.frame
            if cell.isHittable, frame.minY > chromeBottom(in: app), frame.maxY < window.maxY {
                return cell
            }
            // Above the chrome means scroll back toward it, not away.
            if frame.minY <= chromeBottom(in: app) { app.swipeDown() } else { app.swipeUp() }
        }
        return nil
    }

    /// The bottom of the sheet's sticky top: the nav bar, plus the weekday
    /// caption row riding under it as a safe-area inset. "W" is the one
    /// caption letter that appears exactly once, so it measures the row
    /// without a hard-coded height.
    private func chromeBottom(in app: XCUIApplication) -> CGFloat {
        let captions = app.staticTexts["W"]
        return captions.exists ? captions.frame.maxY
            : app.navigationBars["Jump to a day"].frame.maxY
    }

    /// `DayFormat.id`'s spelling, which is what the cell identifiers carry.
    private static func dayCellId(daysFromToday days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "calendar-day-\(formatter.string(from: date))"
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
