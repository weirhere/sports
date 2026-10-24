import SwiftUI
// `EnvironmentValues.requestReview` is StoreKit's, surfaced into SwiftUI —
// first-party, so the zero-dependency rule is untouched.
import StoreKit
import os

/// Tap a game, land somewhere worth landing: header, linescore, scoring
/// plays, team stats, leaders.
struct GameDetailScreen: View {
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "gamedetail")

    let game: Game

    @Environment(\.scenePhase) private var scenePhase
    /// Optional on purpose: a preview or a host that never planted one
    /// should render the page, not trap. `RootView` always provides it.
    @Environment(ReviewPrompt.self) private var reviewPrompt: ReviewPrompt?
    @Environment(UIStateStore.self) private var uiState: UIStateStore?

    /// Betting lines, per the Settings switch; off where no store is in
    /// the environment (previews).
    private var showsLines: Bool { uiState?.showsLines ?? false }
    @Environment(Router.self) private var router: Router?
    /// Optional like the router: previews and tests build this screen
    /// without the app's environment.
    @Environment(LeagueScoreboards.self) private var scoreboards: LeagueScoreboards?
    @Environment(\.requestReview) private var requestReview
    /// Spoiler mode (E30): the rule, and the store the Reveal button
    /// writes to. The store is optional like the router; the rule's
    /// default is off, so a preview shows its score.
    @Environment(\.spoilerGuard) private var spoilerGuard
    @Environment(SpoilerStore.self) private var spoiler: SpoilerStore?

    @State private var loadedSummary: GameSummary?
    /// Which game the loaded summary and standings describe. Belt and
    /// braces against the navigation-identity trap the `.id(game.routeKey)`
    /// on every Game destination closes: a reused screen must not paint the
    /// previous game's logos, leaders and venue under this one's header,
    /// whatever the routing layer does. A fetch-once guard is only safe if
    /// it knows what it fetched.
    @State private var loadedKey: String?
    @State private var isLoading = false
    @State private var lastError: String?
    /// The matchup-standings card's data, when it had to be fetched; a
    /// miss just hides the card. College football's arrives inside the
    /// summary instead (E21, 2026-09-21) and never touches this.
    @State private var conferenceStandings: [ConferenceStandings] = []
    /// Whether the fallback fetch has already been spent on this game.
    /// The poll re-enters `load` every 30s, and a league that ships no
    /// standings block would otherwise ask for the tables on every tick —
    /// which is the polite-guest rule broken by a card, of all things.
    @State private var triedStandingsFallback = false
    @State private var tab: Tab = .facts
    /// How far the header has collapsed under the bar (`CollapsingHeaderScrollView`).
    @State private var heroCollapse: CGFloat = 0
    /// True once the header's score line has scrolled under the bar — the
    /// bar's principal slot then carries the compact scoreboard.
    @State private var showsCompactHeader = false
    @State private var isSharing = false
    /// Rendered on the share tap, so the card can never carry a score the
    /// screen has already moved past.
    @State private var shareCardPNG: Data?
    /// Which edge incoming tab content pushes from, the entity pages'
    /// rule: trailing walking forward, leading coming back.
    @State private var tabSlideEdge: Edge = .trailing

    /// Whether the Plays tab is narrowed to the plays that scored. Lives
    /// here rather than in the list so switching tabs and coming back
    /// doesn't quietly widen the slate under the user.
    @State private var scoringOnly = false

    /// The H2H tab's series, and the game it belongs to — the summary's
    /// `loadedKey` guard applied to the second fetch on this screen, for
    /// the same reason. Fetched on the tab's first appearance rather than
    /// with the page: a series is twenty requests for a tab most visits
    /// never open.
    @State private var loadedSeries: HeadToHead?
    @State private var seriesKey: String?
    @State private var seriesFailed = false
    @State private var isLoadingSeries = false

    /// The News tab's stories, and the game they were fetched for — the
    /// series' guard again. Fetched when the tab first opens: two team
    /// feeds are two requests most visits never need.
    @State private var news: [NewsStory]?
    @State private var newsKey: String?
    @State private var newsFailed = false

    /// The Roster tab's model, and the game it was built for — the series'
    /// guard a third time. Fetched when the tab first opens (up to six
    /// requests, see `GameRosterFetch.swift`) and again when the game's
    /// phase flips under it: a lineup moves at kickoff and at the final,
    /// not between polls.
    @State private var loadedRoster: GameRoster?
    @State private var rosterKey: String?
    @State private var rosterFailed = false
    @State private var isLoadingRoster = false
    /// Whether the summary was in hand when the roster was assembled. One
    /// that lands after is a source — the box score names who played —
    /// so the lists are rebuilt once it does.
    @State private var rosterHadSummary = false

    /// The Standings tab's tables and scope. A model rather than more
    /// `@State` here because it carries its own fetch-once rules per
    /// scope; keyed by the game inside, like everything above.
    @State private var standingsTab = GameStandingsModel()

    /// The summary, but only if it belongs to the game on screen. Every
    /// card on the page reads through here, so a screen handed a new game
    /// falls back to what the pushed row already knows — the header it has
    /// always drawn before the fetch lands — rather than to another
    /// matchup's.
    private var summary: GameSummary? {
        loadedKey == game.routeKey ? loadedSummary : nil
    }

    /// Standings are league-wide and fetched once, so they carry the same
    /// risk the summary does: a reused screen handed a game in another
    /// league would keep asking the matchup card to find its two teams in
    /// the wrong table.
    ///
    /// The summary's own copy wins where there is one (E21, 2026-09-21):
    /// it is this game's two tables rather than the whole league's, and
    /// it arrived inside a request the page had to make anyway. The
    /// fetched tables are the fallback, and the card can't tell the
    /// difference — both are `[ConferenceStandings]` and
    /// `MatchupStandings` finds its two teams in either.
    private var currentStandings: [ConferenceStandings] {
        guard loadedKey == game.routeKey else { return [] }
        let fromSummary = loadedSummary?.matchupStandings ?? []
        return fromSummary.isEmpty ? conferenceStandings : fromSummary
    }

    /// Raw values order the tabs — the slide direction is an ordinal
    /// comparison. Facts keeps every card the screen has always had,
    /// minus Drives, which moved into Plays (2026-09-06); Plays sits in
    /// the middle because chronology comes before rosters, and H2H comes
    /// last because the history comes after the game itself. News sits
    /// second (Andy, 2026-09-27, E26), the entity pages' order: what's
    /// being written about the matchup, one swipe from the score. Roster
    /// (E29, 2026-10-18) sits after the box score, which is the rosters'
    /// place that comment always reserved. Standings (2026-10-24) sits
    /// between Roster and H2H, FotMob's Table-before-H2H order: where the
    /// two sides stand this season comes before how they have fared
    /// against each other across all of them.
    private enum Tab: Int, HeroTabItem {
        case facts, news, plays, boxScore, roster, standings, headToHead

        /// The bar reads `TabLabel.title`, not this: the first tab's name
        /// follows the game's state. This is the static name the rest of
        /// the screen (and the UI tests' identifiers) know a tab by.
        var title: String {
            switch self {
            case .facts: "Facts"
            case .news: "News"
            case .plays: "Plays"
            case .boxScore: "Box score"
            case .roster: "Roster"
            case .standings: "Standings"
            case .headToHead: "H2H"
            }
        }
    }

    /// What the bar draws for a tab: the enum's order under a title that
    /// can move. The first tab is "Preview" until kickoff and "Facts" from
    /// the first snap on (Andy, 2026-10-18, FotMob's naming), with the same
    /// cards either way — so the name lives on the label, not the case.
    private struct TabLabel: HeroTabItem {
        let tab: Tab
        let title: String
    }

    private func label(_ tab: Tab) -> TabLabel {
        TabLabel(tab: tab, title: tab == .facts
                 ? GameHeaderState.factsTabTitle(game, summary, concealed: concealed)
                 : tab.title)
    }

    /// Whether this page hides its result (E30). Decided from the merged
    /// status, not the pushed row: a `.pre` row pushed before kickoff
    /// whose summary has since gone live is exactly the page that must
    /// hide, and a `.pre` game is the one the guard lets through.
    private var concealed: Bool {
        spoilerGuard.conceals(GameHeaderState.merged(game, summary))
    }

    /// The merge with its result taken out — what every concealed surface
    /// on this page renders from.
    private var concealedGame: Game { GameHeaderState.concealedGame(game, summary) }

    /// A tab only exists where its data does. Pre-kick games, CFBD's
    /// feed, and any game ESPN hasn't filled in show Summary alone and
    /// no tab row — exactly as they did before either tab existed.
    private var availableTabs: [Tab] {
        // Concealed (E30): Preview alone, and so no tab row. Every other
        // tab is the result in some form — the plays, the box score, who
        // played, the recap — and the page's standing rule for a tab
        // whose whole content is missing is no tab.
        guard !concealed else { return [.facts] }
        var tabs: [Tab] = [.facts]
        // News reads the two teams' feeds, not the summary, so like H2H
        // it's there from the first frame. ESPN's only: the fixture and
        // CFBD feeds have no news endpoint to ask.
        if hasHeadToHead, client.providesRoster { tabs.append(.news) }
        if let summary {
            if hasDrives(summary) || !summary.plays.isEmpty { tabs.append(.plays) }
            if !summary.boxScore.isEmpty { tabs.append(.boxScore) }
        }
        // Roster reads its own endpoints, so like News it is there from the
        // first frame, and ESPN-only for the same reason: the fixture and
        // CFBD feeds have no roster to ask for (E29).
        if hasHeadToHead, client.providesRoster { tabs.append(.roster) }
        // Standings read the league's tables, not the summary, so they are
        // there from the first frame too. ESPN-only on News' and Roster's
        // proxy: the fixture feed answers no tables and CFBD's are FBS
        // only, and a tab that could only ever say "TBA" is no tab.
        if hasHeadToHead, client.providesRoster { tabs.append(.standings) }
        // H2H reads the pushed row, not the summary, so it is offered from
        // the first frame — which is the point: before kickoff it is the
        // only other tab there is, and "who usually wins this" is the
        // pre-game question. That does mean a pre-kick page now shows a tab
        // row where it deliberately showed none (2026-09-05); a row of two
        // real answers is not the chrome-saying-nothing that rule was
        // written against.
        if hasHeadToHead { tabs.append(.headToHead) }
        return tabs
    }

    /// Whether a series is even askable. Both sides have to be named — an
    /// id is what the meetings are filtered by — and a team cannot play
    /// itself.
    private var hasHeadToHead: Bool {
        let away = game.away.team.id, home = game.home.team.id
        return !away.isEmpty && !home.isEmpty && away != home
    }

    private var showsTabs: Bool { availableTabs.count > 1 }

    /// Football's plays live inside its drives; every other league's
    /// arrive flat. Which list the Plays tab renders follows from that.
    private func hasDrives(_ summary: GameSummary) -> Bool {
        !summary.drives.isEmpty || summary.currentDrive != nil
    }

    private func hasScoringPlays(_ summary: GameSummary) -> Bool {
        if hasDrives(summary) {
            return !summary.drives.allSatisfy(\.scoringPlays.isEmpty)
                || !(summary.currentDrive?.scoringPlays.isEmpty ?? true)
        }
        return summary.plays.contains(where: \.isScoringPlay)
    }

    private var gameLeague: League { game.home.team.league }

    /// Whether a period past the overtime would be a shootout rather than
    /// a second overtime. Hockey settles a regular-season tie that way and
    /// a playoff game never does, so the label has to know which it is.
    private var allowsShootout: Bool {
        gameLeague == .nhl && game.seasonType != Postseason.seasonType
    }

    /// Scoped to the game's league — the summary endpoint lives behind
    /// its own sport path, and event ids are fetched through it.
    private var client: any ScoresProviding {
        DataProvider.makeClient(league: game.home.team.league)
    }

    var body: some View {
        // The header rides over the content and collapses as it scrolls,
        // the entity pages' template: the matchup scrolls away, the tab row
        // pins under the bar, and the bar takes over the score once the
        // header's own score line has gone under it (Andy, 2026-10-02).
        CollapsingHeaderScrollView(landing: landing, collapse: $heroCollapse) {
            // The header sits on the card surface — headers match the
            // cards on every entity page (Andy, 2026-08-31); the content
            // below stays in cards on the recessed one. Opaque because it
            // draws over the content rather than above it.
            header
                .frame(maxWidth: .infinity)
                .background(Color.bgCard)
        } strip: {
            if showsTabs {
                // Leading, with the entity pages' Spacing.lg gutter — Team
                // and Conference anchor their tab rows to the left edge and
                // this is the same component. The gutter lives inside
                // HeroTabBar as of 2026-09-21, so this hands it an unpadded
                // surface.
                HeroTabBar(tabs: availableTabs.map(label), selection: label(tab),
                           onSelect: { select(tab: $0.tab) })
                    .frame(maxWidth: .infinity)
                    .background(Color.bgCard)
                    // The nav bar's hairline, repeated under the tabs, so
                    // the pinned row has the same edge over the content
                    // scrolling under it (Andy, 2026-10-02).
                    .overlay(alignment: .bottom) {
                        Divider().overlay(Color.divider)
                    }
            }
        } content: { _ in
            VStack(spacing: 0) {
                // H2H stands outside the summary gate: it is built from the
                // pushed row, so it works while the summary is still in
                // flight and — the case that matters — when the summary
                // failed outright. A page that can't reach one endpoint
                // shouldn't hide a tab that doesn't use it.
                if summary != nil || tab == .headToHead || tab == .news || tab == .roster
                    || tab == .standings {
                    Group {
                        // A tab whose data went away between polls falls
                        // back rather than rendering an empty pane.
                        let shown: Tab = availableTabs.contains(tab) ? tab : .facts
                        switch shown {
                        case .boxScore:
                            if let summary {
                                BoxScoreList(summary: summary)
                                    .padding(Spacing.sm)
                            }
                        case .plays:
                            if let summary { playsPane(summary) }
                        case .headToHead:
                            headToHeadPane
                        case .news:
                            newsPane
                        case .roster:
                            GameRosterPane(league: gameLeague, state: rosterState,
                                           possessionTeamId: possessionTeamId,
                                           onRetry: { Task { await loadRoster(force: true) } })
                        case .standings:
                            standingsPane
                        case .facts:
                            if let summary { summaryCards(summary) }
                        }
                    }
                    // geometryGroup pins every child to the pane while it
                    // slides — without it, subtrees resolve their own
                    // positions and marks sit still as cards move.
                    .geometryGroup()
                    .id(tab)
                    .transition(.push(from: tabSlideEdge))
                    // The entity pages' swipe: horizontal walks the tabs,
                    // with a dominance check so vertical scrolling never
                    // tab-flips. The buttons stay, so nothing is gated.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                let dx = value.translation.width
                                let tabs = availableTabs
                                guard showsTabs, !tabOwnsHorizontalAxis, abs(dx) > 50,
                                      abs(dx) > abs(value.translation.height) * 1.5,
                                      let here = tabs.firstIndex(of: tab)
                                else { return }
                                let next = here + (dx < 0 ? 1 : -1)
                                guard tabs.indices.contains(next) else { return }
                                select(tab: tabs[next])
                            }
                    )
                } else if isLoading {
                    ProgressView().padding(.vertical, Spacing.xl)
                } else if lastError != nil {
                    VStack(spacing: Spacing.sm) {
                        Text("Couldn't load this game.")
                            .font(.teamName)
                            .foregroundStyle(.textSecondary)
                        Button("Retry") {
                            Task { await load(force: true) }
                        }
                        .font(.teamNameEmphasis)
                        .foregroundStyle(.textPrimary)
                    }
                    .padding(.vertical, Spacing.xl)
                }
            }
        }
        .onChange(of: heroCollapse > Self.compactThreshold) { _, scrolledPastScore in
            withAnimation(.easeInOut(duration: 0.15)) {
                showsCompactHeader = scrolledPastScore
            }
        }
        // The card color through the top bounce, matching the entity pages.
        .heroTopBand(Color.bgCard)
        .background(Color.bgRecessed)
        // No bar title: the header is the identity until it scrolls away,
        // and then the compact scoreboard in the principal slot is.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgCard, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                compactHeader
                    .opacity(showsCompactHeader ? 1 : 0)
                    .accessibilityHidden(!showsCompactHeader)
            }
            #if canImport(ActivityKit)
            // The pin steps out while the compact scoreboard holds the bar:
            // the score needs the width, and pinning is a choice made from
            // the full header, not mid-scroll.
            if !showsCompactHeader {
                ToolbarItem(placement: .topBarTrailing) {
                    // Renders nothing until path 3's service exists — see
                    // LiveActivityController.isAvailable.
                    GameActivityPinButton(game: game, summary: summary)
                }
            }
            #endif
            // No share while concealed (E30): the card is the score.
            // Reveal first, and the button comes back.
            if !concealed {
            ToolbarItem(placement: .topBarTrailing) {
                // Not a ShareLink: only UIActivityItemSource can hand
                // Messages the score card as the link's preview image.
                Button {
                    Task {
                        shareCardPNG = await renderedShareCard()
                        isSharing = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.textPrimary)
                }
                .accessibilityLabel("Share this game")
                .sheet(isPresented: $isSharing) {
                    GameShareSheet(source: GameShareItemSource(
                        title: shareBody,
                        link: ShareSignOff.appStoreLink,
                        cardPNG: shareCardPNG))
                }
            }
            }
        }
        // The third of the app's three haptics: a live score changing under
        // your thumb. Detail-screen only — the scoreboard's 60-game poll
        // would machine-gun the Taptic engine.
        .sensoryFeedback(.impact(weight: .medium), trigger: currentScores) { _, _ in
            // Not while concealed (E30): a tap on the wrist at every score
            // is the score, read by touch.
            isLiveNow && !concealed
        }
        // Keyed by the game, not fire-once: a screen reused for another
        // game must fetch that game rather than sit on what it holds.
        .task(id: game.routeKey) {
            await load()
            await pinIfRequested()
            await askForReviewIfEarned()
        }
        // The same pin, when this game's page was already open as the
        // reminder's action came in and nothing above re-runs.
        .onChange(of: router?.pendingPin) { _, pin in
            guard pin == game.id, summary != nil else { return }
            Task { await pinIfRequested() }
        }
        // The series is fetched when its tab is first opened, not with the
        // page — twenty requests is a lot to spend on a tab most visits
        // never reach. The id carries the game so a screen handed another
        // matchup while sitting on H2H fetches the new one.
        .task(id: "\(game.routeKey):\(tab == .headToHead)") {
            guard tab == .headToHead else { return }
            await loadSeries()
        }
        // The News tab's feeds, on the same terms.
        .task(id: "\(game.routeKey):\(tab == .news)") {
            guard tab == .news else { return }
            await loadNews()
        }
        // The Standings tab's tables, on the same terms — and again when
        // the chip changes scope, since Division is a request of its own.
        // The load is idempotent, so a scope already fetched costs nothing.
        .task(id: "\(game.routeKey):\(tab == .standings):\(standingsTab.scope)") {
            guard tab == .standings else { return }
            await standingsTab.load(for: game, client: client)
        }
        // The Roster tab's sources, on the same terms — and asked again
        // when the game's phase changes under an open tab (the pre-game
        // projection becomes the lineup at kickoff) or when the summary
        // lands after the lists were built without it.
        .task(id: "\(game.routeKey):\(tab == .roster):\(rosterPhase):\(summary != nil)") {
            guard tab == .roster else { return }
            let stale = loadedRoster.map {
                $0.phase != rosterPhase || (!rosterHadSummary && summary != nil)
            } ?? false
            await loadRoster(force: stale)
        }
        // The live auto-refresh mirrors the scoreboard's polling rules: only while
        // the scene is active and the game is in progress. The id flips when
        // either condition changes, cancelling or restarting the loop — a
        // summary that comes back final stops it on its own. The game rides
        // in it for the reason above: a new game is a new loop.
        .task(id: pollKey) {
            guard scenePhase == .active, isLiveNow else { return }
            Self.logger.info("detail polling: started for event \(game.id)")
            while !Task.isCancelled {
                try? await Task.sleep(for: DataProvider.pollInterval)
                guard !Task.isCancelled else { break }
                Self.logger.info("detail polling: tick for event \(game.id)")
                await load(force: true)
            }
            Self.logger.info("detail polling: stopped for event \(game.id)")
        }
        .refreshable {
            await load(force: true)
            if tab == .roster { await loadRoster(force: true) }
            if tab == .standings { await standingsTab.load(for: game, client: client, force: true) }
        }
    }

    private var isLiveNow: Bool { GameHeaderState.isLive(game, summary) }

    /// Whether the pane is using the horizontal axis itself, so the tab
    /// swipe stands down — the team page's rule. Only the NFL's standings
    /// table does: its twelve columns scroll under a pinned name column.
    private var tabOwnsHorizontalAxis: Bool {
        tab == .standings && gameLeague.standingsScrollsHorizontally
    }

    /// Where the header's score line ends: 16pt of padding, the live
    /// dot's row and the 41pt score. Past it, the bar takes over.
    private static let compactThreshold: CGFloat = 64

    /// Re-landing on a tab flip, the entity pages' rule: the new pane opens
    /// at its top with the header fully expanded.
    private var landing: ScrollLanding {
        ScrollLanding(key: "\(game.routeKey):\(tab)", target: nil)
    }

    /// The rating ask, at the only moment it is earned: a kickoff reminder
    /// fired, the user tapped it, and the game it promised is on screen
    /// and loaded (open question #7).
    ///
    /// After the page has something on it, never before. A sheet thrown up
    /// over a spinner asks the user to rate a loading indicator, and one
    /// thrown up over "Couldn't load this game" asks them to rate a
    /// failure — which is why the load guard sits *above* the arm and a
    /// failed fetch leaves the arm intact: the reminder promised a game,
    /// and a game that never arrived hasn't earned anything yet.
    ///
    /// The settle delay lets the push animation finish first. Navigating
    /// away inside it cancels the task, and by then the arm is spent, so a
    /// user who left is neither asked on the way out nor chased on the
    /// next launch.
    private func askForReviewIfEarned() async {
        guard let reviewPrompt else { return }
        guard summary != nil, lastError == nil else { return }
        // Not over a concealed page (E30): the ask would land on top of
        // the Reveal button, and a page hiding its score hasn't shown
        // the thing the reminder promised yet.
        guard !concealed else { return }
        guard reviewPrompt.earnedByOpening(gameId: game.id) else { return }
        try? await Task.sleep(for: .seconds(1.5))
        guard !Task.isCancelled else { return }
        reviewPrompt.recordRequest()
        requestReview()
    }

    /// What restarts the poll loop: the game, and whether it should be
    /// running at all.
    private var pollKey: String {
        "\(game.routeKey):\(scenePhase == .active && isLiveNow)"
    }

    /// Past-season games (pushed from a flipped team schedule) must not
    /// wear the current season's standings.
    private var isCurrentSeason: Bool {
        // On the game's own league's clock: a March hockey game is this
        // season's, where a college-football rollover would file it under
        // last year's.
        let league = game.home.team.league
        return game.date.map {
            SeasonYear.year(for: league, now: $0) == SeasonYear.year(for: league)
        } ?? false
    }

    private var currentScores: [Int?] {
        [summary?.away?.score ?? game.away.score, summary?.home?.score ?? game.home.score]
    }

    /// Shares what the header shows — the summary's fresher score when it
    /// has one, not the pushed row's snapshot.
    private var shareText: String { ShareSignOff.appended(to: shareBody) }

    /// The share sentence without the sign-off, composed from the fresher
    /// summary score. Doubles as the link preview's title, where the
    /// branding would only repeat what the store link already says.
    private var shareBody: String {
        let away = competitor(game.away, summary?.away)
        let home = competitor(game.home, summary?.home)
        guard showsScores, let awayScore = away.score, let homeScore = home.score else {
            return game.shareBody
        }
        let status = statusLine.replacingOccurrences(of: "\n", with: ", ")
        return "\(away.team.location) \(awayScore), \(home.team.location) \(homeScore), \(status)"
    }

    /// Rendered on demand rather than kept warm: the logos are already in
    /// `LogoCache` from the header above, so this costs a frame, and a
    /// card rendered at tap time can't be stale.
    private func renderedShareCard() async -> Data? {
        let card = GameShareCard(game: game, summary: summary, shareText: shareText)
        do {
            return try await card.pngData()
        } catch {
            // The share still works — the bubble just loses its picture.
            Self.logger.error("share card render failed: \(String(describing: error))")
            return nil
        }
    }

    /// Renders from the scoreboard's Game immediately; the summary fills in.
    /// `GameHeader` since 2026-10-19 — its own file, so the snapshot suite
    /// can draw it without the screen.
    @ViewBuilder
    private var header: some View {
        if concealed {
            GameHeader(concealed: concealedGame, onReveal: { spoiler?.reveal(game) })
        } else {
            GameHeader(game: game, summary: summary)
        }
    }

    /// The bar's scoreboard, or while concealed its status word alone:
    /// `CompactGameHeader`'s own `.status` case, reached by handing it the
    /// concealed game, whose scores are nil.
    private var compactHeader: CompactGameHeader {
        concealed ? CompactGameHeader(game: concealedGame, summary: nil)
                  : CompactGameHeader(game: game, summary: summary)
    }

    // Delegated to GameHeaderState so the share card provably renders the
    // same merge and status strings as this header.
    private func competitor(_ fallback: Competitor, _ side: GameSummary.Side?)
        -> (team: Team, score: Int?, record: String?, winner: Bool?) {
        GameHeaderState.competitor(fallback, side)
    }

    private var possessionTeamId: String? { GameHeaderState.possessionTeamId(game, summary) }

    /// Internal for AccessibilityLabelTests: what the header says for a side.
    func sideAccessibilityLabel(_ side: (team: Team, score: Int?, record: String?, winner: Bool?)) -> String {
        GameHeader(game: game, summary: summary).sideAccessibilityLabel(side)
    }

    private var showsScores: Bool { GameHeaderState.showsScores(game, summary) }

    private var statusLine: String { GameHeaderState.statusLine(game, summary) }


    /// Tab taps and content swipes share the one direction rule. The edge
    /// commits a transaction BEFORE the switch: the outgoing pane's
    /// `.push` resolves against the pre-change tree, so setting both
    /// together replays the previous direction (the entity pages' split,
    /// 2026-08-31).
    private func select(tab value: Tab) {
        guard value != tab else { return }
        tabSlideEdge = value.rawValue > tab.rawValue ? .trailing : .leading
        Task { @MainActor in
            withAnimation(.default) { tab = value }
        }
    }

    /// The Roster tab's phase — which of "planning to play", "playing"
    /// and "played" its lists answer.
    private var rosterPhase: GameRoster.Phase { GameHeaderState.rosterPhase(game, summary) }

    /// What the Roster pane draws, keyed by the game like the series.
    private var rosterState: GameRosterPane.LoadState {
        guard rosterKey == game.routeKey else { return .loading }
        if let loadedRoster { return .loaded(loadedRoster) }
        return rosterFailed ? .failed : .loading
    }

    /// Up to six requests, once per game per phase — see
    /// `GameRosterFetch.swift` for which and why. A refetch that fails
    /// keeps the lists it had rather than replacing them with Retry.
    private func loadRoster(force: Bool = false) async {
        let key = game.routeKey
        if rosterKey == key, loadedRoster != nil, !force { return }
        guard !isLoadingRoster else { return }
        isLoadingRoster = true
        defer { isLoadingRoster = false }
        rosterKey = key
        rosterFailed = false
        let hadSummary = summary != nil
        let phase = rosterPhase
        do {
            let loaded = try await client.gameRoster(for: game, summary: summary, phase: phase,
                                                     currentSeason: isCurrentSeason)
            guard game.routeKey == key else { return }
            loadedRoster = loaded
            rosterHadSummary = hadSummary
        } catch {
            guard game.routeKey == key else { return }
            if loadedRoster == nil { rosterFailed = true }
        }
    }

    /// Every card the Facts (or, pre-game, Preview) tab has always had, in
    /// the order it had them — the Box score tab is additive, so nothing
    /// here moved.
    @ViewBuilder
    private func summaryCards(_ summary: GameSummary) -> some View {
        if concealed {
            concealedCards(summary)
        } else {
        let story = summary.story(forGame: game.id, status: GameHeaderState.status(game, summary))
        VStack(spacing: Spacing.sm) {
                    // A final leads with its recap, FotMob's match report
                    // on Facts (docs/news.md, N2). It rode in with the
                    // summary, so the card costs no request of its own.
                    if let story, story.kind == .recap {
                        storyCard(story)
                    }
                    // The Gamecast strip leads while a game is live: the
                    // down, the spot, and the last play are what the page
                    // is being opened for at 3:30 on a Saturday.
                    if let situation = summary.situation {
                        card(title: "Current drive") {
                            LiveSituationCard(summary: summary, situation: situation)
                        }
                    } else if let shots = shotGamecast(summary) {
                        // Basketball and hockey: the same card over this
                        // period's shots (2026-09-27).
                        card(title: "Current \(gameLeague.periodFormat.longName.lowercased())") {
                            LiveSituationCard(summary: summary, content: shots.content, map: shots.map)
                        }
                    }
                    // When and where to watch is one question; the
                    // ground it's played on is another (FotMob's Preview
                    // cards, monochrome). Pre-kick the sections below are
                    // all empty, so the pair carries the whole "what do I
                    // need to know" load — but the questions outlive the
                    // kickoff, so Game info stays put once a game starts.
                    if KickoffInfoRows.hasContent(game: game, summary: summary,
                                                  showsLines: showsLines) {
                        card(title: "Game info") {
                            KickoffInfoRows(game: game, summary: summary, showsLines: showsLines)
                        }
                    }
                    // Pre-game the preview follows Game info (N3): when
                    // and where to watch is still the first question.
                    if let story, story.kind == .preview {
                        storyCard(story)
                    }
                    if !showsScores, GameInfoRows.hasVenueContent(summary) {
                        card(title: "Venue") {
                            GameInfoRows(summary: summary)
                        }
                    }
                    if summary.away?.linescores.isEmpty == false {
                        card {
                            LineScoreGrid(summary: summary, league: gameLeague,
                                          allowsShootout: allowsShootout)
                        }
                    }
                    // ESPN's predictor before kickoff, the per-play line
                    // after it. Absent in hockey, whose payload has neither.
                    if let probability = summary.winProbability {
                        let isFinal = GameHeaderState.status(game, summary).isFinal
                        card(title: "Win probability",
                             subtitle: WinProbabilityCard.reading(probability, isFinal: isFinal).caption) {
                            WinProbabilityCard(probability: probability, isFinal: isFinal,
                                               away: game.away.team, home: game.home.team)
                        }
                    }
                    // "Scoring" in football, "Goals" in hockey, and no
                    // card at all in basketball — ~98 buckets a game is
                    // the box score with worse formatting.
                    if let title = gameLeague.scoringCardTitle, !summary.scoringPlays.isEmpty {
                        card(title: title) {
                            ScoringPlaysList(summary: summary, league: gameLeague,
                                             allowsShootout: allowsShootout)
                        }
                    }
                    if !summary.teamStats.isEmpty {
                        card(title: "Team stats", subtitle: statsLegend(summary)) {
                            TeamStatsCompare(summary: summary)
                        }
                    }
                    if !summary.leaders.isEmpty {
                        card(title: "Leaders") { LeadersList(summary: summary) }
                    }
                    // The two sides' conference standing "so far" —
                    // only for current-season games (the fetch is
                    // always the current tables, and 2019's page must
                    // not wear 2026's numbers).
                    if isCurrentSeason,
                       MatchupStandings.hasContent(away: game.away.team,
                                                   home: game.home.team,
                                                   standings: currentStandings) {
                        card(title: "Standings") {
                            MatchupStandings(away: game.away.team,
                                             home: game.home.team,
                                             standings: currentStandings)
                        }
                    }
                    // Pre-game the venue card sits up top with the
                    // kickoff; once scores exist it comes back down
                    // here, to place the game and count the crowd.
                    if showsScores, GameInfoRows.hasVenueContent(summary) {
                        card(title: "Venue") {
                            GameInfoRows(summary: summary)
                        }
                    }
            }
            .padding(Spacing.sm)
        }
    }

    /// The Preview a concealed game shows (E30): when and where to watch,
    /// and the ground — the two cards with no result in them, in their
    /// pre-game order. Everything else on Facts is the outcome in one
    /// form or another: the recap's headline, the situation strip, the
    /// line score, win probability, the scoring, the stats, the leaders,
    /// a standings table that already counts this game. No betting line
    /// either, whatever Settings says: who was favored beside a final
    /// with no score is half the result.
    private func concealedCards(_ summary: GameSummary) -> some View {
        VStack(spacing: Spacing.sm) {
            if KickoffInfoRows.hasContent(game: concealedGame, summary: summary) {
                card(title: "Game info") {
                    KickoffInfoRows(game: concealedGame, summary: summary)
                }
            }
            if GameInfoRows.hasVenueContent(summary) {
                card(title: "Venue") {
                    GameInfoRows(summary: summary)
                }
            }
        }
        .padding(Spacing.sm)
    }

    /// The game's story as one `StoryRow`, opening the reader. The reader's
    /// score row doesn't link back: this page is where it would go.
    private func storyCard(_ story: NewsStory) -> some View {
        card(title: story.kind.title) {
            NavigationLink(value: StoryDestination(story: story, game: game, linksGame: false)) {
                StoryRow(story: story)
            }
            .buttonStyle(.plain)
        }
    }

    /// The court or rink Gamecast, live games only (D1): the color budget's
    /// surface exception is "only ever drawn while a game is live", and a
    /// final keeps the page it had. Nil in football, whose card is the
    /// drive, and wherever the feed has nothing to draw.
    private func shotGamecast(_ summary: GameSummary) -> (content: GamecastContent, map: ShotMap)? {
        guard case .live = GameHeaderState.status(game, summary),
              let map = ShotMap.current(plays: summary.plays, league: gameLeague,
                                        awayId: summary.away?.team.id,
                                        allowsShootout: allowsShootout),
              let content = GamecastContent.shotMap(summary: summary, league: gameLeague,
                                                    allowsShootout: allowsShootout)
        else { return nil }
        return (content, map)
    }

    /// The Plays tab: the Games tabs' control row language — two toggles
    /// answering one question, so turning one on turns the other off —
    /// over the one card that holds every possession.
    private func playsPane(_ summary: GameSummary) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                SlateToggleChip(title: "All plays", isOn: !scoringOnly,
                                hint: "Shows every play") {
                    scoringOnly = false
                }
                SlateToggleChip(title: "Scoring", isOn: scoringOnly,
                                hint: "Shows only the plays that scored") {
                    scoringOnly = true
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.sm)
            if scoringOnly, !hasScoringPlays(summary) {
                Text("No scoring plays yet.")
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
                    .padding(.vertical, Spacing.xl)
            } else if hasDrives(summary) {
                card { PlayByPlayList(summary: summary, scoringOnly: scoringOnly) }
            } else {
                // A league with no possessions to group by: the period is
                // the only rung ESPN's flat feed carries.
                card {
                    PeriodPlayList(summary: summary, league: gameLeague,
                                   allowsShootout: allowsShootout,
                                   scoringOnly: scoringOnly)
                }
            }
        }
        .padding(Spacing.sm)
    }

    /// The Standings tab: both sides' tables at the chip's scope.
    private var standingsPane: some View {
        GameStandingsPane(
            game: game,
            state: standingsTab.state(for: game),
            scope: standingsTab.scope,
            // Live dots are current-season only: a past game's tables are
            // that season's, and tonight's scores mean nothing on them.
            liveGames: isCurrentSeason
                ? (scoreboards?.store(for: gameLeague).boardGames.filter(\.isLive) ?? []) : [],
            onSelectScope: { value in
                withAnimation(.default) { standingsTab.select(scope: value) }
            },
            onRetry: { Task { await standingsTab.load(for: game, client: client, force: true) } }
        )
    }

    /// The H2H tab: the series tally and the meetings behind it.
    private var headToHeadPane: some View {
        HeadToHeadPane(away: game.away.team, home: game.home.team,
                       state: seriesState,
                       onRetry: { Task { await loadSeries(force: true) } })
    }

    /// What the pane draws. Keyed by the game like everything else on this
    /// screen: a reused screen must not show the last matchup's series
    /// under this one's logos.
    private var seriesState: HeadToHeadPane.LoadState {
        guard seriesKey == game.routeKey else { return .loading }
        if let loadedSeries { return .loaded(loadedSeries) }
        return seriesFailed ? .failed : .loading
    }

    /// Walks the series out of the two teams' shared past. Runs on the H2H
    /// tab's first appearance and never again for that game — it is a
    /// season-by-season walk, not something to put on a 30s poll.
    private func loadSeries(force: Bool = false) async {
        let key = game.routeKey
        if seriesKey == key, loadedSeries != nil, !force { return }
        guard !isLoadingSeries else { return }
        isLoadingSeries = true
        seriesKey = key
        seriesFailed = false
        defer { isLoadingSeries = false }
        do {
            let loaded = try await client.headToHead(for: game)
            guard game.routeKey == key else { return }
            loadedSeries = loaded
        } catch {
            guard game.routeKey == key else { return }
            seriesFailed = true
        }
    }

    /// The News tab: both teams' stories in the rows every News tab uses.
    @ViewBuilder
    private var newsPane: some View {
        Group {
            if newsKey == game.routeKey, let news, !news.isEmpty {
                StoryListCard(stories: news)
            } else if newsKey == game.routeKey, news != nil {
                StatusMessage(text: "No stories about this matchup right now.")
                    .cardSurface()
            } else if newsKey == game.routeKey, newsFailed {
                StatusMessage(text: "Couldn't load the news.",
                              retry: { Task { await loadNews(force: true) } })
                    .cardSurface()
            } else {
                ProgressView().padding(.vertical, Spacing.xl)
            }
        }
        .padding(Spacing.sm)
    }

    /// The two teams' own feeds, merged, with the game's own recap or
    /// preview folded in where the summary carries one — the Summary
    /// tab's card, listed with everything else about the matchup.
    private func loadNews(force: Bool = false) async {
        let key = game.routeKey
        if newsKey == key, news != nil, !force { return }
        newsKey = key
        newsFailed = false
        let teams = [game.away.team.id, game.home.team.id]
            .map { FollowKey(league: gameLeague, teamId: $0) }
        let loaded = await NewsFeedStore.teamsPage(teams)
        guard game.routeKey == key else { return }
        if let loaded {
            let own = summary.flatMap {
                $0.story(forGame: game.id, status: GameHeaderState.status(game, $0))
            }
            news = NewsMapper.forYou([own.map { [$0] } ?? [], loaded])
        } else {
            newsFailed = true
        }
    }

    /// One content card: optional bordered header, then the section's own
    /// rows — the same recipe as the team-page cards.
    private func card(title: String? = nil, subtitle: String? = nil,
                      @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            if let title {
                CardHeader(title: title, subtitle: subtitle)
            }
            content()
                .padding(.top, Spacing.xs)
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    /// The Team stats card's column legend, formerly the sub-view's own
    /// header trailing text.
    private func statsLegend(_ summary: GameSummary) -> String {
        "\(summary.away?.team.abbreviation ?? "AWAY") · \(summary.home?.team.abbreviation ?? "HOME")"
    }

    private func load(force: Bool = false) async {
        let key = game.routeKey
        // A screen handed a different game drops what it was holding,
        // the view-state the old game scoped included: a Plays tab and a
        // scoring-only filter belong to the matchup they were chosen on.
        if loadedKey != key {
            loadedSummary = nil
            conferenceStandings = []
            triedStandingsFallback = false
            lastError = nil
            tab = .facts
            scoringOnly = false
            shareCardPNG = nil
            loadedSeries = nil
            seriesKey = nil
            seriesFailed = false
            news = nil
            newsKey = nil
            newsFailed = false
            loadedRoster = nil
            rosterKey = nil
            rosterFailed = false
            rosterHadSummary = false
            loadedKey = key
        }
        guard loadedSummary == nil || force else { return }
        isLoading = true
        defer { isLoading = false }
        // Standings ride along for the matchup card — independent fetch,
        // quiet failure, skipped entirely for past-season games and once
        // loaded (the poll loop shouldn't refetch tables every 30s).
        // The gate is decided here, on the main actor: an `async let`
        // initializer is a nonisolated autoclosure, so it can't read
        // `conferenceStandings` itself.
        //
        // College football skips it outright: its summary carries both
        // conferences' tables, so the speculative fetch was asking ESPN
        // for a whole league to render two rows it was about to be handed
        // anyway (E21, 2026-09-21). If the block turns out to be missing,
        // the fallback below picks it up — once.
        let needsStandings = isCurrentSeason && conferenceStandings.isEmpty
            && !game.home.team.league.summaryCarriesMatchupStandings
        async let standingsFetch: [ConferenceStandings]? =
            needsStandings ? try? client.conferenceStandings() : nil
        do {
            let loaded = try await client.gameSummary(eventId: game.id)
            // And the screen may have been handed another game while this
            // was in flight — the widget tap this whole guard exists for
            // can land mid-fetch as easily as before one.
            guard game.routeKey == key else { return }
            loadedSummary = loaded
            lastError = nil
            // The Scores list's copy of this game catches up to this one,
            // which is usually the fresher of the two (2026-09-26).
            scoreboards?.absorb(loaded, for: game)
        } catch {
            guard game.routeKey == key else { return }
            lastError = "Couldn't load this game."
        }
        if let loaded = await standingsFetch, game.routeKey == key {
            conferenceStandings = loaded
        }
        // The fallback: a league that ships a standings block, and a
        // payload that came back without one. Sequential rather than
        // speculative — it costs a round trip, but only on the path where
        // the free copy didn't arrive, and only once per game.
        if isCurrentSeason, !triedStandingsFallback, conferenceStandings.isEmpty,
           let summary = loadedSummary, summary.matchupStandings.isEmpty,
           game.home.team.league.summaryCarriesMatchupStandings {
            triedStandingsFallback = true
            let fallback = try? await client.conferenceStandings()
            if let fallback, game.routeKey == key {
                conferenceStandings = fallback
            }
        }
        await refreshPinnedActivity()
    }

    /// The kickoff reminder's "Pin to Lock Screen", carried out once this
    /// game is on screen with its summary in hand. Spent whether or not the
    /// card starts, so a pin that can't happen (the game finished, or
    /// activities were switched off after the reminder fired) doesn't fire
    /// later on a visit nobody meant as a pin. Starting a game that is
    /// already pinned is a no-op inside `start`.
    private func pinIfRequested() async {
        guard let router, router.pendingPin == game.id else { return }
        router.pendingPin = nil
        #if canImport(ActivityKit)
        guard LiveActivityController.isAvailable,
              LiveActivityController.isStartable(game, summary: summary) else { return }
        await LiveActivityController().start(game: game, summary: summary)
        #endif
    }

    /// Keeps a pinned card in step with what this screen just fetched.
    ///
    /// Deliberately riding the existing 30s poll rather than opening a
    /// loop of its own: no new ESPN request source, and the cadence is
    /// already the polite-guest floor. It also means the card is only
    /// this fresh while the screen is open — which is exactly why path 3's
    /// service is the thing that makes the feature real, and why
    /// `isAvailable` stays false until it exists.
    private func refreshPinnedActivity() async {
        #if canImport(ActivityKit)
        guard LiveActivityController.isAvailable else { return }
        let controller = LiveActivityController()
        guard controller.isActive(gameId: game.id) else { return }
        await controller.update(game: game, summary: summary)
        // A game that finished while the page sat open retires its own
        // card on the widget's spent rule, so nothing is left claiming a
        // clock is running.
        await controller.endIfSpent(game: game)
        #endif
    }
}
