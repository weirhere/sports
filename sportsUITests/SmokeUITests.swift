import XCTest

/// Live-network smoke test: every tab renders real data, and following a
/// team from the Add teams sheet makes the Following section appear on
/// Scores.
final class SmokeUITests: XCTestCase {
    @MainActor
    func testTabsAndFollowFlow() throws {
        let app = XCUIApplication()
        // A fresh simulator would otherwise get the pick-your-teams sheet;
        // the arg lands in UserDefaults' argument domain and marks it seen.
        // The Scores filters persist across launches by design, so every
        // suite that queries game rows pins them or it inherits whatever
        // the last run left selected.
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.liveOnly", "NO",
                                "-ui.scoreFilter", ""]
        app.launch()

        // Scores loads a real slate as one accordion per league. At least
        // one of them has to be there — which one depends on the day, so
        // the assertion names neither: a September Saturday is college
        // football only, a September Sunday is the NFL only.
        //
        // Deliberately not asserting on the day: whichever day the app
        // opens on, the leagues are its sections.
        let anyLeague = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
            "College Football,", "NFL,")).firstMatch
        XCTAssertTrue(anyLeague.waitForExistence(timeout: 20),
                      "Scores should show at least one league accordion")
        snapshot(app, "scores-day")

        // The accordion collapses and reopens, and the state is the user's
        // to keep — league sections start open and remember being closed.
        let wasExpanded = anyLeague.value as? String == "expanded"
        anyLeague.tap()
        XCTAssertNotEqual(anyLeague.value as? String,
                          wasExpanded ? "expanded" : "collapsed",
                          "Tapping a league header should toggle it")
        anyLeague.tap()

        // The day strip walks the season. Yesterday always exists inside
        // it, and the Today chip is the way back — it only appears once
        // the strip has wandered off today.
        let today = app.buttons["day-strip-today"]
        XCTAssertFalse(today.exists, "The Today chip should be hidden on today")
        app.swipeLeft()
        XCTAssertTrue(today.waitForExistence(timeout: 10),
                      "Swiping to another day should offer the way back")
        today.tap()
        // XCUIElement has no wait-for-absence, and the chip disappearing
        // *is* the assertion — the strip only offers it off today.
        let goneExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: today)
        XCTAssertEqual(XCTWaiter().wait(for: [goneExpectation], timeout: 10), .completed,
                       "Tapping Today should return the strip home")

        // Tables leads with the Top 25 row; the poll itself is one tap
        // down. Which poll depends on the calendar — the AP preseason Top
        // 25 doesn't drop until mid-August.
        XCTAssertTrue(openRankingsPoll(in: app),
                      "The Top 25 row should push a poll with a ranked #1")
        snapshot(app, "rankings")

        // Teams: the tab lists the teams you follow, and joining one goes
        // through the Add teams sheet (2026-09-05). Tolerates an
        // already-followed Georgia from a previous run — follows persist
        // on the simulator.
        XCTAssertTrue(followTeam("Georgia Bulldogs", in: app),
                      "The Add teams sheet should follow Georgia")
        let card = app.teamCard("Georgia Bulldogs")
        XCTAssertTrue(card.waitForExistence(timeout: 10),
                      "A followed team should get a card of its own")
        snapshot(app, "teams")

        // The card pushes the team page.
        card.tap()
        XCTAssertTrue(app.buttons["Following"].firstMatch.waitForExistence(timeout: 10),
                      "The card should push the followed team's page")
        snapshot(app, "team-page")

        // Scores now leads with the Following section — but the list kept
        // its scroll position from the SEC hunt above, and on a full slate
        // Following sits screens higher, outside the LazyVStack's realized
        // range. Scroll back up to it.
        // openTab, not a bare tab tap: a tap issued while the team-page
        // push is still settling gets swallowed, and the hunt below then
        // swipes the team page instead of the scores list.
        XCTAssertTrue(openTab("Scores", in: app, until: app.scoresLiveChip),
                      "Scores should render its header")
        let followingHeader = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@", "Following,")).firstMatch
        XCTAssertTrue(scrollUntilExists(followingHeader, in: app,
                                        revealing: .above, timeout: 10),
                      "Following section should appear once a team is followed")
        // The collapse at the top of this test (or a persisted user tap)
        // leaves the section closed, and a collapsed section's rows don't
        // exist as elements — expand it before hunting the game row.
        if followingHeader.value as? String == "collapsed" {
            followingHeader.tap()
        }
        snapshot(app, "scores-following")

        // Into a game detail from the Following section.
        // By the row's combined label, not an inner static text: GameRow is
        // `.accessibilityElement(children: .ignore)`, so its texts aren't
        // queryable descendants (iOS 18's XCUITest leaked them; iOS 26's
        // doesn't). The lookahead keeps Georgia Tech/State/Southern rows —
        // possible via a followed conference — from matching.
        let gameLink = app.buttons.matching(NSPredicate(
            format: "label MATCHES %@", ".*Georgia(?! (Tech|State|Southern)).*")).firstMatch
        XCTAssertTrue(gameLink.waitForExistence(timeout: 5), "Following should list a Georgia game row")
        gameLink.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10),
                      "Tapping a game row should push the game detail")
        snapshot(app, "game-detail")

        // Header team column pushes the team page. Asserting on the Following
        // pill (Georgia was followed above), not the schedule — the schedule
        // section is calendar-dependent.
        let teamButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Georgia")).firstMatch
        XCTAssertTrue(teamButton.waitForExistence(timeout: 10),
                      "Game detail header should have a Georgia team button")
        teamButton.tap()
        XCTAssertTrue(app.buttons["Following"].firstMatch.waitForExistence(timeout: 10),
                      "Team header tap should push the team page")
        snapshot(app, "team-page-from-game")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
