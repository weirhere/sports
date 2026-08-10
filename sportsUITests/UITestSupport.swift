import XCTest

/// Shared queries for the UI tests. Both live-data walks (SmokeUITests,
/// ScreenshotTests, AppStoreScreenshots) hit the same two rough edges: which
/// polls exist depends on the calendar, and the season menu is a SwiftUI
/// `Menu` that a mid-load re-render can dismiss out from under the tap.
extension XCUIApplication {
    /// The #1 row of whichever poll PollScreen is showing — proof the poll
    /// rendered real data.
    ///
    /// Don't reach for the poll chips instead. They're the wrong landmark
    /// twice over: the picker only renders when more than one poll exists
    /// (`PollScreen.body`), and which polls exist is a calendar fact —
    /// the preseason AP Top 25 doesn't drop until mid-August, so for most of
    /// the year the feed carries only the Coaches poll and no chips appear.
    /// The label shape comes from `RankRow.accessibilitySummary`.
    var topRankedRow: XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Number 1,"))
            .firstMatch
    }

    /// The Top 25 row leading the Rankings list. By identifier, not label —
    /// the Scores tab's "Top 25, N games" accordion header lives in the
    /// same element tree and label queries cross tab hierarchies.
    var top25Row: XCUIElement {
        descendants(matching: .any)
            .matching(identifier: "rankings-top25-row").firstMatch
    }

    /// The season chip in the Scores header, labeled with the selected year.
    var seasonChip: XCUIElement {
        buttons.matching(NSPredicate(format: "label MATCHES %@", "^20[0-9][0-9]$"))
            .firstMatch
    }
}

extension XCTestCase {
    /// Opens the Rankings tab and drills into the poll: tab → Top 25 row →
    /// PollScreen's #1 row. The poll moved one level down when Rankings
    /// became the tables hub, so every "show me the poll" test goes
    /// through here.
    @MainActor
    @discardableResult
    func openRankingsPoll(in app: XCUIApplication) -> Bool {
        guard openTab("Rankings", in: app, until: app.top25Row) else { return false }
        app.top25Row.tap()
        return app.topRankedRow.waitForExistence(timeout: 15)
    }

    /// Waits for `element`, swiping down the list if it hasn't materialized.
    ///
    /// The Scores stack is a LazyVStack, and a followed conference swells
    /// Following to a whole slate — sections that used to sit at the top
    /// (SEC, the first day header) can be screens below the fold, where
    /// their elements don't exist yet. Persisted follows are real user
    /// state, so any assertion about a section must be willing to scroll.
    @MainActor
    @discardableResult
    func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication,
                           maxSwipes: Int = 12, timeout: TimeInterval = 15) -> Bool {
        if element.waitForExistence(timeout: timeout) { return true }
        for _ in 0..<maxSwipes where !element.exists {
            app.swipeUp(velocity: .fast)
        }
        return element.exists
    }

    /// Taps a tab and waits for something on the destination to prove it
    /// landed, retrying the tap if it didn't.
    ///
    /// A tab tap issued while a navigation pop is still animating gets
    /// swallowed — the tap "succeeds", the app stays put, and the next wait
    /// fails somewhere unrelated with a screenshot of the wrong screen.
    @MainActor
    @discardableResult
    func openTab(_ name: String, in app: XCUIApplication,
                 until landmark: XCUIElement, timeout: TimeInterval = 15,
                 attempts: Int = 3) -> Bool {
        for _ in 0..<attempts {
            let tab = app.tabBars.buttons[name]
            guard tab.waitForExistence(timeout: 10) else { continue }
            tab.tap()
            if landmark.waitForExistence(timeout: timeout) { return true }
        }
        return false
    }

    /// Scrolls `element` into view inside `strip` and taps it.
    ///
    /// Two traps here. Direction isn't fixed — the week strip opens on the
    /// current week, so Week 10 sits off to the right in a fresh season and
    /// off to the left in a completed one, and scrolling the wrong way walks
    /// away from it until the loop gives up. And `swipeLeft`/`swipeRight`
    /// travel the strip's full width, roughly six weeks, so a fixed swipe
    /// overshoots and then ping-pongs past the target forever.
    ///
    /// So: drag a controlled fraction of the strip, and halve that fraction
    /// every time the direction reverses. It converges instead of oscillating.
    /// Tapping an offscreen element throws "activation point invalid", so
    /// visibility is checked by frame containment rather than isHittable.
    @MainActor
    @discardableResult
    func scrollToAndTap(_ element: XCUIElement, in strip: XCUIElement,
                        within window: XCUIElement, maxDrags: Int = 20) -> Bool {
        var fraction: CGFloat = 0.5
        var lastWasLeftward: Bool?

        for _ in 0..<maxDrags {
            guard element.exists else { return false }
            if window.frame.contains(element.frame) {
                element.tap()
                return true
            }
            // Leftward drag pulls content left, revealing what's off the right.
            let leftward = element.frame.midX > window.frame.midX
            if let last = lastWasLeftward, last != leftward {
                fraction = max(fraction / 2, 0.08)
            }
            lastWasLeftward = leftward

            let dx = fraction / 2
            let from = strip.coordinate(withNormalizedOffset:
                CGVector(dx: leftward ? 0.5 + dx : 0.5 - dx, dy: 0.5))
            let to = strip.coordinate(withNormalizedOffset:
                CGVector(dx: leftward ? 0.5 - dx : 0.5 + dx, dy: 0.5))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        return false
    }

    /// Switches the Scores header to `year`, returning false if it never took.
    ///
    /// The menu is retried: tapping the chip while the first scoreboard load is
    /// still settling re-renders the header and drops the menu before its items
    /// register, which reads as "no 2025 button" and fails an unguarded wait.
    @MainActor
    @discardableResult
    func selectSeason(_ year: Int, in app: XCUIApplication,
                      attempts: Int = 3) -> Bool {
        let label = String(year)
        for _ in 0..<attempts {
            let chip = app.seasonChip
            guard chip.waitForExistence(timeout: 15) else { continue }
            if chip.label == label { return true }
            chip.tap()

            // Picker rows inside a Menu surface as plain buttons on iOS.
            let option = app.buttons[label]
            guard option.waitForExistence(timeout: 5) else { continue }
            option.tap()

            let updated = app.seasonChip
            if updated.waitForExistence(timeout: 10), updated.label == label {
                return true
            }
        }
        return false
    }
}
