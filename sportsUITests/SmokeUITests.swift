import XCTest

/// Live-network smoke test: every tab renders real data, and following a
/// team from browse makes the Following section appear on Scores.
final class SmokeUITests: XCTestCase {
    @MainActor
    func testTabsAndFollowFlow() throws {
        let app = XCUIApplication()
        // A fresh simulator would otherwise get the pick-your-teams sheet;
        // the arg lands in UserDefaults' argument domain and marks it seen.
        // Grouping is pinned to conference the same way — the test asserts
        // conference headers, and the sim may have "by date" persisted.
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.scoresGrouping", "conference",
                                "-ui.liveOnly", "NO",
                                "-ui.scoreFilter", "",
                                // The cold-launch auto-pick opens on
                                // whichever league is live, so every
                                // live-ESPN suite pins one or it drifts.
                                "-ui.league", "cfb"]
        app.launch()

        // Scores loads a real slate. Persisted follows can swell Following
        // (and Top 25 stacks ~20 games under it) far enough that SEC sits
        // past any reasonable swipe budget on a full Saturday, so collapse
        // the headline sections first — ConferenceUITests does the same,
        // and the state persists exactly like a user's tap would. The
        // longer first wait covers the initial slate load.
        for (index, prefix) in ["Following,", "Top 25,"].enumerated() {
            let header = app.buttons.matching(NSPredicate(
                format: "label BEGINSWITH %@ AND value == %@", prefix, "expanded")).firstMatch
            if header.waitForExistence(timeout: index == 0 ? 10 : 3) {
                header.tap()
            }
        }
        XCTAssertTrue(scrollUntilExists(app.staticTexts["SEC"], in: app),
                      "Scores should show the SEC section header")

        // Grouping toggle, now inside the filter sheet: by date swaps
        // conference sections for day sections; toggling back restores the
        // conference stack. The funnel chip lives in the fixed header, so
        // it stays hittable after scrolling.
        XCTAssertTrue(setScoresGrouping(byDate: true, in: app),
                      "The filter sheet should offer the By date segment")
        let dayHeader = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@", "(Mon|Tues|Wednes|Thurs|Fri|Satur|Sun)day.*")).firstMatch
        XCTAssertTrue(scrollUntilExists(dayHeader, in: app, timeout: 5),
                      "Date grouping should show a day section header")
        snapshot(app, "scores-by-date")
        XCTAssertTrue(setScoresGrouping(byDate: false, in: app),
                      "The filter sheet should offer the By conference segment")
        // Both directions: the list keeps the day-header hunt's scroll
        // offset across the grouping switch, which can land past SEC —
        // a downward-only hunt then walks away from it.
        let sec = app.staticTexts["SEC"]
        XCTAssertTrue(scrollUntilExists(sec, in: app, timeout: 5)
                        || scrollUntilExists(sec, in: app, revealing: .above, timeout: 2),
                      "Toggling back should restore conference sections")

        // Rankings leads with the Top 25 row; the poll itself is one tap
        // down. Which poll depends on the calendar — the AP preseason Top
        // 25 doesn't drop until mid-August.
        XCTAssertTrue(openRankingsPoll(in: app),
                      "The Top 25 row should push a poll with a ranked #1")
        snapshot(app, "rankings")

        // Teams browse + search + follow. The landmark is the search field:
        // an "ACC" text exists on the Scores tab too (conference grouping),
        // so it can't prove the tab switch landed.
        XCTAssertTrue(openTab("Teams", in: app, until: app.searchFields.firstMatch),
                      "Teams should show its search field")
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Georgia Bulldogs")
        let row = app.staticTexts["Georgia"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Search should surface Georgia")
        row.tap()

        // Team page: follow (tolerate an already-followed state from a
        // previous run — follows persist on the simulator).
        let follow = app.buttons["Follow"].firstMatch
        if follow.waitForExistence(timeout: 10) {
            follow.tap()
        }
        XCTAssertTrue(app.buttons["Following"].firstMatch.waitForExistence(timeout: 5),
                      "Follow should flip to Following")
        snapshot(app, "team-page")

        // Scores now leads with the Following section — but the list kept
        // its scroll position from the SEC hunt above, and on a full slate
        // Following sits screens higher, outside the LazyVStack's realized
        // range. Scroll back up to it.
        // openTab, not a bare tab tap: a tap issued while the team-page
        // push is still settling gets swallowed, and the hunt below then
        // swipes the team page instead of the scores list.
        XCTAssertTrue(openTab("Scores", in: app, until: app.scoresFilterChip),
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
