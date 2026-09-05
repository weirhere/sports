import SwiftUI
import os

/// Tap a game, land somewhere worth landing: header, linescore, scoring
/// plays, team stats, leaders.
struct GameDetailScreen: View {
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "gamedetail")

    let game: Game

    @Environment(\.scenePhase) private var scenePhase

    @State private var summary: GameSummary?
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

    /// Raw values order the tabs — the slide direction is an ordinal
    /// comparison. Summary keeps every card the screen has always had, in
    /// the order it had them; Box score is purely additive.
    private enum Tab: Int, HeroTabItem {
        case summary, boxScore

        var title: String {
            switch self {
            case .summary: "Summary"
            case .boxScore: "Box score"
            }
        }
    }

    /// No player stats, no tab row: pre-kick games, CFBD's feed, and any
    /// game ESPN hasn't filled in look exactly as they did before.
    private var showsTabs: Bool { !(summary?.boxScore.isEmpty ?? true) }

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
                        HeroTabBar(tabs: [.summary, .boxScore], selection: tab,
                                   onSelect: { select(tab: $0) })
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.lg)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.bgCard)
                if let summary {
                    Group {
                        if tab == .boxScore, showsTabs {
                            BoxScoreList(summary: summary)
                                .padding(Spacing.sm)
                        } else {
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
                                guard showsTabs, abs(dx) > 50,
                                      abs(dx) > abs(value.translation.height) * 1.5,
                                      let target = Tab(rawValue: tab.rawValue + (dx < 0 ? 1 : -1))
                                else { return }
                                select(tab: target)
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
        .task { await load() }
        // 30s auto-refresh mirrors the scoreboard's polling rules: only while
        // the scene is active and the game is in progress. The id flips when
        // either condition changes, cancelling or restarting the loop — a
        // summary that comes back final stops it on its own.
        .task(id: scenePhase == .active && isLiveNow) {
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

    /// The header's "where do I watch" line, live only — gated on the
    /// summary-fresher status so it retires the moment the game goes final.
    private var liveBroadcast: String? { isLiveNow ? game.broadcast : nil }

    /// Past-season games (pushed from a flipped team schedule) must not
    /// wear the current season's standings.
    private var isCurrentSeason: Bool {
        game.date.map { CFBSeason.year(for: $0) == CFBSeason.year() } ?? false
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
                Text(statusLine)
                    .font(.metaEmphasis)
                    .foregroundStyle(showsScores ? .textSecondary : .textPrimary)
                    .multilineTextAlignment(.center)
                // Live is the one state with no other network surface —
                // pre-game has the info card (and statusLine's own second
                // line), finals have nothing left to tune into. Detail
                // screen only: the share card's status stays score-shaped.
                if let broadcast = liveBroadcast {
                    Text(broadcast)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, showsScores ? 0 : Spacing.md)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                ([statusLine.replacingOccurrences(of: "\n", with: ", ")]
                    + (liveBroadcast.map { ["on \($0)"] } ?? []))
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
                    // Pre-kick, the sections below are all empty — the
                    // game-info card carries the "what do I need to
                    // know" load (FotMob's Preview cards, monochrome).
                    if !showsScores {
                        card(title: "Game info") { gameInfoRows(summary) }
                    }
                    if summary.away?.linescores.isEmpty == false {
                        card { LineScoreGrid(summary: summary) }
                    }
                    if !summary.scoringPlays.isEmpty {
                        card(title: "Scoring") { ScoringPlaysList(summary: summary) }
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
                                                   standings: conferenceStandings) {
                        card(title: "Standings") {
                            MatchupStandings(away: game.away.team,
                                             home: game.home.team,
                                             standings: conferenceStandings)
                        }
                    }
                    if !summary.drives.isEmpty {
                        card(title: "Drives") { DriveLogList(summary: summary) }
                    }
                    // Pre-game the info card already places the game;
                    // once scores exist it returns as the venue card.
                    if showsScores, summary.venue != nil || summary.attendance != nil {
                        card(title: "Game info") { venueRows(summary) }
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

    /// The pre-game card's rows: kickoff, network, venue, surface,
    /// weather — whatever the payload actually knows, one line each.
    @ViewBuilder
    private func gameInfoRows(_ summary: GameSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let date = game.date {
                infoRow("calendar",
                        game.timeTBD
                            ? "\(GameRow.relativeKickParts(date, weekday: .abbreviated).day) · Kickoff TBD"
                            : GameRow.relativeKick(date, weekday: .abbreviated))
            }
            if let broadcast = game.broadcast {
                infoRow("tv", broadcast)
            }
            if let venue = summary.venue {
                infoRow("mappin.and.ellipse",
                        [venue, summary.venueCity].compactMap { $0 }.joined(separator: " · "))
            }
            if summary.venueCapacity != nil || summary.grassSurface != nil {
                let capacity = summary.venueCapacity.map { "Capacity \($0.formatted())" }
                let surface = summary.grassSurface.map { $0 ? "Grass" : "Turf" }
                infoRow("sportscourt", [capacity, surface].compactMap { $0 }.joined(separator: " · "))
            }
            let weatherLine = [summary.weatherTemperature.map { "\($0)°" },
                               summary.weatherCondition]
                .compactMap { $0 }.joined(separator: " · ")
            if !weatherLine.isEmpty {
                infoRow("cloud.sun", weatherLine)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func infoRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.textSecondary)
                .frame(width: 20)
            Text(text)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
    }

    /// The Team stats card's column legend, formerly the sub-view's own
    /// header trailing text.
    private func statsLegend(_ summary: GameSummary) -> String {
        "\(summary.away?.team.abbreviation ?? "AWAY") · \(summary.home?.team.abbreviation ?? "HOME")"
    }

    /// The live/final counterpart to the pre-game info rows: where the
    /// game is (was) and how many showed up.
    @ViewBuilder
    private func venueRows(_ summary: GameSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let venue = summary.venue {
                infoRow("mappin.and.ellipse",
                        [venue, summary.venueCity].compactMap { $0 }.joined(separator: " · "))
            }
            if let attendance = summary.attendance {
                infoRow("person.2", "Attendance \(attendance.formatted())")
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func load(force: Bool = false) async {
        guard summary == nil || force else { return }
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
            summary = try await client.gameSummary(eventId: game.id)
            lastError = nil
        } catch {
            lastError = "Couldn't load this game."
        }
        if let loaded = await standingsFetch {
            conferenceStandings = loaded
        }
    }
}
