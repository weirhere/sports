import XCTest

/// App Store screenshot capture — a sibling of ScreenshotTests, but aimed at
/// the store rather than design review. It shoots the current day live, so
/// the slate carries the app's whole argument: green live dots and running
/// clocks next to the finals, with the followed teams on top.
///
/// Run on the store devices (iPhone 17 Pro Max for 6.9", 16 Plus for 6.5")
/// with `-parallel-testing-enabled NO`, and export the attachments from the
/// xcresult with `xcresulttool export attachments`. Set the status bar first:
///
///     xcrun simctl status_bar <udid> override --time "9:41" \
///       --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
///
/// Out of season today is empty — pass `TEST_RUNNER_SCREENSHOT_SEASON=2025`
/// and `TEST_RUNNER_SCREENSHOT_DAY="Saturday, November 8"` (the day chip's
/// spoken label) to shoot a completed Saturday.
final class AppStoreScreenshots: XCTestCase {
    /// The launch every frame shares. `extra` is appended last, so a
    /// frame can switch a mode on (spoiler mode's keys, for one).
    @MainActor
    private func launchApp(extra: [String] = []) -> XCUIApplication {
        let env = ProcessInfo.processInfo.environment
        let app = XCUIApplication()
        app.launchArguments += ["-ui.appearance", "system",
                                // Every logo and headshot as a gray disc
                                // by default: the listing carries no third
                                // party's marks (4.1(a), 2026-09-29).
                                // SCREENSHOT_NEUTRAL_LOGOS=NO shoots the
                                // real marks (Andy's call, 2026-10-19).
                                "-screenshot.neutralLogos",
                                env["SCREENSHOT_NEUTRAL_LOGOS"] ?? "YES",
                                "-ui.onboardingSeen", "YES",
                                "-ui.liveOnly", "NO", "-ui.tightOnly", "NO",
                                "-ui.scoreFilter", "",
                                // Seed follows so the Following section leads
                                // with content (argument-domain array syntax).
                                // League-qualified since the namespacing
                                // migration — a bare id reads as nobody.
                                //
                                // Overridable, because the teams worth
                                // seeding depend on the day being shot: a
                                // both-leagues frame needs a follow in each
                                // league that actually played that day.
                                "-following.teamKeys",
                                env["SCREENSHOT_FOLLOWS"]
                                    ?? "(cfb:61, cfb:130, cfb:251)"]
        app.launchArguments += extra
        app.launch()
        return app
    }

    /// Walks the day strip to `SCREENSHOT_DAY` when it is set, then waits
    /// for the slate: a row with a score on it, or under
    /// `SCREENSHOT_PREGAME` any row at all.
    @MainActor
    private func landOnSlate(_ app: XCUIApplication) -> XCUIElementQuery {
        let env = ProcessInfo.processInfo.environment
        // No SCREENSHOT_SEASON any more: Scores carries no season control
        // since the view-options sheet retired — the day strip is bounded
        // by the current season and season selection lives on Leagues. Any
        // day of this season is reachable by name; a past season is not.
        if let day = env["SCREENSHOT_DAY"] {
            // Chips are addressed by their spoken label ("Saturday,
            // November 8"); the strip's HStack isn't lazy, so every day
            // button exists in the hierarchy even scrolled offscreen.
            let chip = app.buttons[day]
            let strip = app.scrollViews.containing(.button, identifier: day).firstMatch
            XCTAssertTrue(strip.waitForExistence(timeout: 15), "Day strip should load")
            XCTAssertTrue(scrollToAndTap(chip, in: strip, within: app.windows.firstMatch),
                          "\(day) should be reachable in the strip")
        }

        // Scores: expand nothing — Following and the slate's accordions
        // are open by default, which is the hero shot. Wait for a row that has
        // a score on it, so the slate isn't a screen of kickoff times.
        //
        // SCREENSHOT_PREGAME waives that, for the one frame that has to
        // show a day nobody has played yet: before the NFL's opening week
        // there is no played NFL game anywhere Scores can reach, and a
        // slate of kickoff times is the honest picture of that Sunday.
        let played = app.scrollViews.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", " left", "final"))
        if env["SCREENSHOT_PREGAME"] == nil {
            XCTAssertTrue(played.firstMatch.waitForExistence(timeout: 20),
                          "The day should show games with scores")
        } else {
            let anyRow = app.scrollViews.buttons.matching(NSPredicate(
                format: "label CONTAINS[c] %@", " at ")).firstMatch
            XCTAssertTrue(anyRow.waitForExistence(timeout: 20),
                          "The day should show its slate")
        }
        return played
    }

    @MainActor
    func testCaptureStoreScreenshots() throws {
        let env = ProcessInfo.processInfo.environment
        let app = launchApp()
        let played = landOnSlate(app)
        snapshot(app, "01-scores")

        // Pre-game mode shoots the slate and stops. Everything below needs
        // a played game — a box score, a line score, leaders — and a day
        // nobody has played has none of it.
        if env["SCREENSHOT_PREGAME"] != nil { return }

        // Game detail, off a completed game where there is one. The live
        // treatment is already the Scores shot's job; what the detail and box
        // score need is a game with a full stat line behind it, and a game in
        // the first quarter has almost nothing to show.
        // `SCREENSHOT_GAME` names the game by a word of its row label
        // ("Houston") so the box-score frame can be a football one
        // whatever sport the first final on the slate happens to be.
        let final = app.scrollViews.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@", "final")).firstMatch
        let game: XCUIElement
        if let word = env["SCREENSHOT_GAME"] {
            game = app.scrollViews.buttons.matching(NSPredicate(
                format: "label CONTAINS[c] %@", word)).firstMatch
            XCTAssertTrue(scrollUntilExists(game, in: app), "\(word) should be on the slate")
        } else {
            game = final.exists ? final : played.firstMatch
        }
        game.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        // Let line score / leaders finish loading before the shot.
        _ = app.staticTexts["Total"].waitForExistence(timeout: 8)
        snapshot(app, "02-game-detail")

        // Box score — 1.4.0's headline. The tab row is hidden entirely when a
        // game ships no player stats, so this shot is conditional.
        let boxScore = app.buttons["Box score"]
        if boxScore.waitForExistence(timeout: 5) {
            boxScore.tap()
            _ = app.staticTexts["Passing"].waitForExistence(timeout: 8)
            snapshot(app, "03-box-score")
        } else {
            XCTFail("No box score on \(game.label) — reshoot against a game with player stats")
        }
        app.navigationBars.buttons.firstMatch.tap()

        // Leagues.
        XCTAssertTrue(openRankingsPoll(in: app),
                      "The Top 25 row should push a poll with a ranked #1")
        snapshot(app, "04-rankings")

        // Teams: the seeded follows, one card each.
        XCTAssertTrue(openTab("Teams", in: app, until: app.buttons["Add teams"]),
                      "Teams should load")
        snapshot(app, "05-teams")

        // A team page, via the app-wide search tab.
        XCTAssertTrue(openTeamPage("Georgia Bulldogs", in: app),
                      "Search should land on the Georgia team page")
        snapshot(app, "06-team-page")
    }

    /// 2.9.0's surfaces (2026-10-19): the Roster tab's starters on the
    /// field, the News tab's Transfers page, and spoiler mode on the slate
    /// and the game page. `SCREENSHOT_GAME` names the game to open for the
    /// Roster frame by a word of its row label ("49ers"); without it the
    /// first played game is used, whatever sport it is.
    @MainActor
    func testCaptureFeatureFrames() throws {
        let env = ProcessInfo.processInfo.environment
        let app = launchApp()
        let played = landOnSlate(app)

        // Roster tab, on the named game.
        let target: XCUIElement
        if let word = env["SCREENSHOT_GAME"] {
            target = app.scrollViews.buttons.matching(NSPredicate(
                format: "label CONTAINS[c] %@", word)).firstMatch
        } else {
            target = played.firstMatch
        }
        XCTAssertTrue(scrollUntilExists(target, in: app), "The Roster frame's game should be on the slate")
        target.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        let roster = app.buttons["Roster"]
        XCTAssertTrue(roster.waitForExistence(timeout: 10), "The game page should offer a Roster tab")
        roster.tap()
        let starters = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] %@", "starters")).firstMatch
        XCTAssertTrue(starters.waitForExistence(timeout: 20), "The Starters card should load")
        // Headshots land after the card does.
        Thread.sleep(forTimeInterval: 4)
        snapshot(app, "09-roster")
        app.navigationBars.buttons.firstMatch.tap()

        // News → Transfers.
        let transfers = app.buttons["Transfers"]
        if openTab("News", in: app, until: transfers) {
            transfers.tap()
            Thread.sleep(forTimeInterval: 5)
            snapshot(app, "10-news-transfers")
        } else {
            XCTFail("News should offer a Transfers page")
        }

        // Spoiler mode: relaunch with the switch on for the followed
        // teams, nothing revealed. The followed rows read "score hidden".
        app.terminate()
        let hidden = launchApp(extra: ["-spoiler.hidesScores", "YES",
                                       "-spoiler.scope", "followed",
                                       "-spoiler.revealed", "{}"])
        _ = landOnSlate(hidden)
        let concealed = hidden.scrollViews.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@", "score hidden")).firstMatch
        XCTAssertTrue(concealed.waitForExistence(timeout: 20), "A followed team's row should hide its score")
        snapshot(hidden, "11-hide-scores")
        concealed.tap()
        let reveal = hidden.buttons["game-reveal-score"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 10), "The hidden game's page should offer Reveal score")
        Thread.sleep(forTimeInterval: 2)
        snapshot(hidden, "12-hide-scores-page")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
