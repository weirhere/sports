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

    /// The season picker's menu button in the filter sheet, labeled with
    /// the selected year.
    var seasonChip: XCUIElement {
        buttons.matching(NSPredicate(format: "label MATCHES %@", "^20[0-9][0-9]$"))
            .firstMatch
    }

    /// The Scores header's funnel chip — the door to the view-options
    /// sheet (grouping, season, conference filter).
    var scoresFilterChip: XCUIElement {
        descendants(matching: .any)
            .matching(identifier: "scores-filter-chip").firstMatch
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

    /// Which way an off-screen element is expected to lie.
    enum ScrollReveal { case below, above }

    /// Waits for `element`, swiping through the list if it hasn't materialized.
    ///
    /// The Scores stack is a LazyVStack, and a followed conference swells
    /// Following to a whole slate — sections that used to sit at the top
    /// (SEC, the first day header) can be screens below the fold, where
    /// their elements don't exist yet. Persisted follows are real user
    /// state, so any assertion about a section must be willing to scroll.
    /// A full in-season Saturday slate runs ~99 games, so the swipe budget
    /// has to cover many screens of rows.
    ///
    /// `revealing: .above` swipes the other way: the list keeps its scroll
    /// position across tab switches, so a section pinned to the top
    /// (Following) can sit screens above wherever the last hunt ended.
    @MainActor
    @discardableResult
    func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication,
                           revealing: ScrollReveal = .below,
                           maxSwipes: Int = 20, timeout: TimeInterval = 15) -> Bool {
        if element.waitForExistence(timeout: timeout) { return true }
        for _ in 0..<maxSwipes where !element.exists {
            switch revealing {
            case .below: app.swipeUp(velocity: .fast)
            case .above: app.swipeDown(velocity: .fast)
            }
        }
        return element.exists
    }

    /// Taps `button` and verifies `panel` actually went away, retrying with
    /// a frame-derived coordinate tap when it didn't.
    ///
    /// iOS 26.5 hosts alert panels — the app's SwiftUI alerts and
    /// springboard's permission prompts alike — outside the accessibility
    /// window `tap()` resolves its activation point against, so the
    /// synthesized tap can land nowhere while the element query itself
    /// matched fine. A coordinate tap synthesizes the touch at the button's
    /// on-screen frame, which does land. The wait between attempts is the
    /// dismiss animation's grace period — without it a good tap reads as a
    /// miss and the retry pokes whatever lies beneath the departed panel.
    /// `via` chooses whose coordinate space synthesizes the touch. For any
    /// panel button pass the app under test: a coordinate rooted in the
    /// (full-screen) app is a true screen-level touch and lands on the
    /// panel. `button.tap()` is never used in that mode — the broken
    /// synthesis doesn't just miss, its strays land on unrelated app UI
    /// (a late one toggled the reminder bell straight back off), so the
    /// element-tap path can't even be tried first.
    @MainActor
    @discardableResult
    func tapUntilDismissed(_ button: XCUIElement, dismissing panel: XCUIElement,
                           via eventTarget: XCUIApplication? = nil,
                           attempts: Int = 3) -> Bool {
        for _ in 0..<attempts {
            guard button.exists else { break }
            if let target = eventTarget {
                // The panel scales in; a frame read mid-animation aims at
                // a point the button hasn't reached yet (one such tap
                // landed on Not Now instead of Enable). Hold fire until
                // two consecutive reads agree.
                var frame = button.frame
                for _ in 0..<8 {
                    Thread.sleep(forTimeInterval: 0.25)
                    let settled = button.frame
                    if settled == frame, !settled.isEmpty { break }
                    frame = settled
                }
                target.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
                    .tap()
            } else {
                button.tap()
            }
            let gone = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: panel)
            if XCTWaiter.wait(for: [gone], timeout: 3) == .completed { return true }
        }
        return !panel.exists
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

    /// Switches the Scores season to `year` through the filter sheet,
    /// returning false if it never took. Leaves the sheet closed.
    ///
    /// The menu is retried: tapping the picker while the first scoreboard
    /// load is still settling re-renders the sheet and drops the menu
    /// before its items register, which reads as "no 2025 button" and
    /// fails an unguarded wait.
    @MainActor
    @discardableResult
    func selectSeason(_ year: Int, in app: XCUIApplication,
                      attempts: Int = 3) -> Bool {
        let label = String(year)
        for _ in 0..<attempts {
            // The season picker lives in the filter sheet (2026-08-29).
            if !app.seasonChip.exists {
                let funnel = app.scoresFilterChip
                guard funnel.waitForExistence(timeout: 15) else { continue }
                funnel.tap()
            }
            let chip = app.seasonChip
            guard chip.waitForExistence(timeout: 10) else { continue }
            if chip.label == label {
                dismissFilterSheet(in: app)
                return true
            }
            chip.tap()

            // Picker rows inside a Menu surface as plain buttons on iOS.
            let option = app.buttons[label]
            guard option.waitForExistence(timeout: 5) else { continue }
            option.tap()

            let updated = app.seasonChip
            if updated.waitForExistence(timeout: 10), updated.label == label {
                dismissFilterSheet(in: app)
                return true
            }
        }
        return false
    }

    /// Switches the Scores grouping through the filter sheet's segmented
    /// picker, returning false if the sheet or segment never appeared.
    /// Leaves the sheet closed.
    @MainActor
    @discardableResult
    func setScoresGrouping(byDate: Bool, in app: XCUIApplication) -> Bool {
        let funnel = app.scoresFilterChip
        guard funnel.waitForExistence(timeout: 10) else { return false }
        funnel.tap()
        let segment = app.buttons[byDate ? "By date" : "By conference"]
        guard segment.waitForExistence(timeout: 5) else {
            dismissFilterSheet(in: app)
            return false
        }
        segment.tap()
        dismissFilterSheet(in: app)
        return true
    }

    /// Closes the filter sheet if it's up; a no-op otherwise.
    @MainActor
    private func dismissFilterSheet(in app: XCUIApplication) {
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 3) { cancel.tap() }
    }
}
