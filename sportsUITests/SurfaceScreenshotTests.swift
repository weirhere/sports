import XCTest

/// A camera for the parallel-ui skill, not a test of behaviour: one game
/// page per sport — football's field, basketball's court, hockey's rink —
/// plus the Scores slate and each team page on the way, so a UI PR can
/// show its change on every surface the app paints. Appearance comes
/// from the simulator (`xcrun simctl ui <udid> appearance dark`) and the
/// shots are named through `TEST_RUNNER_SNAPSHOT_PREFIX` (`light`/`dark`).
///
/// Which game is shot is a calendar fact, so the suite doesn't pick one
/// by id: it searches for a team (`SHOT_TEAM_CFB` / `_NBA` / `_NHL` /
/// `_NFL`, with sensible defaults), opens its Games tab and taps the
/// first played game — the page with the most on it. The app relaunches
/// between leagues: the search field keeps its text otherwise, and a
/// clean launch is cheaper than clearing it.
///
/// A surface that can't be reached is logged as `MISSING SURFACE …` and
/// the walk continues. `SHOT_STRICT=1` turns those into failures.
final class SurfaceScreenshotTests: XCTestCase {

    private static let defaultTeams = [
        "cfb": "Georgia Bulldogs",
        "nfl": "Kansas City Chiefs",
        "nba": "Boston Celtics",
        "nhl": "Boston Bruins",
    ]

    /// The sport, which is what a reviewer thinks in; the league is the
    /// app's unit.
    private static let surfaceNames = [
        "cfb": "football",
        "nfl": "nfl",
        "nba": "basketball",
        "nhl": "hockey",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testShootEachSportsSurface() throws {
        let env = ProcessInfo.processInfo.environment
        let prefix = env["SNAPSHOT_PREFIX"] ?? "shot"
        let leagues = (env["SHOT_LEAGUES"] ?? "cfb,nba,nhl")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var missing: [String] = []

        // The slate first, in whatever state the day is in.
        let app = launch()
        if app.anyScoresSection.waitForExistence(timeout: 20) {
            snapshot(app, "\(prefix)-scores")
        } else {
            missing.append("scores: no section loaded in 20s")
        }

        for league in leagues {
            let surface = Self.surfaceNames[league] ?? league
            let team = env["SHOT_TEAM_\(league.uppercased())"].flatMap { $0.isEmpty ? nil : $0 }
                ?? Self.defaultTeams[league] ?? league

            let app = launch()
            guard openTeamPage(team, in: app) else {
                missing.append("\(surface): search never landed on \(team)")
                continue
            }
            snapshot(app, "\(prefix)-\(surface)-team")

            let gamesTab = app.buttons["hero-tab-games"]
            guard gamesTab.waitForExistence(timeout: 10) else {
                missing.append("\(surface): \(team) has no Games tab")
                continue
            }
            gamesTab.tap()

            // A played game first — won / lost / final / live — since that
            // page carries the line score, the leaders and the box score;
            // any scheduled game if the season hasn't started.
            let played = app.scrollViews.buttons.matching(NSPredicate(
                format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@",
                ", won ", ", lost ", ", final", ", live")).firstMatch
            let scheduled = app.scrollViews.buttons.matching(NSPredicate(
                format: "label CONTAINS %@ OR label CONTAINS %@", ", versus ", ", at ")).firstMatch
            let row = played.waitForExistence(timeout: 15) ? played : scheduled
            guard row.waitForExistence(timeout: 5), bringOnScreen(row, in: app) else {
                missing.append("\(surface): no game row on \(team)'s Games tab")
                continue
            }
            row.tap()
            guard app.buttons["hero-tab-row"].waitForExistence(timeout: 15)
                    || app.navigationBars.firstMatch.waitForExistence(timeout: 5) else {
                missing.append("\(surface): game page never presented")
                continue
            }
            settle(3)
            snapshot(app, "\(prefix)-\(surface)-game")

            // The Roster tab's painted field / court / rink, where the
            // game offers one (ESPN names no starters for hockey).
            let roster = app.buttons["hero-tab-roster"]
            if roster.waitForExistence(timeout: 3) {
                roster.tap()
                settle(2)
                snapshot(app, "\(prefix)-\(surface)-game-roster")
            }
        }

        for line in missing { print("MISSING SURFACE \(line)") }
        if env["SHOT_STRICT"] == "1", !missing.isEmpty {
            XCTFail("Surfaces not captured: \(missing.joined(separator: "; "))")
        }
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui.appearance", "system",
            "-ui.onboardingSeen", "YES",
            "-ui.followPromptDismissed", "YES",
            "-ui.liveOnly", "NO", "-ui.tightOnly", "NO",
            "-ui.scoreFilter", "none",
            "-review.prompt", "off",
        ]
        app.launch()
        return app
    }

    /// Swipes the page up until the row sits wholly on screen, so the tap
    /// lands on it rather than throwing "activation point invalid".
    @MainActor
    private func bringOnScreen(_ element: XCUIElement, in app: XCUIApplication,
                               maxSwipes: Int = 8) -> Bool {
        let window = app.windows.firstMatch
        for _ in 0..<maxSwipes {
            guard element.exists else { return false }
            let floor = app.tabBars.firstMatch.exists
                ? app.tabBars.firstMatch.frame.minY : window.frame.maxY
            if element.frame.minY >= window.frame.minY, element.frame.maxY <= floor {
                return true
            }
            app.scrollViews.firstMatch.swipeUp()
        }
        return element.exists && element.isHittable
    }

    @MainActor
    private func settle(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
