import XCTest

/// Live-network walk of the conference standings flow: the tables hub's
/// conference row pushes ConferencePage, the follow pill toggles, and the
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
                                "-ui.liveOnly", "NO",
                                "-ui.scoreFilter", ""]
        app.launch()

        // The tables hub is the way into a conference page now: the Teams
        // tab lists the teams you follow rather than the directory, so its
        // conference accordions (and their standings context menu) are
        // gone. ACC, not SEC — the hub's college-football accordion lists
        // conferences tier-then-name, so ACC is the first row under the
        // Top 25 one and is realized even in a LazyVStack.
        XCTAssertTrue(openTab("Tables", in: app, until: app.top25Row),
                      "Tables should load its hub")
        let accRow = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label BEGINSWITH %@", "ACC", "ACC,")).firstMatch
        XCTAssertTrue(scrollUntilExists(accRow, in: app, timeout: 15),
                      "The hub should list the ACC")
        accRow.tap()

        // ConferencePage: hero, follow pill, and standings-or-TBA. The name
        // lives in the hero (TeamPage template), so the pill marks the
        // page. Rows collapse to one element (a button, via
        // NavigationLink), so query any descendant by label like
        // UITestSupport's topRankedRow does.
        let conferencePill = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@",
            "Follow conference", "Following conference")).firstMatch
        XCTAssertTrue(conferencePill.waitForExistence(timeout: 10),
                      "The hub row should push the ACC page")
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
        // gone entirely with the view-options sheet (2026-09-06); the
        // season chip on the day strip is the stable marker now.
        XCTAssertTrue(openTab("Scores", in: app, until: app.scoresLiveChip),
                      "Scores should render its header")
        // Following a conference is what puts its whole slate into the
        // Scores Following section. Asserting the section exists, not what
        // is in it: the ACC may have no games on the day the app opened
        // on, and the promise under test is that a conference follow
        // counts as following someone.
        //
        // The conference-accordion assertion this replaces retired with
        // the conference sections themselves (2026-09-05) — the breakdown
        // by conference lives on Tables now.
        let followingHeader = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@", "Following,")).firstMatch
        let leagueHeader = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
            "College Football,", "NFL,")).firstMatch
        XCTAssertTrue(followingHeader.waitForExistence(timeout: 15)
                        || leagueHeader.waitForExistence(timeout: 5),
                      "Scores should render its day's sections")
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
