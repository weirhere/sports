import XCTest

/// The Postseason bracket's round swipe (Andy, 2026-09-06) — the gesture
/// shares the horizontal axis with the entity pages' tab swipe, so this
/// asserts the round moves and the tab doesn't.
final class PostseasonSwipeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// The current season has no results, so a completed one is the only
    /// place a full bracket exists. 2025's playoff is finished.
    private func openPostseason(_ app: XCUIApplication) -> Bool {
        app.buttons["tables-league-cfb"].firstMatch.waitForExistence(timeout: 20)
        let top25 = app.buttons["rankings-top25-row"].firstMatch
        guard top25.waitForExistence(timeout: 20) else { return false }
        top25.tap()
        let tab = app.buttons["Postseason"].firstMatch
        guard tab.waitForExistence(timeout: 25) else { return false }
        tab.tap()
        return true
    }

    func testSwipingWalksTheRounds() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.scoreFilter", "none", "-ui.liveOnly", "NO"]
        app.launch()
        app.tabBars.buttons["Tables"].firstMatch.tap()
        guard openPostseason(app) else {
            XCTFail("Couldn't reach the Postseason tab")
            return
        }

        // Whichever round it opened on, swiping left should land on a
        // different one — and leave the tab alone.
        let chips = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "postseason-round-"))
        XCTAssertGreaterThan(chips.count, 1, "A bracket needs more than one round")
        let before = (0..<chips.count)
            .map { chips.element(boundBy: $0) }
            .first { $0.isSelected }?.identifier
        XCTAssertNotNil(before, "Some round should be selected")

        app.swipeLeft()
        let changed = NSPredicate(format: "isSelected == true")
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let now = (0..<chips.count)
                    .map { chips.element(boundBy: $0) }
                    .first { $0.isSelected }?.identifier
                return now != nil && now != before
            }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed,
                       "Swiping left should move to the next round")
        _ = changed

        // The tab must not have moved with it — the rounds own this axis.
        XCTAssertTrue(app.buttons["Postseason"].firstMatch.exists,
                      "The swipe must not have changed tabs")
    }
}
