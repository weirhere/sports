import XCTest

/// Spoiler mode on the scripted Saturday (E30, 2026-10-19). Runs against
/// `FixtureScoresClient` with Delta College followed: fx-fades (Charlie
/// A&M at Delta College) is live for its first eight fetches and then
/// final, 31–17 to Delta, so with the mode on its row has to hide both
/// states, its page has to open on Preview alone, and one tap on Reveal
/// has to bring the score back everywhere.
///
/// Both of the mode's keys are pinned from the argument domain. The
/// setting persists in the App Group suite by design, so without the pin
/// a suite would inherit whatever the last run — or whoever last used
/// this simulator — left switched; and a leftover reveal of fx-fades
/// would pre-reveal the game this test is about to reveal. Safe as
/// overrides because `SpoilerStore` reads both once in `init`.
final class SpoilerModeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchFixtureApp(scope: String = "followed") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui.onboardingSeen", "YES",
            "-ui.followPromptDismissed", "YES",
            "-ui.scoreFilter", "none",
            "-data.provider", "fixture",
            "-poll.interval", "0.5",
            // A reminder-tapped game arms the rating sheet; nothing here
            // taps one, but the sheet would eat the Reveal tap if it did.
            "-review.prompt", "off",
            // Delta College, fx-fades' home side (argument-domain array
            // syntax, league-qualified).
            "-following.teamKeys", "(cfb:fx-103)",
            "-spoiler.hidesScores", "YES",
            "-spoiler.scope", scope,
            "-spoiler.revealed", "{}",
        ]
        app.launch()
        return app
    }

    /// The fx-fades row, by its stable identifier — its label changes
    /// shape with the status and again on reveal.
    @MainActor
    private func fadesRow(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "scores-game-fx-fades").firstMatch
    }

    /// Waits for the row's label to satisfy `predicate`, polling once a
    /// second so the hold stays query-sparse (the ghost-activation rule).
    @MainActor
    private func waitForLabel(of element: XCUIElement, timeout: TimeInterval,
                              _ predicate: (String) -> Bool) -> String? {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if element.exists, predicate(element.label) { return element.label }
            Thread.sleep(forTimeInterval: 1)
        }
        return nil
    }

    /// Live and final both hide; the page opens on Preview alone; the
    /// reveal restores the score on the page and, on the way back, on
    /// the row.
    @MainActor
    func testFollowedGameHidesUntilRevealed() throws {
        let app = launchFixtureApp()
        let row = fadesRow(in: app)
        XCTAssertTrue(scrollUntilExists(row, in: app), "fx-fades row never appeared")

        // Live, concealed: the sentence says so and carries no score.
        let liveLabel = row.label
        XCTAssertTrue(liveLabel.contains("score hidden"), "live row not concealed: \(liveLabel)")
        XCTAssertFalse(liveLabel.contains("31") || liveLabel.contains("17"), "live row leaks: \(liveLabel)")

        // Final at tick 8 (~4s at the compressed poll): still concealed,
        // and the records are rewound a game — Delta's 2-0 reads 1-0,
        // Charlie's 0-2 reads 0-1.
        guard let finalLabel = waitForLabel(of: row, timeout: 20, { $0.contains("final") }) else {
            return XCTFail("fx-fades never went final; last label: \(row.label)")
        }
        XCTAssertTrue(finalLabel.contains("score hidden"), "final row not concealed: \(finalLabel)")
        XCTAssertFalse(finalLabel.contains("31"), "final row leaks the score: \(finalLabel)")
        XCTAssertTrue(finalLabel.contains("0 and 1") && finalLabel.contains("1 and 0"),
                      "records not rewound: \(finalLabel)")

        // Into the page by a settled-frame tap on the team names (the
        // leading half of the row — the status column is the reveal).
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: row.frame.minX + row.frame.width * 0.3, dy: row.frame.midY))
            .tap()
        let reveal = app.buttons["game-reveal-score"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 10), "concealed page shows no Reveal button")
        XCTAssertFalse(app.buttons["Share this game"].exists, "share offered on a concealed page")
        for tab in ["plays", "box score", "roster", "h2h", "news"] {
            XCTAssertFalse(app.buttons["hero-tab-\(tab)"].exists, "tab \(tab) offered on a concealed page")
        }

        // Reveal: the share button is the page's landmark for a shown score.
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: reveal.frame.midX, dy: reveal.frame.midY))
            .tap()
        XCTAssertTrue(app.buttons["Share this game"].waitForExistence(timeout: 10),
                      "reveal didn't bring the page back")
        XCTAssertFalse(reveal.exists, "Reveal button survived the reveal")

        // Back to Scores: the row now speaks the score.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(scrollUntilExists(row, in: app), "fx-fades row gone after the reveal")
        guard let shownLabel = waitForLabel(of: row, timeout: 10, { $0.contains("31") }) else {
            return XCTFail("revealed row still hides the score: \(row.label)")
        }
        XCTAssertTrue(shownLabel.contains("Delta College 31"), "revealed row: \(shownLabel)")
        XCTAssertFalse(shownLabel.contains("score hidden"))
    }

    /// An unfollowed game is untouched by the mode: fx-hold is always
    /// live and nobody follows either side.
    @MainActor
    func testUnfollowedGamesKeepTheirScores() throws {
        let app = launchFixtureApp()
        let hold = app.descendants(matching: .any).matching(identifier: "scores-game-fx-hold").firstMatch
        XCTAssertTrue(scrollUntilExists(hold, in: app), "fx-hold row never appeared")
        XCTAssertFalse(hold.label.contains("score hidden"), "unfollowed row concealed: \(hold.label)")
    }

    /// All games reaches the unfollowed slate too: the same fx-hold row
    /// hides under the wider scope.
    @MainActor
    func testAllGamesScopeHidesUnfollowedGames() throws {
        let app = launchFixtureApp(scope: "all")
        let hold = app.descendants(matching: .any).matching(identifier: "scores-game-fx-hold").firstMatch
        XCTAssertTrue(scrollUntilExists(hold, in: app), "fx-hold row never appeared")
        XCTAssertTrue(hold.label.contains("score hidden"), "All games left fx-hold showing: \(hold.label)")
        XCTAssertTrue(hold.label.contains("live"), "fx-hold should still say it is live: \(hold.label)")
    }
}
