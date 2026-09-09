import XCTest

/// The Postseason bracket's round swipe (Andy, 2026-09-06) — the gesture
/// shares the horizontal axis with the entity pages' tab swipe, so this
/// asserts the round moves and the tab doesn't.
final class PostseasonSwipeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// A bracket only exists where a playoff has been played, and the tab
    /// is hidden outright where it hasn't (`ConferencePage.availableTabs`)
    /// — so for most of the year the current season is the one place this
    /// test cannot run. It steps back a season instead.
    ///
    /// Which season that is comes from the chip's own value, never a
    /// hardcoded year: assertions here must not encode calendar facts.
    private func selectPreviousSeason(_ app: XCUIApplication) -> Bool {
        let chip = app.buttons["season-chip"].firstMatch
        guard chip.waitForExistence(timeout: 20),
              let current = Int(chip.value as? String ?? "") else { return false }
        chip.tap()
        // A Picker inside a Menu surfaces as menu items on some runtimes and
        // plain buttons on others, and neither exists the instant the chip is
        // tapped — so wait for whichever turns up rather than reading
        // `.exists` before the menu has drawn.
        let year = String(current - 1)
        let item = app.menuItems[year].firstMatch
        let button = app.buttons[year].firstMatch
        guard item.waitForExistence(timeout: 5) || button.waitForExistence(timeout: 5)
        else { return false }
        (item.exists ? item : button).tap()

        // Self-verifying, like the Scores season helper: the switch refetches
        // the season, and everything after this depends on it having taken.
        let took = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", year), object: chip)
        return XCTWaiter().wait(for: [took], timeout: 30) == .completed
    }

    private func openPostseason(_ app: XCUIApplication) -> Bool {
        app.buttons["tables-league-cfb"].firstMatch.waitForExistence(timeout: 20)
        let top25 = app.buttons["rankings-top25-row"].firstMatch
        guard top25.waitForExistence(timeout: 20) else { return false }
        top25.tap()
        guard selectPreviousSeason(app) else { return false }
        // A past season is two `limit=900` requests for the whole FBS
        // slate, so the tab can take a beat longer than a tab switch.
        let tab = app.buttons["Postseason"].firstMatch
        guard tab.waitForExistence(timeout: 60) else { return false }
        tab.tap()
        return true
    }

    func testSwipingWalksTheRounds() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.scoreFilter", "none", "-ui.liveOnly", "NO"]
        app.launch()
        app.tabBars.buttons["Leagues"].firstMatch.tap()
        guard openPostseason(app) else {
            XCTFail("Couldn't reach the Postseason tab in the previous season")
            return
        }

        let chips = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "postseason-round-"))
        XCTAssertGreaterThan(chips.count, 1, "A bracket needs more than one round")

        // Start from the first round deliberately. A finished season opens
        // on its *last* round (`Postseason.defaultRound`) — the national
        // championship — where a left swipe has nowhere to go, and the
        // right swipe that would is the system's back gesture near the
        // screen edge. So the only honest direction to assert is forward
        // from the front.
        let first = chips.element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 10), "The bracket should chip its rounds")
        first.tap()
        let before = first.identifier

        // Drag just under the chip row, where the round's first match card
        // always sits. The obvious mid-screen swipe misses: the gesture is
        // attached to the bracket's own stack, which is only as tall as its
        // cards, and an early round of a finished playoff can be a single
        // game — so the middle of the screen is empty space that receives
        // nothing. `swipeLeft()` is no good either; the round swipe is
        // threshold-based (>50pt, `PostseasonSection.roundSwipe`) and wants
        // a real drag, which is why the strip helper uses this same call.
        let y = first.frame.maxY + 40
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(CGVector(dx: app.frame.width * 0.85, dy: y))
        let to = origin.withOffset(CGVector(dx: app.frame.width * 0.15, dy: y))
        from.press(forDuration: 0.1, thenDragTo: to,
                   withVelocity: .slow, thenHoldForDuration: 0.1)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let now = (0..<chips.count)
                    .map { chips.element(boundBy: $0) }
                    .first { $0.isSelected }?.identifier
                return now != nil && now != before
            }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed,
                       "Swiping left should move to the next round")

        // The tab must not have moved with it — the rounds own this axis.
        XCTAssertTrue(app.buttons["Postseason"].firstMatch.exists,
                      "The swipe must not have changed tabs")
    }
}
