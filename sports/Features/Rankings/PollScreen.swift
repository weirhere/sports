import SwiftUI

/// The poll, on the entity-page template ConferencePage and TeamPage share
/// (Andy, 2026-09-05): hero mark and title, a Standings / Games tab pair,
/// content as cards on the recessed ground, and the follow pill on the
/// toolbar row. Season, week and poll are chips over the table.
///
/// The Top 25 *is* an entity here, and its members are the 25 ranked teams
/// — so Standings is the poll table (rendered in the standings tables' own
/// column language) and Games is those teams' season slate, one card per
/// week, exactly as a conference's is (Andy, 2026-09-05: "mirror the ui of
/// all the other league/conference pages").
///
/// Which poll is a filter, not a tab: AP, Coaches and CFP are the same
/// table of the same 25 teams, read by different voters, so they belong on
/// one menu chip above the table rather than splitting the page in two
/// (Andy, 2026-09-05, superseding the segmented picker). CFP only appears
/// from late October, when ESPN starts returning it. The chosen poll scopes
/// the Games tab too — its 25 teams are the slate's members.
struct PollScreen: View {
    /// The FBS polls we show, in picker order. ESPN's response also
    /// carries the FCS and DII/DIII polls — filtered out.
    private static let displayedTypes = ["ap", "usa", "cfp"]

    /// The polls the app shows, in picker order — one place, because the
    /// hub's row and this page have to agree on which poll is "first".
    static func displayed(_ polls: [Poll]) -> [Poll] {
        displayedTypes.compactMap { type in polls.first { $0.type == type } }
    }

    /// Raw values order the tabs — the slide direction is an ordinal
    /// comparison (TeamPage's rule).
    private enum Tab: Int, HeroTabItem {
        case standings, games, postseason

        var title: String {
            switch self {
            case .standings: "Standings"
            case .games: "Games"
            case .postseason: "Postseason"
            }
        }
    }

    /// The current season's polls where the caller already has them — the
    /// tables hub fetched them for its own row. Empty is a legitimate
    /// push: the Scores Top 25 header holds no polls, so the page fetches
    /// the season in progress the same way it fetches every other one.
    var polls: [Poll] = []
    /// Whose poll this is — the follow control's id.
    var league: League = .collegeFootball

    @Environment(UIStateStore.self) private var uiState
    @State private var showsInlineTitle = false
    @State private var tab: Tab = .standings
    /// Which edge incoming tab content pushes from — right walking Games →
    /// Standings, left coming back (TeamPage's rule).
    @State private var tabSlideEdge: Edge = .trailing
    /// How far the hero has collapsed under the bar (`CollapsingHeaderScrollView`).
    @State private var heroCollapse: CGFloat = 0

    /// Nil means the season in progress, which needs no fetch of its own.
    @State private var pickedYear: Int?
    /// Past seasons, cached per page visit like TeamPage's schedules.
    @State private var pollsByYear: [Int: [Poll]] = [:]
    @State private var loadingYears: Set<Int> = []
    @State private var failedYears: Set<Int> = []

    /// Each season's published weeks, oldest first, fetched beside its
    /// polls. A season whose list doesn't come back just shows no week
    /// chip — its latest table is still the page.
    @State private var weeksByYear: [Int: [PollWeek]] = [:]
    /// The week picked on the chip; nil is the season's latest (Andy,
    /// 2026-09-27): the current week while a season runs, the final polls
    /// once it's over. Cleared by a season switch.
    @State private var pickedWeek: PollWeek?
    /// Weeks before the latest, fetched on pick and kept for the visit.
    @State private var weekPolls: [SeasonWeek: [Poll]] = [:]
    @State private var loadingWeeks: Set<SeasonWeek> = []
    @State private var failedWeeks: Set<SeasonWeek> = []

    private struct SeasonWeek: Hashable {
        let year: Int
        let week: PollWeek
    }

    /// The ranked teams' season slate, per year — one request each, kept
    /// for the visit.
    @State private var gamesByYear: [Int: [Game]] = [:]
    @State private var gamesLoadingYears: Set<Int> = []
    @State private var gamesFailedYears: Set<Int> = []

    /// Optional like ConferencePage's: without the scoreboard in the
    /// environment the slate simply stays the snapshot it was fetched as.
    @Environment(LeagueScoreboards.self) private var scoreboards: LeagueScoreboards?

    /// How the Games tab heads its cards, and whose games it shows.
    /// Weeks and Date are on/off toggles over the same slate — a view
    /// choice, not a narrowing — and they're alternatives, so turning one
    /// on turns the other off (Andy, 2026-09-05). Both off is one
    /// chronological card. Team is the filter.
    @State private var grouping: ConferenceSlate.Grouping = .week
    @State private var teamFilter: String?
    /// The Postseason tab's round — session-scoped, guarded like the team
    /// filter beside it.
    @State private var postseasonRound: String?

    var body: some View {
        // ConferencePage's shape (2026-09-27): the header rides over the
        // content and collapses as it scrolls, so a Games tab opens on this
        // week with the hero expanded and the tabs and chips in view.
        CollapsingHeaderScrollView(landing: landing, collapse: $heroCollapse) {
            hero
        } strip: {
            pinnedControls
        } content: { headerHeight in
            Group {
                switch tab {
                case .standings: standingsSection
                case .games: gamesSection(scrollInset: headerHeight)
                case .postseason: postseasonSection
                }
            }
            .transition(.push(from: tabSlideEdge))
            .geometryGroup()
            .id(tab)
        }
        // ConferencePage's handoff: once the hero's own title scrolls under
        // the bar, the bar takes over the identity.
        .onChange(of: heroCollapse > 64) { _, scrolledPastHero in
            withAnimation(.easeInOut(duration: 0.15)) {
                showsInlineTitle = scrolledPastHero
            }
        }
        .heroTopBand(Color.bgCard)
        .background(Color.bgRecessed)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgCard, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Top 25")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .opacity(showsInlineTitle ? 1 : 0)
                    .accessibilityHidden(!showsInlineTitle)
            }
            // The season chip leads each pane's control row instead
            // (2026-09-27) — see `seasonChip`.
            ToolbarItemGroup(placement: .topBarTrailing) {
                PollFollowPill(league: league)
            }
        }
        .task {
            async let poll: Void = load(year: year)
            async let weeks: Void = loadWeeks(year: year)
            async let games: Void = loadGames(year: year)
            _ = await (poll, weeks, games)
        }
    }

    // MARK: - Season

    private var currentYear: Int { SeasonYear.year(for: league) }

    private var year: Int { pickedYear ?? currentYear }

    private var availableSeasons: [Int] {
        Array(stride(from: currentYear, through: league.seasonFloor, by: -1))
    }

    /// The shown season's polls. The current one came in with the push
    /// where the caller had it; every other — and the current one on a
    /// push that carried none — is fetched on demand and kept.
    ///
    /// A picked week other than the latest reads from its own fetch; the
    /// latest *is* the season's table, so picking it back costs nothing.
    private var seasonPolls: [Poll] {
        if let key = pickedPastWeek { return weekPolls[key] ?? [] }
        if year == currentYear, !polls.isEmpty { return Self.displayed(polls) }
        return pollsByYear[year] ?? []
    }

    // MARK: - Week

    private var seasonWeeks: [PollWeek] { weeksByYear[year] ?? [] }

    /// What the week chip reads: the pick, or the season's newest week.
    private var shownWeek: PollWeek? { pickedWeek ?? seasonWeeks.last }

    /// A pick that needs its own fetch — anything but the latest week.
    private var pickedPastWeek: SeasonWeek? {
        guard let pickedWeek, pickedWeek != seasonWeeks.last else { return nil }
        return SeasonWeek(year: year, week: pickedWeek)
    }

    private var tableIsLoading: Bool {
        pickedPastWeek.map { loadingWeeks.contains($0) } ?? loadingYears.contains(year)
    }

    private var tableFailed: Bool {
        pickedPastWeek.map { failedWeeks.contains($0) } ?? failedYears.contains(year)
    }

    private func retryTable() async {
        if let key = pickedPastWeek {
            await load(week: key, force: true)
        } else {
            await load(year: year, force: true)
        }
    }

    private func select(week value: PollWeek) {
        guard value != shownWeek else { return }
        pickedWeek = value
        guard let key = pickedPastWeek else { return }
        Task { await load(week: key) }
    }

    private func loadWeeks(year value: Int) async {
        guard weeksByYear[value] == nil else { return }
        // A miss hides the chip rather than failing the page, and isn't
        // cached, so the next visit to the season asks again.
        if let weeks = try? await DataProvider.makeClient(league: league).rankingWeeks(year: value) {
            weeksByYear[value] = weeks
        }
    }

    private func load(week key: SeasonWeek, force: Bool = false) async {
        guard weekPolls[key] == nil || force else { return }
        guard !loadingWeeks.contains(key) else { return }
        loadingWeeks.insert(key)
        defer { loadingWeeks.remove(key) }
        do {
            let fetched = try await DataProvider.makeClient(league: league)
                .rankings(year: key.year, week: key.week)
            weekPolls[key] = Self.displayed(fetched)
            failedWeeks.remove(key)
        } catch {
            failedWeeks.insert(key)
        }
    }

    private var selectedPoll: Poll? {
        seasonPolls.first { $0.type == uiState.pollChoice } ?? seasonPolls.first
    }

    private func select(year value: Int) {
        guard value != year else { return }
        pickedYear = value
        // A week number means nothing across seasons: the new one opens
        // on its own latest, as the page does.
        pickedWeek = nil
        // The grouping is a view choice and carries over; the team pick
        // survives only where the team is still ranked (`activeTeamId`).
        Task {
            async let poll: Void = load(year: value)
            async let weeks: Void = loadWeeks(year: value)
            async let games: Void = loadGames(year: value)
            _ = await (poll, weeks, games)
        }
    }

    private func select(tab value: Tab) {
        guard value != tab else { return }
        // The edge commits before the switch so the outgoing pane's
        // `.push` resolves against it (TeamPage's split, 2026-08-31).
        tabSlideEdge = value.rawValue > tab.rawValue ? .trailing : .leading
        Task { @MainActor in
            withAnimation(.default) { tab = value }
        }
    }

    private func load(year value: Int, force: Bool = false) async {
        // The season in progress arrived with the push where the push
        // carried one, and a season already fetched is a season already
        // fetched.
        guard value != currentYear || polls.isEmpty else { return }
        guard pollsByYear[value] == nil || force else { return }
        guard !loadingYears.contains(value) else { return }
        loadingYears.insert(value)
        defer { loadingYears.remove(value) }
        do {
            let fetched = try await DataProvider.makeClient(league: league).rankings(year: value)
            pollsByYear[value] = Self.displayed(fetched)
            failedYears.remove(value)
        } catch {
            failedYears.insert(value)
        }
    }

    /// The season's whole FBS slate in one request — the ranked teams'
    /// games are a filter over it, not 25 schedule fetches. `groups=80`
    /// with `dates={year}` returns the full season (verified live
    /// 2026-09-05: 800 events for 2025), which is the same request
    /// ConferencePage makes for one conference.
    private func loadGames(year value: Int, force: Bool = false) async {
        guard gamesByYear[value] == nil || force else { return }
        guard !gamesLoadingYears.contains(value) else { return }
        gamesLoadingYears.insert(value)
        defer { gamesLoadingYears.remove(value) }
        do {
            gamesByYear[value] = try await DataProvider.makeClient(league: league)
                .seasonGames(year: value)
            gamesFailedYears.remove(value)
        } catch {
            gamesFailedYears.insert(value)
        }
    }

    // MARK: - Hero

    /// The conference hero's shape, wearing the hub row's trophy.
    private var hero: some View {
        HStack(spacing: Spacing.md) {
            // The trophy, not the league's football (Andy, 2026-09-27) —
            // the hub row's mark since 2026-09-21, and the Leagues tab's
            // glyph, so the row and the page it opens agree. Black ink in
            // both modes: the disc behind it is light in dark mode and
            // clear on the light hero, which is exactly where a crest's
            // own dark ink would sit.
            Image(systemName: "trophy.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.black)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.logoBacking).padding(-6))
                .padding(6)
            VStack(alignment: .leading, spacing: 2) {
                Text("Top 25")
                    .font(.heroTitle)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                // No subtitle (Andy, 2026-09-27): ESPN's headline ("2025
                // AP Poll: Final Rankings") said which season, poll and
                // week, and the chips over the table now say all three.
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgCard)
    }

    private var tabRow: some View {
        // Unpadded: HeroTabBar carries its own gutter so tabs scroll out
        // at the surface edge (2026-09-21).
        HeroTabBar(tabs: availableTabs, selection: tab,
                   onSelect: { select(tab: $0) })
    }

    /// The sticky header — the tab row and the pane's control row, both
    /// painting their own surface so content can slide under them
    /// (ConferencePage's `pinnedControls`).
    private var pinnedControls: some View {
        VStack(spacing: 0) {
            tabRow
                // Reaches above the strip's frame to cover the seam a
                // pinned header leaves under the bar.
                .background(Color.bgCard.padding(.top, -Spacing.sm))
            VStack(spacing: 0) {
                controlRow(for: tab)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.sm)
                // The gap that used to be the pane's own top padding.
                Color.clear.frame(height: Spacing.sm)
            }
            .frame(maxWidth: .infinity)
            .background(Color.bgRecessed)
        }
    }

    /// The season leads every tab's row; after it, what shapes this pane
    /// alone — the week and poll on Standings, the slate toggles on Games,
    /// nothing on Postseason, whose round chips live in the pane.
    private func controlRow(for tab: Tab) -> some View {
        SeasonControlRow(season: seasonChip) {
            switch tab {
            case .standings:
                if let shownWeek, seasonWeeks.count > 1 {
                    PollWeekMenuChip(weeks: seasonWeeks, current: shownWeek,
                                     onSelect: { select(week: $0) })
                }
                if seasonPolls.count > 1 {
                    PollMenuChip(polls: seasonPolls, current: selectedPoll?.type,
                                 onSelect: { uiState.pollChoice = $0 })
                }
            case .games:
                SlateControlRow(grouping: grouping,
                                onToggle: { toggle($0) },
                                teams: filterableTeams,
                                teamSelection: activeTeamId,
                                onSelectTeam: { teamFilter = $0 })
            case .postseason:
                EmptyView()
            }
        }
    }

    // MARK: - Standings

    private var standingsSection: some View {
        standingsContent
            // No top padding: the pinned header carries it.
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.sm)
    }

    /// The season picker leads every pane's control row, above the cards
    /// it scopes (Andy, 2026-09-27, superseding the 2026-09-05 move onto
    /// the toolbar row), with the pane's own controls after it: the poll
    /// picker on Rankings, the slate toggles on Games.
    private var seasonChip: SeasonMenuChip {
        SeasonMenuChip(current: year, seasons: availableSeasons, league: league,
                       onSelect: { select(year: $0) })
    }

    @ViewBuilder
    private var standingsContent: some View {
        if let poll = selectedPoll, !poll.ranks.isEmpty {
            pollCard(poll)
        } else if tableIsLoading {
            // A lone spinner gets no card — a surface around it hugs into
            // a floating pill (Andy, 2026-08-31).
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
        } else if tableFailed {
            StatusMessage(text: "Couldn't load the poll.",
                          retry: { Task { await retryTable() } })
                .cardSurface()
        } else {
            // A season ESPN has no poll for — the preseason before the
            // first vote drops, or a year the core API comes back empty on.
            StatusMessage(text: "No poll for this season.")
                .cardSurface()
        }
    }

    private func pollCard(_ poll: Poll) -> some View {
        VStack(spacing: 0) {
            RankColumnCaptions()
            LazyVStack(spacing: 0) {
                ForEach(poll.ranks) { ranked in
                    NavigationLink {
                        TeamPage(team: ranked.team)
                    } label: {
                        RankRow(ranked: ranked)
                    }
                    .buttonStyle(.plain)
                    if ranked.id != poll.ranks.last?.id {
                        Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                    }
                }
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    // MARK: - Games

    /// The season's slate narrowed to the poll's own teams — the app's
    /// "any ranked participant" rule (2026-07-21), which is what a Top 25
    /// slate has always meant here.
    /// The season slate through the shared live merge. It's fetched once
    /// per visit and never polled, so without this a live game froze at
    /// the score it had when the page opened and a pre-game row never
    /// turned live at all.
    private var slate: [Game]? {
        guard let games = gamesByYear[year] else { return nil }
        return Game.merging(games, withLive: scoreboards?.store(for: league).boardGames ?? [])
    }

    private var rankedGames: [Game]? {
        guard let games = slate, let poll = selectedPoll else { return nil }
        let ranked = Set(poll.ranks.map(\.team.id))
        return games.filter { ranked.contains($0.home.team.id) || ranked.contains($0.away.team.id) }
    }

    /// The teams the team chip can offer: this poll's 25, in rank order,
    /// so the menu reads like the table above it.
    private var filterableTeams: [Team] {
        selectedPoll?.ranks.map(\.team) ?? []
    }

    /// A team pick survives a season switch only where that season's poll
    /// still ranks the team — otherwise the pane would filter to a team
    /// this table never had.
    private var activeTeamId: String? {
        guard let teamFilter, filterableTeams.contains(where: { $0.id == teamFilter }) else {
            return nil
        }
        return teamFilter
    }

    private var activeTeamName: String? {
        filterableTeams.first { $0.id == activeTeamId }?.location
    }

    /// The whole season, postseason included (Andy, 2026-09-06): the
    /// bracket answers "who plays whom", this tab answers "when", and a
    /// playoff game is easiest to find in date order with everything else.
    private var filteredGames: [Game]? {
        guard let rankedGames else { return nil }
        return ConferenceSlate.games(rankedGames, forTeamId: activeTeamId)
    }

    /// Postseason only where the season has one. This page is college
    /// football's league-wide entity — the poll's own 25 teams don't scope
    /// it, because a bowl slate is the division's, not the Top 25's, and a
    /// postseason narrowed to ranked teams would drop most of the bowls.
    private var availableTabs: [Tab] {
        postseasonRounds.isEmpty ? [.standings, .games] : [.standings, .games, .postseason]
    }

    private var postseasonRounds: [PostseasonRound] {
        Postseason.rounds(from: slate ?? [], league: league)
    }

    private var activePostseasonRound: String? {
        let rounds = postseasonRounds
        if let postseasonRound, rounds.contains(where: { $0.name == postseasonRound }) {
            return postseasonRound
        }
        return Postseason.defaultRound(in: rounds)
    }

    private var postseasonSection: some View {
        PostseasonSection(rounds: postseasonRounds,
                          exhibition: Postseason.exhibition(from: slate ?? [],
                                                            league: league),
                          selection: activePostseasonRound,
                          onSelectRound: { postseasonRound = $0 })
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.sm)
    }

    /// ConferencePage's landing rule: Games on this week, every other tab
    /// straight back to the top.
    private var landing: ScrollLanding {
        ScrollLanding(key: "\(tab)",
                      target: tab == .games
                          ? gamesOpeningCardId.map(ConferenceGamesList.scrollAnchor(for:))
                          : nil)
    }

    private func gamesSection(scrollInset: CGFloat) -> some View {
        gamesContent(scrollInset: scrollInset)
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.sm)
    }

    private var gamesOpeningCardId: String? {
        filteredGames.flatMap { ConferenceSlate.openingCardId(games: $0, by: grouping) }
    }

    /// Turning a grouping on turns the other off — they're two answers to
    /// one question. Turning the on one off leaves the slate ungrouped.
    private func toggle(_ value: ConferenceSlate.Grouping) {
        withAnimation(.default) {
            grouping = grouping == value ? .none : value
        }
    }

    @ViewBuilder
    private func gamesContent(scrollInset: CGFloat) -> some View {
        if let filteredGames, !filteredGames.isEmpty {
            ConferenceGamesList(games: filteredGames, grouping: grouping,
                                scrollInset: scrollInset)
        } else if hasNarrowedToNothing {
            // The narrowed-empty state, Scores' rule (2026-08-29): name
            // what's hiding the games and offer them back, so a filtered
            // pane never reads as a missing schedule.
            StatusMessage(text: narrowedEmptyText,
                          actionTitle: "Show all games",
                          retry: { teamFilter = nil })
                .cardSurface()
        } else if gamesLoadingYears.contains(year) {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
        } else if gamesFailedYears.contains(year) {
            StatusMessage(text: "Couldn't load the schedule.",
                          retry: { Task { await loadGames(year: year, force: true) } })
                .cardSurface()
        } else {
            StatusMessage(text: "Schedule TBA")
                .cardSurface()
        }
    }

    private var hasNarrowedToNothing: Bool {
        rankedGames?.isEmpty == false && activeTeamId != nil
    }

    /// Names what's hiding the games, so the way out is obvious.
    private var narrowedEmptyText: String {
        guard let activeTeamName else { return "No \(year) games" }
        return "No \(year) games for \(activeTeamName)"
    }

    static func label(for poll: Poll) -> String {
        switch poll.type {
        case "ap": "AP"
        case "usa": "Coaches"
        case "cfp": "CFP"
        default: poll.shortName ?? poll.name
        }
    }
}
