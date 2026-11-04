import XCTest

/// Regression coverage for the self-popping live game detail (BACKLOG E5,
/// observed live 2026-08-29 on SJSU @ USC: a pushed detail dismissed
/// itself mid-drive with no input). Runs against `FixtureScoresClient` —
/// a scripted slate that replays a Saturday's state changes (scores
/// moving, a game going final, a kickoff, a payload dropping a game, a
/// rank blinking, a transient fetch failure) — with the poll compressed
/// to one second, so a one-minute hold covers more refresh churn than an
/// hour of real ESPN.
///
/// Unlike the rest of this suite, no live data and no calendar facts: the
/// fixture serves the same Saturday every run.
final class LiveDetailHoldUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchFixtureApp(liveOnly: Bool = false,
                                  summaryFlicker: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui.onboardingSeen", "YES",
            "-ui.followPromptDismissed", "YES",
            // Pin the slate filter: it persists across launches by design
            // (2026-08-29), so without this a suite inherits whatever the
            // last run — or the person using this simulator — left
            // selected, and every row query goes looking in a filtered
            // slate. Safe as an argument-domain override because
            // UIStateStore reads the key once at init; "none" parses to
            // no filter.
            "-ui.scoreFilter", "none",
            "-data.provider", "fixture",
            "-poll.interval", "0.5",
        ]
        if liveOnly {
            // Live is session-only (2026-10-22); this is the DEBUG-only
            // launch hook that starts the app on a live slate.
            app.launchArguments += ["-ui.liveOnly", "YES"]
        }
        if summaryFlicker {
            app.launchArguments += ["-fixture.summaryFlicker", "YES"]
        }
        app.launch()
        return app
    }

    /// Finds the hold target's row (label churns every poll, so match a
    /// stable substring), pushes its detail with a settled-frame
    /// coordinate tap, and returns the detail's toolbar landmark.
    @MainActor
    private func pushDetail(containing text: String,
                            in app: XCUIApplication) -> XCUIElement {
        let rows = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'scores-game' AND label CONTAINS %@", text))
        XCTAssertTrue(scrollUntilExists(rows.firstMatch, in: app), "fixture row \(text) never appeared")
        // A game is a row in every section it belongs to (Top 25 and its
        // conference), and the first in tree order can sit below the fold:
        // a coordinate tap at an off-screen frame lands nowhere (y 1316 on
        // an 874pt screen at the 3.0.0 cut). Tap the first copy on screen,
        // and only once its frame has held still across two reads — a frame
        // read while a swipe's momentum is still carrying the list put the
        // tap on a section header and collapsed it.
        let screen = app.windows.firstMatch.frame
        func onScreenFrame() -> CGRect? {
            rows.allElementsBoundByIndex
                .map(\.frame)
                .first { screen.contains(CGPoint(x: $0.midX, y: $0.midY))
                    && $0.midY > 180 && $0.midY < screen.maxY - 120 }
        }
        // Off the band, scroll *toward* the row, by a measured drag. A swipe
        // that only ever went up stranded the row above the fold: one
        // momentum swipe carried the slate to its end with Charlie A&M
        // scrolled off the top, and every later swipe pushed against the
        // bottom of the list (WEIR-90, 2026-11-03). A press-and-drag has no
        // momentum, so the row lands where the drag puts it.
        func nudgeTowardRow() {
            let frames = rows.allElementsBoundByIndex.map(\.frame).filter { !$0.isEmpty }
            guard let nearest = frames.min(by: {
                abs($0.midY - screen.midY) < abs($1.midY - screen.midY)
            }) else {
                app.swipeUp(velocity: .slow)
                return
            }
            let reach = screen.height * 0.35
            let delta = max(-reach, min(reach, screen.midY - nearest.midY))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: screen.maxX - 24, dy: screen.midY))
            let end = origin.withOffset(CGVector(dx: screen.maxX - 24, dy: screen.midY + delta))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        func settledFrame() -> CGRect? {
            for _ in 0..<8 {
                let first = onScreenFrame()
                Thread.sleep(forTimeInterval: 0.4)
                let second = onScreenFrame()
                if let first, let second, first == second { return second }
                if second == nil { nudgeTowardRow() }
            }
            return nil
        }
        // The pushed page must be the game asked for. The fixture adds and
        // drops rows on its own schedule, so a row can slide under a tap
        // between the frame read and the touch: one run opened Kilo State,
        // the row above Charlie A&M (WEIR-90). The header's team names are
        // the check — the Scores rows are single combined buttons, so a
        // non-row element carrying the name is the detail's.
        let landmark = app.buttons["Share this game"]
        let header = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND NOT (identifier BEGINSWITH 'scores-game')", text))
        for _ in 0..<3 {
            guard let target = settledFrame() else {
                XCTFail("fixture row \(text) never came on screen")
                return landmark
            }
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: target.midX, dy: target.midY))
                .tap()
            guard landmark.waitForExistence(timeout: 10) else { continue }
            if header.firstMatch.waitForExistence(timeout: 3) { return landmark }
            app.navigationBars.buttons.firstMatch.tap()
            _ = rows.firstMatch.waitForExistence(timeout: 5)
        }
        XCTFail("game detail for \(text) never presented")
        return landmark
    }

    /// Asserts the detail stays up until `deadline`, checking every second.
    /// A miss has to last: one read of a landmark that's on screen the
    /// whole time can come back false on iOS 26.5 (WEIR-90 — the video and
    /// the `scoresnav` path log both had the detail still pushed), and a
    /// real pop doesn't come back, so a two-second recheck still catches it.
    @MainActor
    private func hold(_ landmark: XCUIElement, seconds: TimeInterval,
                      message: String) {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 1)
            if !landmark.exists {
                XCTAssertTrue(landmark.waitForExistence(timeout: 2), message)
            }
        }
    }

    /// Pushes the always-live fixture game and holds its detail across
    /// ~45 poll cycles, asserting the screen never pops. The share button
    /// is the landmark: it lives in the detail's toolbar and nowhere on
    /// Scores.
    @MainActor
    func testLiveDetailSurvivesRefreshChurn() throws {
        let app = launchFixtureApp()
        let landmark = pushDetail(containing: "Alpha State", in: app)
        // Every scripted state change (final at tick 8, kickoff at 5,
        // payload drop each 5th, error each 7th, rank blink each 4th,
        // live-flag flicker each 11th) lands several times in the window.
        hold(landmark, seconds: 45,
             message: "live game detail popped back to Scores mid-hold")
    }

    /// The Aug 29 pass's actual configuration risk, dialed up: the Live
    /// filter narrows every section to live games, so each scripted flip
    /// adds or removes whole rows and sections under the pushed screen —
    /// including the held game's own row vanishing when its live flag
    /// flickers.
    @MainActor
    func testLiveDetailSurvivesFilteredSectionChurn() throws {
        let app = launchFixtureApp(liveOnly: true)
        let landmark = pushDetail(containing: "Alpha State", in: app)
        hold(landmark, seconds: 45,
             message: "detail popped under the Live filter's section churn")
    }

    // MARK: - Ghost-activation diagnostics (opt-in, not part of the suite)
    //
    // The 2026-08-29 field bug ("detail pops itself back to Scores")
    // reproduced here as an iOS 26.5 XCUITest artifact, not an app bug: a
    // hold that queries the accessibility tree every second occasionally
    // fires a nav control with NO synthesized touch — on the Aug 29 tree
    // it hit the back button (pop to Scores, 3/3 runs), on current main
    // it pushed a header team link's TeamPage (2/6). The same app state
    // held by hand (simctl-driven, no XCUITest) never moved, and
    // query-free holds passed 3/3. Run these with GHOST_REPRO=1 in the
    // test environment to demonstrate the artifact; they are skipped by
    // default because their failures indict the automation stack.

    @MainActor
    func testGhostPushRepro_queryingHold() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GHOST_REPRO"] == "1",
                          "diagnostic for the iOS 26.5 ghost-activation artifact; set GHOST_REPRO=1 to run")
        let app = launchFixtureApp(summaryFlicker: true)
        let landmark = pushDetail(containing: "Alpha State", in: app)
        hold(landmark, seconds: 45,
             message: "ghost activation fired during a querying hold")
    }

    /// The discriminator: identical app state, but the hold issues no
    /// accessibility queries — one sleep, one final check.
    @MainActor
    func testGhostPushRepro_queryFreeHold() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GHOST_REPRO"] == "1",
                          "diagnostic for the iOS 26.5 ghost-activation artifact; set GHOST_REPRO=1 to run")
        let app = launchFixtureApp(summaryFlicker: true)
        let landmark = pushDetail(containing: "Alpha State", in: app)
        Thread.sleep(forTimeInterval: 45)
        XCTAssertTrue(landmark.exists,
                      "detail left the screen during a query-free hold")
    }

    /// The companion case the 2026-08-29 pass could never reach: the held
    /// game itself going final must keep the screen pushed (only its
    /// polling stops). `fx-fades` goes final on the 8th fetch.
    @MainActor
    func testDetailStaysPushedWhenGameGoesFinal() throws {
        let app = launchFixtureApp()
        let landmark = pushDetail(containing: "Charlie A&M", in: app)
        // Across the live → final flip plus post-final refresh cycles.
        hold(landmark, seconds: 20,
             message: "detail popped when the game went final")

        // The poll gate's own input, read off the running app: the header
        // renders the merged status, so "Final" here is the same `isLive`
        // flip that cancels the detail's poll loop. Queried once, after
        // the hold — a querying hold can ghost-activate nav controls
        // (CLAUDE.md), and this assertion doesn't need to run during one.
        let status = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Final"))
            .firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5),
                      "header never flipped to Final, so the poll never self-stopped")
    }
}
