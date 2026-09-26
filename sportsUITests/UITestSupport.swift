import XCTest

/// Shared queries for the UI tests. Both live-data walks (SmokeUITests,
/// ScreenshotTests, AppStoreScreenshots) hit the same two rough edges: which
/// polls exist depends on the calendar, and the season menu is a SwiftUI
/// `Menu` that a mid-load re-render can dismiss out from under the tap.
extension XCUIApplication {
    /// The #1 row of whichever poll PollScreen is showing — proof the poll
    /// rendered real data.
    ///
    /// Don't reach for the poll chips instead. They're the wrong landmark
    /// twice over: the picker only renders when more than one poll exists
    /// (`PollScreen.body`), and which polls exist is a calendar fact —
    /// the preseason AP Top 25 doesn't drop until mid-August, so for most of
    /// the year the feed carries only the Coaches poll and no chips appear.
    /// The label shape comes from `RankRow.accessibilitySummary`.
    var topRankedRow: XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Number 1,"))
            .firstMatch
    }

    /// The Top 25 row leading the Leagues list. By identifier, not label —
    /// the Scores tab's "Top 25, N games" accordion header lives in the
    /// same element tree and label queries cross tab hierarchies.
    var top25Row: XCUIElement {
        descendants(matching: .any)
            .matching(identifier: "rankings-top25-row").firstMatch
    }

    /// The season picker's menu button in the filter sheet, labeled with
    /// the selected year.
    var seasonChip: XCUIElement {
        descendants(matching: .any).matching(identifier: "season-chip").firstMatch
    }

    /// The Scores header's Live chip — the one control left there, and so
    /// the stable "Scores has rendered" marker. It replaced the
    /// view-options funnel, which retired with its sheet.
    var scoresLiveChip: XCUIElement {
        descendants(matching: .any).matching(identifier: "scores-live-chip").firstMatch
    }

    /// Any section accordion on the Scores screen, by identifier prefix.
    ///
    /// Not by label: which sections exist is a calendar fact and, since
    /// 2026-09-06, a follow-set fact too — a September Saturday is a stack
    /// of college-football conferences, a Sunday is the NFL's one
    /// accordion, and a followed table hoists a section above both. The
    /// identifier prefix is the one thing every Scores section shares
    /// (`SectionAccordion`).
    var anyScoresSection: XCUIElement {
        buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@",
                                     "scores-section-")).firstMatch
    }

    /// The topmost Scores section header that sits wholly on screen above
    /// the tab bar, pinned by its identifier. `anyScoresSection` is the
    /// first in the accessibility tree, which isn't the first on screen:
    /// since every league and conference lists below Hide all
    /// (2026-09-26), a lazy stack of ~30 sections handed back one parked
    /// under the tab bar, and `isHittable` still vouches for headers far
    /// below the fold. Frames don't lie, so this reads them. Pinned by
    /// identifier rather than index so the query can't slide onto a
    /// neighbour when the toggle re-renders. Call once the list has loaded
    /// (wait on `anyScoresSection` first).
    var reachableScoresSection: XCUIElement {
        let sections = buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@",
                                                    "scores-section-"))
        let window = windows.firstMatch.frame
        let floor = tabBars.firstMatch.exists ? tabBars.firstMatch.frame.minY : window.maxY
        let onScreen = sections.allElementsBoundByIndex
            .map { (id: $0.identifier, frame: $0.frame) }
            .filter { $0.frame.minY >= window.minY && $0.frame.maxY <= floor && !$0.frame.isEmpty }
            .min { $0.frame.minY < $1.frame.minY }
        guard let id = onScreen?.id, !id.isEmpty else { return sections.firstMatch }
        return buttons[id]
    }

    /// ConferencePage's follow pill, in either state — the page's
    /// landmark, since its name lives in the hero rather than the bar.
    var conferenceFollowPill: XCUIElement {
        buttons.matching(NSPredicate(format: "label == %@ OR label == %@",
                                     "Follow conference", "Following conference")).firstMatch
    }

    /// One named Scores section, by the title its header speaks —
    /// "SEC, 6 games".
    func scoresSection(_ title: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(title),")).firstMatch
    }

    /// A followed team's card on the Teams tab. The card speaks its name
    /// and the group it plays in ("Georgia Bulldogs, SEC"), so the match
    /// is a prefix — the sheet's rows carry the bare name.
    func teamCard(_ name: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }
}

extension XCTestCase {
    /// Opens the Leagues tab and drills into the poll: tab → Top 25 row →
    /// PollScreen's #1 row. The poll moved one level down when the hub
    /// became the tables hub, so every "show me the poll" test goes
    /// through here.
    @MainActor
    @discardableResult
    func openRankingsPoll(in app: XCUIApplication) -> Bool {
        // The landmark is the league's own accordion header, not the Top 25
        // row inside it: the hub's sections open **closed** as of
        // 2026-09-21, so the row is not in the tree on arrival and waiting
        // for it waits forever.
        let cfbSection = app.descendants(matching: .any)
            .matching(identifier: "tables-league-cfb").firstMatch
        guard openTab("Leagues", in: app, until: cfbSection) else { return false }
        // Asked of the tree rather than of the header's "collapsed" value,
        // so this keeps working whichever way the section starts — the
        // default has now flipped once and could flip back.
        if !app.top25Row.exists { cfbSection.tap() }
        guard app.top25Row.waitForExistence(timeout: 10) else { return false }
        app.top25Row.tap()
        return app.topRankedRow.waitForExistence(timeout: 15)
    }

    /// Opens a college conference's page from the Leagues tab: tab →
    /// college football's accordion → the conference's row → the page,
    /// landmarked by its follow pill.
    ///
    /// Two traps, both of which broke `ConferenceUITests` for a while.
    /// The hub's accordions open **closed** (2026-09-21), so the row isn't
    /// in the tree until the league's header is tapped. And a loose
    /// `BEGINSWITH "ACC,"` also matches the Scores tab's "ACC, NCAAF, 10
    /// games" header, which stays in the hierarchy behind the Leagues tab —
    /// tapping it does nothing you can see. The hub row only ever speaks
    /// "ACC" or "ACC, led by …", so that's all this matches.
    @MainActor
    @discardableResult
    func openCollegeConference(_ name: String, in app: XCUIApplication) -> Bool {
        let cfbSection = app.descendants(matching: .any)
            .matching(identifier: "tables-league-cfb").firstMatch
        guard openTab("Leagues", in: app, until: cfbSection) else { return false }
        let row = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label BEGINSWITH %@", name, "\(name), led by")).firstMatch
        // Asked of the tree rather than the header's value, as
        // `openRankingsPoll` does, so either default keeps working.
        if !row.exists { cfbSection.tap() }
        guard scrollUntilExists(row, in: app, timeout: 10) else { return false }
        // Verified and retried: a standings fetch landing mid-tap can
        // swallow the push.
        let pill = app.conferenceFollowPill
        for _ in 0..<3 where !pill.exists {
            guard row.exists else { break }
            row.tap()
            _ = pill.waitForExistence(timeout: 10)
        }
        return pill.exists
    }

    /// Opens the Add teams sheet from the Teams tab.
    ///
    /// The Teams tab is the list of teams you follow (2026-09-05), so
    /// joining one goes through this sheet rather than the browse
    /// accordions that used to live on the tab. The sheet's field carries
    /// its own identifier — the app-wide search tab has one too, and
    /// `searchFields.firstMatch` would be ambiguous whenever both are in
    /// the hierarchy.
    @MainActor
    @discardableResult
    func openAddTeamsSheet(in app: XCUIApplication) -> Bool {
        let add = app.buttons["Add teams"].firstMatch
        guard openTab("Teams", in: app, until: add) else { return false }
        // Retried like every other tap here: a directory re-render lands
        // mid-tap and the sheet never opens.
        for _ in 0..<3 {
            guard add.waitForExistence(timeout: 5) else { break }
            add.tap()
            if app.searchFields["search.addTeams"].waitForExistence(timeout: 5) { return true }
        }
        return false
    }

    /// Follows a team through the Add teams sheet: opens the sheet,
    /// searches for the team by name, follows it, and returns once its
    /// card is on the Teams tab. A no-op follow if a previous run already
    /// followed it (follows persist on the simulator).
    ///
    /// `name` is the team's full display name — "Georgia Bulldogs" — which
    /// is what search matches, what the row says, and now what the star
    /// says too. It took a separate `location` argument until 2026-09-21,
    /// when the row stopped setting a location against a nickname.
    @MainActor
    @discardableResult
    func followTeam(_ name: String,
                    in app: XCUIApplication) -> Bool {
        guard openAddTeamsSheet(in: app) else { return false }
        let field = app.searchFields["search.addTeams"]
        field.tap()
        field.typeText(name)
        // The star follows; the row beside it does not. The sheet's rows
        // split in 2.2.0 (the `opensTeam` shape): the body became a
        // NavigationLink into the team page, so tapping the row navigates
        // and follows nothing — which is exactly how this helper failed,
        // silently, for a whole release.
        //
        // The star is labelled with the team's **full name**, and took a
        // bare location until 2026-09-21: the Add teams row now names a
        // team in one string ("Georgia Bulldogs"), so `TeamFollowRow`
        // spends `team.displayName` where it used to spend `team.location`.
        // Note this is the sheet's rule and not the app's — `SectionAccordion`
        // and `RankRow` still label their stars by location, so a helper
        // driving *those* surfaces must not copy this.
        let star = app.buttons["Follow \(name)"].firstMatch
        let following = app.buttons["Unfollow \(name)"].firstMatch
        guard star.waitForExistence(timeout: 10) || following.exists else {
            return false
        }
        // One tap, confirmed on the tab behind rather than in the sheet.
        // A retry loop would tap into nothing: the first follow of all
        // raises the kickoff-reminder offer, and SwiftUI closes the sheet
        // to present it (both are anchored to the same view), taking the
        // star's element with it.
        if star.exists { star.tap() }
        // Still up whenever nothing interrupted — leave it the way a user
        // would.
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 2) { done.tap() }
        return app.teamCard(name).waitForExistence(timeout: 10)
    }

    /// Lands on a team's page through the app-wide search tab — the route
    /// to a team page for a team you don't already follow, now that the
    /// Teams tab lists follows rather than the whole directory.
    @MainActor
    @discardableResult
    func openTeamPage(_ name: String, in app: XCUIApplication) -> Bool {
        let field = appWideSearchField(in: app)
        guard openTab("Search", in: app, until: field) else { return false }
        // Tap the settled frame rather than the element: `focusOnAppear`
        // means SwiftUI may still be installing focus when the query first
        // resolves, and a tap that lands mid-rebuild misses.
        guard waitForHittable(field, timeout: 10) else { return false }
        field.tap()
        field.typeText(name)
        // A prefix, not the bare name: a search result says which league it
        // found ("Georgia Bulldogs, CFB" — 2026-09-07), because one
        // "Cleveland Browns" tells you nothing about which football you
        // found. An exact-label query stopped matching the day that landed.
        let result = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        guard result.waitForExistence(timeout: 10) else { return false }
        result.tap()
        // The Router intent switches to the Teams tab and pushes the page;
        // Follow may already read Following from a prior run.
        return app.buttons["Follow"].firstMatch.waitForExistence(timeout: 10)
            || app.buttons["Following"].firstMatch.waitForExistence(timeout: 5)
    }

    /// Waits for an element to become hittable, not merely to exist.
    ///
    /// `waitForExistence` answers a different question: a SwiftUI view can
    /// resolve in the accessibility tree a frame before it is tappable, and
    /// a tap in that window throws rather than missing quietly.
    @MainActor
    @discardableResult
    func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isHittable { return true }
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")],
                               timeout: 0.2)
        }
        return element.isHittable
    }

    /// The app-wide search field, found by identifier across element types.
    ///
    /// `SearchField` is a SwiftUI `TextField` wearing `.isSearchField` as a
    /// trait (`SearchField.swift`). A trait is not a type: XCUITest resolved
    /// that pairing as `.searchField` for years, and on iOS 26.5 it reports
    /// `.textField` instead, so `app.searchFields["search.appWide"]` matches
    /// nothing and the failure reads as the app having lost its search box.
    /// Found 2026-09-21 on `HeroTabFitUITests`' first ever run.
    ///
    /// Matching on the identifier alone rather than picking the other type
    /// is the point: this has now moved once, so a query that survives it
    /// moving back is worth more than one pinned to today's answer.
    @MainActor
    func appWideSearchField(in app: XCUIApplication) -> XCUIElement {
        // Constrained to the two types the field can report as. A bare
        // identifier match over `.any` also catches the container that
        // carries it, and a container is never hittable — which fails in a
        // way that reads exactly like the field being missing.
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier == %@ AND (elementType == %d OR elementType == %d)",
                "search.appWide",
                XCUIElement.ElementType.searchField.rawValue,
                XCUIElement.ElementType.textField.rawValue))
            .firstMatch
    }

    /// Which way an off-screen element is expected to lie.
    enum ScrollReveal { case below, above }

    /// Waits for `element`, swiping through the list if it hasn't materialized.
    ///
    /// The Scores stack is a LazyVStack, and a followed conference swells
    /// Following to a whole slate — sections that used to sit at the top
    /// (SEC, the first day header) can be screens below the fold, where
    /// their elements don't exist yet. Persisted follows are real user
    /// state, so any assertion about a section must be willing to scroll.
    /// A full in-season Saturday slate runs ~99 games, so the swipe budget
    /// has to cover many screens of rows.
    ///
    /// `revealing: .above` swipes the other way: the list keeps its scroll
    /// position across tab switches, so a section pinned to the top
    /// (Following) can sit screens above wherever the last hunt ended.
    @MainActor
    @discardableResult
    func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication,
                           revealing: ScrollReveal = .below,
                           maxSwipes: Int = 20, timeout: TimeInterval = 15) -> Bool {
        if element.waitForExistence(timeout: timeout) { return true }
        for _ in 0..<maxSwipes where !element.exists {
            switch revealing {
            case .below: app.swipeUp(velocity: .fast)
            case .above: app.swipeDown(velocity: .fast)
            }
        }
        return element.exists
    }

    /// Taps `button` and verifies `panel` actually went away, retrying with
    /// a frame-derived coordinate tap when it didn't.
    ///
    /// iOS 26.5 hosts alert panels — the app's SwiftUI alerts and
    /// springboard's permission prompts alike — outside the accessibility
    /// window `tap()` resolves its activation point against, so the
    /// synthesized tap can land nowhere while the element query itself
    /// matched fine. A coordinate tap synthesizes the touch at the button's
    /// on-screen frame, which does land. The wait between attempts is the
    /// dismiss animation's grace period — without it a good tap reads as a
    /// miss and the retry pokes whatever lies beneath the departed panel.
    /// `via` chooses whose coordinate space synthesizes the touch. For any
    /// panel button pass the app under test: a coordinate rooted in the
    /// (full-screen) app is a true screen-level touch and lands on the
    /// panel. `button.tap()` is never used in that mode — the broken
    /// synthesis doesn't just miss, its strays land on unrelated app UI
    /// (a late one toggled the reminder bell straight back off), so the
    /// element-tap path can't even be tried first.
    @MainActor
    @discardableResult
    func tapUntilDismissed(_ button: XCUIElement, dismissing panel: XCUIElement,
                           via eventTarget: XCUIApplication? = nil,
                           attempts: Int = 3) -> Bool {
        for _ in 0..<attempts {
            guard button.exists else { break }
            if let target = eventTarget {
                // The panel scales in; a frame read mid-animation aims at
                // a point the button hasn't reached yet (one such tap
                // landed on Not Now instead of Enable). Hold fire until
                // two consecutive reads agree.
                var frame = button.frame
                for _ in 0..<8 {
                    Thread.sleep(forTimeInterval: 0.25)
                    let settled = button.frame
                    if settled == frame, !settled.isEmpty { break }
                    frame = settled
                }
                target.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
                    .tap()
            } else {
                button.tap()
            }
            let gone = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: panel)
            if XCTWaiter.wait(for: [gone], timeout: 3) == .completed { return true }
        }
        return !panel.exists
    }

    /// Taps a tab and waits for something on the destination to prove it
    /// landed, retrying the tap if it didn't.
    ///
    /// A tab tap issued while a navigation pop is still animating gets
    /// swallowed — the tap "succeeds", the app stays put, and the next wait
    /// fails somewhere unrelated with a screenshot of the wrong screen.
    @MainActor
    @discardableResult
    func openTab(_ name: String, in app: XCUIApplication,
                 until landmark: XCUIElement, timeout: TimeInterval = 15,
                 attempts: Int = 3) -> Bool {
        for _ in 0..<attempts {
            let tab = app.tabBars.buttons[name]
            guard tab.waitForExistence(timeout: 10) else { continue }
            tab.tap()
            if landmark.waitForExistence(timeout: timeout) { return true }
        }
        return false
    }

    /// Scrolls `element` into view inside `strip` and taps it.
    ///
    /// Two traps here. Direction isn't fixed — the day strip opens on
    /// today, so a target sits off to the right in one season and off to
    /// the left in another, and scrolling the wrong way walks away from it
    /// until the loop gives up. And `swipeLeft`/`swipeRight` travel the
    /// strip's full width, so a fixed swipe overshoots and then ping-pongs
    /// past the target forever.
    ///
    /// So: drag a controlled fraction of the strip, and halve that fraction
    /// every time the direction reverses. It converges instead of oscillating.
    /// Tapping an offscreen element throws "activation point invalid", so
    /// visibility is checked by frame containment rather than isHittable.
    @MainActor
    @discardableResult
    func scrollToAndTap(_ element: XCUIElement, in strip: XCUIElement,
                        within window: XCUIElement, maxDrags: Int = 20) -> Bool {
        var fraction: CGFloat = 0.5
        var lastWasLeftward: Bool?

        for _ in 0..<maxDrags {
            guard element.exists else { return false }
            if window.frame.contains(element.frame) {
                element.tap()
                return true
            }
            // Leftward drag pulls content left, revealing what's off the right.
            let leftward = element.frame.midX > window.frame.midX
            if let last = lastWasLeftward, last != leftward {
                fraction = max(fraction / 2, 0.08)
            }
            lastWasLeftward = leftward

            let dx = fraction / 2
            let from = strip.coordinate(withNormalizedOffset:
                CGVector(dx: leftward ? 0.5 + dx : 0.5 - dx, dy: 0.5))
            let to = strip.coordinate(withNormalizedOffset:
                CGVector(dx: leftward ? 0.5 - dx : 0.5 + dx, dy: 0.5))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        return false
    }

    /// Switches the Scores season to `year` through the filter sheet,
    /// returning false if it never took. Leaves the sheet closed.
    ///
    /// The menu is retried: tapping the picker while the first scoreboard
    /// load is still settling re-renders the sheet and drops the menu
    /// before its items register, which reads as "no 2025 button" and
    /// fails an unguarded wait.
    @MainActor
    @discardableResult
    func selectSeason(_ year: Int, in app: XCUIApplication,
                      attempts: Int = 3) -> Bool {
        let label = String(year)
        for _ in 0..<attempts {
            // Wherever the chip rides — a hero toolbar, a tab pane — it is
            // simply on screen; there is no door to open first. Scores has
            // no season control at all now, so this is for entity pages.
            let chip = app.seasonChip
            guard chip.waitForExistence(timeout: 15) else { continue }
            if chip.value as? String == label { return true }
            chip.tap()

            // Picker rows inside a Menu surface as plain buttons on iOS.
            let option = app.buttons[label]
            guard option.waitForExistence(timeout: 5) else { continue }
            option.tap()

            let updated = app.seasonChip
            if updated.waitForExistence(timeout: 10),
               updated.value as? String == label {
                return true
            }
        }
        return false
    }
}