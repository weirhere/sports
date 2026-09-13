import SwiftUI
import os

/// Tap a game, land somewhere worth landing: header, linescore, scoring
/// plays, team stats, leaders.
struct GameDetailScreen: View {
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "gamedetail")

    let game: Game

    @Environment(\.scenePhase) private var scenePhase

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
    /// The matchup-standings card's data; a miss just hides the card.
    @State private var conferenceStandings: [ConferenceStandings] = []
    @State private var tab: Tab = .summary
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
    private var currentStandings: [ConferenceStandings] {
        loadedKey == game.routeKey ? conferenceStandings : []
    }

    /// Raw values order the tabs — the slide direction is an ordinal
    /// comparison. Summary keeps every card the screen has always had,
    /// minus Drives, which moved into Plays (2026-09-06); Plays sits in
    /// the middle because chronology comes before rosters.
    private enum Tab: Int, HeroTabItem {
        case summary, plays, boxScore

        var title: String {
            switch self {
            case .summary: "Summary"
            case .plays: "Plays"
            case .boxScore: "Box score"
            }
        }
    }

    /// A tab only exists where its data does. Pre-kick games, CFBD's
    /// feed, and any game ESPN hasn't filled in show Summary alone and
    /// no tab row — exactly as they did before either tab existed.
    private var availableTabs: [Tab] {
        guard let summary else { return [.summary] }
        var tabs: [Tab] = [.summary]
        if hasDrives(summary) || !summary.plays.isEmpty { tabs.append(.plays) }
        if !summary.boxScore.isEmpty { tabs.append(.boxScore) }
        return tabs
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
        ScrollView {
            VStack(spacing: 0) {
                // The header sits on the card surface — headers match the
                // cards on every entity page (Andy, 2026-08-31); the
                // content below stays in cards on the recessed one.
                VStack(spacing: 0) {
                    header
                    if showsTabs {
                        // Leading, with the entity pages' Spacing.lg gutter —
                        // Team and Conference anchor their tab rows to the
                        // left edge and this is the same component.
                        HeroTabBar(tabs: availableTabs, selection: tab,
                                   onSelect: { select(tab: $0) })
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.lg)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.bgCard)
                if let summary {
                    Group {
                        // A tab whose data went away between polls falls
                        // back rather than rendering an empty pane.
                        let shown: Tab = availableTabs.contains(tab) ? tab : .summary
                        switch shown {
                        case .boxScore:
                            BoxScoreList(summary: summary)
                                .padding(Spacing.sm)
                        case .plays:
                            playsPane(summary)
                        case .summary:
                            summaryCards(summary)
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
                                guard showsTabs, abs(dx) > 50,
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
        // The card color through the top bounce, matching the entity pages.
        .heroTopBand(Color.bgCard)
        .background(Color.bgRecessed)
        .navigationTitle(game.shortName ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgCard, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            #if canImport(ActivityKit)
            ToolbarItem(placement: .topBarTrailing) {
                // Renders nothing until path 3's service exists — see
                // LiveActivityController.isAvailable.
                GameActivityPinButton(game: game, summary: summary)
            }
            #endif
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
        // The third of the app's three haptics: a live score changing under
        // your thumb. Detail-screen only — the scoreboard's 60-game poll
        // would machine-gun the Taptic engine.
        .sensoryFeedback(.impact(weight: .medium), trigger: currentScores) { _, _ in
            isLiveNow
        }
        // Keyed by the game, not fire-once: a screen reused for another
        // game must fetch that game rather than sit on what it holds.
        .task(id: game.routeKey) { await load() }
        // 30s auto-refresh mirrors the scoreboard's polling rules: only while
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
        .refreshable { await load(force: true) }
    }

    private var isLiveNow: Bool { GameHeaderState.isLive(game, summary) }

    /// What restarts the poll loop: the game, and whether it should be
    /// running at all.
    private var pollKey: String {
        "\(game.routeKey):\(scenePhase == .active && isLiveNow)"
    }

    /// The header's "where do I watch" line — live, or pre-game, where the
    /// kickoff split left the network without the second line it used to
    /// ride in on. Gated on the summary-fresher status so it retires the
    /// moment the game goes final.
    private var headerBroadcast: String? {
        (isLiveNow || kickoff != nil) ? game.broadcast : nil
    }

    /// Pre-game only: the kickoff time and its date, rendered as two lines.
    private var kickoff: (time: String, date: String?)? {
        GameHeaderState.kickoff(game, summary)
    }

    /// What VoiceOver hears where the header shows its status — the split
    /// kickoff read back as one sentence.
    private var headerStatusSpoken: String {
        guard let kickoff else {
            return statusLine.replacingOccurrences(of: "\n", with: ", ")
        }
        return [kickoff.date, kickoff.time].compactMap { $0 }.joined(separator: ", ")
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
    private var header: some View {
        let away = competitor(game.away, summary?.away)
        let home = competitor(game.home, summary?.home)
        return HStack(alignment: .top, spacing: Spacing.lg) {
            headerSide(away)
            VStack(spacing: Spacing.xs) {
                // The merge, not the pushed snapshot: `game` is frozen at
                // push, so a game that ends while its detail is open would
                // keep a pulsing dot above the word "Final".
                if isLiveNow { LiveDot() }
                // With scores in play the matchup's number is the page's
                // headline: one big centered score between the logos
                // (FotMob's full-time layout), status demoted beneath it.
                if showsScores, let awayScore = away.score, let homeScore = home.score {
                    scoreLine(away: (awayScore, away.winner), home: (homeScore, home.winner))
                }
                // Before kickoff the time IS the headline — it takes the
                // slot the score takes once there is one, with the date as
                // its caption rather than a phrase joined on with "at".
                if let kickoff {
                    Text(kickoff.time)
                        .font(.kickoffHero)
                        .foregroundStyle(.textPrimary)
                        // Same reason the score line keeps its intrinsic
                        // width: the equal-thirds header would wrap it.
                        .fixedSize()
                    if let date = kickoff.date {
                        Text(date)
                            .font(.teamName)
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text(statusLine)
                        .font(.metaEmphasis)
                        .foregroundStyle(showsScores ? .textSecondary : .textPrimary)
                        .multilineTextAlignment(.center)
                }
                // Live is the one state with no other network surface —
                // pre-game has the info card, finals have nothing left to
                // tune into. Detail screen only: the share card's status
                // stays score-shaped.
                if let broadcast = headerBroadcast {
                    Text(broadcast)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, showsScores ? 0 : Spacing.sm)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                ([headerStatusSpoken]
                    + (headerBroadcast.map { ["on \($0)"] } ?? []))
                    .joined(separator: ", "))
            headerSide(home)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
    }

    /// The centered "24 – 17": the loser's number keeps the muted ink the
    /// per-side scores carried, so the winner still reads without color.
    private func scoreLine(away: (score: Int, winner: Bool?),
                           home: (score: Int, winner: Bool?)) -> some View {
        (Text("\(away.score)")
            .foregroundStyle(away.winner == false ? Color.textSecondary : Color.textPrimary)
            + Text(" – ").foregroundStyle(Color.textSecondary)
            + Text("\(home.score)")
            .foregroundStyle(home.winner == false ? Color.textSecondary : Color.textPrimary))
            .font(isLiveNow ? .scoreHeroLive : .scoreHero)
            // The equal-thirds header would wrap this line; let it keep its
            // intrinsic width and the flexible sides absorb the difference.
            .fixedSize()
    }

    // Delegated to GameHeaderState so the share card provably renders the
    // same merge and status strings as this header.
    private func competitor(_ fallback: Competitor, _ side: GameSummary.Side?)
        -> (team: Team, score: Int?, record: String?, winner: Bool?) {
        GameHeaderState.competitor(fallback, side)
    }

    private func headerSide(_ side: (team: Team, score: Int?, record: String?, winner: Bool?)) -> some View {
        // Value-based so the push lands in the Scores stack's NavigationPath;
        // ScoresScreen owns the matching Team destination.
        NavigationLink(value: side.team) {
            VStack(spacing: Spacing.xs) {
                LogoImage(url: side.team.logoURL)
                    .frame(width: 44, height: 44)
                Text(side.team.location)
                    .font(side.winner == true ? .teamNameEmphasis : .teamName)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    // Reserved so a wrapping name ("Arkansas-Pine Bluff")
                    // doesn't push its record below the other side's.
                    .lineLimit(2, reservesSpace: true)
                if let record = side.record {
                    Text(record)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(sideAccessibilityLabel(side))
        }
        .buttonStyle(.plain)
    }

    /// Internal for AccessibilityLabelTests.
    func sideAccessibilityLabel(_ side: (team: Team, score: Int?, record: String?, winner: Bool?)) -> String {
        guard showsScores, let score = side.score else { return side.team.location }
        return "\(side.team.location) \(score)"
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

    /// Every card the screen has always had, in the order it had them —
    /// the Box score tab is additive, so nothing here moved.
    @ViewBuilder
    private func summaryCards(_ summary: GameSummary) -> some View {
        VStack(spacing: Spacing.sm) {
                    // The Gamecast strip leads while a game is live: the
                    // down, the spot, and the last play are what the page
                    // is being opened for at 3:30 on a Saturday.
                    if let situation = summary.situation {
                        card(title: "Current drive") {
                            LiveSituationCard(summary: summary, situation: situation)
                        }
                    }
                    // When and where to watch is one question; the
                    // ground it's played on is another (FotMob's Preview
                    // cards, monochrome). Pre-kick the sections below are
                    // all empty, so the pair carries the whole "what do I
                    // need to know" load — but the questions outlive the
                    // kickoff, so Game info stays put once a game starts.
                    if KickoffInfoRows.hasContent(game: game, summary: summary) {
                        card(title: "Game info") {
                            KickoffInfoRows(game: game, summary: summary)
                        }
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
            lastError = nil
            tab = .summary
            scoringOnly = false
            shareCardPNG = nil
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
        let needsStandings = isCurrentSeason && conferenceStandings.isEmpty
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
        } catch {
            guard game.routeKey == key else { return }
            lastError = "Couldn't load this game."
        }
        if let loaded = await standingsFetch, game.routeKey == key {
            conferenceStandings = loaded
        }
        await refreshPinnedActivity()
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
