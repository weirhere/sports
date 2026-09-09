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

        // Scores loads a real slate as a stack of accordions. Which ones
        // depends on the day and the follow set — a September Saturday is
        // college football's conferences, a Sunday is the NFL's single
        // section — so the assertion names none of them and matches on the
        // identifier every Scores section shares.
        let anyLeague = app.anyScoresSection
        XCTAssertTrue(anyLeague.waitForExistence(timeout: 20),
                      "Scores should show at least one section accordion")
        snapshot(app, "scores-day")

        // The accordion collapses and reopens, and the state is the user's
        // to keep — every section but Following starts open and remembers
        // being closed.
        let wasExpanded = anyLeague.value as? String == "expanded"
        anyLeague.tap()
        XCTAssertNotEqual(anyLeague.value as? String,
                          wasExpanded ? "expanded" : "collapsed",
                          "Tapping a section header should toggle it")
        anyLeague.tap()

        // The day strip walks the season. Yesterday always exists inside
        // it, and the floating Today button is the way back — it only
        // appears once the strip has wandered far enough that the Today
        // chip itself is off screen — three days out (2026-09-07) — so one
        // swipe is deliberately not enough.
        let today = app.buttons["scores-today-jump"]
        XCTAssertFalse(today.exists, "The Today button should be hidden on today")
        app.swipeLeft()
        XCTAssertFalse(today.exists,
                       "One day out, the Today chip is still on the strip")
        for _ in 0..<2 { app.swipeLeft() }
        XCTAssertTrue(today.waitForExistence(timeout: 10),
                      "Swiping past the Today chip should offer the way back")
        today.tap()
        // XCUIElement has no wait-for-absence, and the button disappearing
        // *is* the assertion — the screen only offers it off today.
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
        XCTAssertTrue(openTab("Games", in: app, until: app.scoresLiveChip),
                      "Scores should render its header")
        let followingHeader = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@", "Following,")).firstMatch

        // Following holds *this day's* followed games (2026-09-06), so the
        // section only exists on a day the followed team plays — and a
        // college team plays once a week. Asserting it on whatever day the
        // test happens to run is a calendar fact, and a false one every
        // Sunday: Georgia plays Saturdays.
        //
        // So walk back a day at a time until it turns up. The drag starts
        // well clear of the left edge — a rightward swipe that begins near
        // it is the system's back gesture, not a day step.
        var foundFollowing = false
        for step in 0...7 {
            if scrollUntilExists(followingHeader, in: app,
                                 revealing: .above, timeout: step == 0 ? 10 : 3) {
                foundFollowing = true
                break
            }
            let y = app.frame.height * 0.5
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.width * 0.35, dy: y))
                .press(forDuration: 0.1,
                       thenDragTo: origin.withOffset(
                        CGVector(dx: app.frame.width * 0.92, dy: y)),
                       withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(foundFollowing,
                      "Following should appear on a day the followed team plays")
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
