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
                                  conferenceGrouping: Bool = false,
                                  summaryFlicker: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui.onboardingSeen", "YES",
            "-ui.liveOnly", liveOnly ? "YES" : "NO",
            "-ui.followPromptDismissed", "YES",
            "-data.provider", "fixture",
            "-poll.interval", "0.5",
        ]
        if conferenceGrouping {
            app.launchArguments += ["-ui.scoresGrouping", "conference"]
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
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
        XCTAssertTrue(scrollUntilExists(row, in: app), "fixture row \(text) never appeared")
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: row.frame.midX, dy: row.frame.midY))
            .tap()
        let landmark = app.buttons["Share this game"]
        XCTAssertTrue(landmark.waitForExistence(timeout: 10), "game detail never presented")
        return landmark
    }

    /// Asserts the detail stays up until `deadline`, checking every second.
    @MainActor
    private func hold(_ landmark: XCUIElement, seconds: TimeInterval,
                      message: String) {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 1)
            XCTAssertTrue(landmark.exists, message)
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
        let app = launchFixtureApp(liveOnly: true, conferenceGrouping: true)
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
