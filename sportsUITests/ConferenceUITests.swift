import XCTest

/// Live-network walk of the conference standings flow: the Teams header's
/// context menu pushes ConferencePage (the trailing standings icon came
/// off browse headers in the P1 review), the follow pill toggles, and the
/// Scores headers keep their standings button.
///
/// Live-data rules apply (see CLAUDE.md): standings are a calendar fact —
/// preseason serves 0-0 rows and an offseason conference can be empty — so
/// the page assertion accepts either real rows or "Standings TBA", and
/// never a specific team, record, or row count.
final class ConferenceUITests: XCTestCase {
    @MainActor
    func testStandingsPageAndConferenceFollow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.scoresGrouping", "conference",
                                "-ui.liveOnly", "NO",
                                "-ui.scoreFilter", "",
                                // The cold-launch auto-pick opens on
                                // whichever league is live, so every
                                // live-ESPN suite pins one or it drifts.
                                "-ui.league", "cfb"]
        app.launch()

        // Teams tab: the first conference group's header reaches standings
        // through its context menu. ACC, not SEC — the browse list is a
        // LazyVStack, so a section below the fold doesn't exist as an
        // element yet, and ACC sorts first under tier-then-name (the
        // existing smoke test leans on it the same way). The landmark is
        // the search field, not a "ACC" text — Scores' conference grouping
        // renders an ACC accordion too, so a text query can read "landed"
        // while the app never left the Scores tab. Same reason the header
        // predicate pins " teams": Scores' header is "ACC, N games".
        XCTAssertTrue(openTab("Teams", in: app, until: app.searchFields.firstMatch),
                      "Teams should show its search field")
        let accHeader = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label ENDSWITH %@",
            "ACC,", " teams")).firstMatch
        XCTAssertTrue(accHeader.waitForExistence(timeout: 15),
                      "The ACC header toggle should exist")
        // The press is retried: a directory re-render mid-press invalidates
        // the element snapshot and the menu never opens.
        let standingsItem = app.buttons["View ACC standings"].firstMatch
        for _ in 0..<3 where !standingsItem.exists {
            guard accHeader.waitForExistence(timeout: 5) else { break }
            accHeader.press(forDuration: 1.0)
            _ = standingsItem.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(standingsItem.exists,
                      "The ACC header's context menu should offer standings")
        standingsItem.tap()

        // ConferencePage: hero, follow pill, and standings-or-TBA. The name
        // lives in the hero (TeamPage template), so the pill marks the
        // page. Rows collapse to one element (a button, via
        // NavigationLink), so query any descendant by label like
        // UITestSupport's topRankedRow does.
        let conferencePill = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@",
            "Follow conference", "Following conference")).firstMatch
        XCTAssertTrue(conferencePill.waitForExistence(timeout: 10),
                      "The standings item should push the ACC page")
        // The page lands on its Games tab (2026-08-29) — the table is one
        // tab over, behind the hero's Standings chip.
        let standingsTab = app.buttons["Standings"].firstMatch
        XCTAssertTrue(standingsTab.waitForExistence(timeout: 5),
                      "The ACC page should offer a Standings tab")
        standingsTab.tap()
        let anyRow = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ OR label == %@", " overall", "Standings TBA")).firstMatch
        XCTAssertTrue(anyRow.waitForExistence(timeout: 15),
                      "The page should show standings rows or the TBA state")

        // Follow round-trip: flip on, flip back off so the simulator's
        // persisted state stays clean for other tests. Follows persist on
        // the simulator, so normalize an already-following leftover first.
        // Every tap is verified by the label flipping and retried — a
        // standings or games fetch landing mid-tap re-renders the hero,
        // and the touch can miss the pill.
        let follow = app.buttons["Follow conference"].firstMatch
        let following = app.buttons["Following conference"].firstMatch
        if following.waitForExistence(timeout: 2) {
            for _ in 0..<3 where !follow.exists {
                guard following.exists else { break }
                following.tap()
                _ = follow.waitForExistence(timeout: 3)
            }
        }
        XCTAssertTrue(follow.waitForExistence(timeout: 5),
                      "The page should offer a conference follow pill")
        for _ in 0..<3 where !following.exists {
            guard follow.exists else { break }
            follow.tap()
            _ = following.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(following.exists, "Follow should flip to Following")
        for _ in 0..<3 where !follow.exists {
            guard following.exists else { break }
            following.tap()
            _ = follow.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(follow.exists, "Unfollow should flip back")

        // Scores headers carry the same affordance. Which conferences have
        // games is a calendar fact, but the section stack always renders
        // some conference during the season and the preseason slate; assert
        // any standings button rather than a specific conference's. The pop
        // targets the back button specifically — the follow pill rides the
        // toolbar now (2026-08-31), so an unqualified first match can
        // toggle it (dirtying the just-normalized state) instead of popping.
        let back = app.navigationBars.buttons.matching(NSPredicate(
            format: "NOT (label IN %@)",
            ["Follow conference", "Following conference"])).firstMatch
        XCTAssertTrue(tapUntilDismissed(back, dismissing: follow),
                      "Back should pop the conference page")
        // The funnel chip marks the Scores header — the season chip moved
        // inside the filter sheet (2026-08-29), so it's no longer visible
        // at rest.
        XCTAssertTrue(openTab("Scores", in: app, until: app.scoresFilterChip),
                      "Scores should render its header")
        // A followed conference pins a whole slate into Following, and Top
        // 25 stacks another ~20 games under it — the first conference
        // header can sit beyond any reasonable swipe budget. Collapsing
        // the two headline sections brings the conferences into reach;
        // their headers are always at the top and the collapse persists
        // exactly like a user's tap would.
        for prefix in ["Following,", "Top 25,"] {
            let header = app.buttons.matching(NSPredicate(
                format: "label BEGINSWITH %@ AND value == %@", prefix, "expanded")).firstMatch
            if header.waitForExistence(timeout: 3) {
                header.tap()
            }
        }
        let scoresStandings = app.buttons.matching(NSPredicate(
            format: "label ENDSWITH %@", " standings")).firstMatch
        XCTAssertTrue(scrollUntilExists(scoresStandings, in: app),
                      "A Scores conference header should carry a standings button")
    }

    @MainActor
    func testTablesListsTop25RowAndConferences() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES"]
        app.launch()

        // The root is the list: Top 25 row first, conferences right below.
        XCTAssertTrue(openTab("Tables", in: app, until: app.top25Row),
                      "Tables should lead with the Top 25 row")

        // An ACC row exists year-round (the list renders offseason, teasers
        // or not); its label is either bare "ACC" or "ACC, led by …".
        let accRow = app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ OR label BEGINSWITH %@", "ACC", "ACC, led by")).firstMatch
        XCTAssertTrue(scrollUntilExists(accRow, in: app, maxSwipes: 4, timeout: 5),
                      "Tables should list the ACC near the root")
        // The pushed page's landmark is the follow pill, not the nav bar:
        // ConferencePage went `.navigationTitle("")` with the hero template
        // (172155d), so the bar is never identified "ACC" anymore. The tap
        // is verified and retried — one issued mid-refresh can be swallowed
        // without the push ever starting.
        let conferencePill = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@",
            "Follow conference", "Following conference")).firstMatch
        for _ in 0..<3 where !conferencePill.exists {
            guard accRow.exists else { break }
            accRow.tap()
            _ = conferencePill.waitForExistence(timeout: 10)
        }
        XCTAssertTrue(conferencePill.exists,
                      "Tapping the conference row should push its standings page")

        // And the Top 25 row pushes the poll. The pop targets the back
        // button specifically — the follow pill rides the toolbar now
        // (2026-08-31), so an unqualified first match can toggle it
        // instead of popping; the pill vanishing proves the pop landed.
        // The root is a LazyVStack holding the ACC hunt's scroll position,
        // so the Top 25 row at the top may not exist yet — scroll up to it.
        let back = app.navigationBars.buttons.matching(NSPredicate(
            format: "NOT (label IN %@)",
            ["Follow conference", "Following conference"])).firstMatch
        XCTAssertTrue(tapUntilDismissed(back, dismissing: conferencePill),
                      "Back should pop the conference page")
        XCTAssertTrue(scrollUntilExists(app.top25Row, in: app,
                                        revealing: .above, timeout: 5),
                      "Popping back should land on the Tables list")
        app.top25Row.tap()
        XCTAssertTrue(app.topRankedRow.waitForExistence(timeout: 15),
                      "The Top 25 row should push a poll with a ranked #1")
    }
}
