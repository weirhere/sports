import SwiftUI

/// One conference's home, on the TeamPage template (Andy's call,
/// 2026-08-25): card-color hero header, Standings and Games tabs
/// (Standings leads since 2026-08-31; the Games tab joined 2026-08-29 —
/// the season's full conference slate, week by week), content as cards on
/// the recessed surface. Standings stay in the provider's order
/// (seed-backed — never re-sorted here).
struct ConferencePage: View {
    let destination: ConferenceDestination

    /// Raw values order the tabs — the slide direction is an ordinal
    /// comparison (TeamPage's rule).
    private enum Tab: Int, HeroTabItem {
        case standings, games

        var title: String {
            switch self {
            case .standings: "Standings"
            case .games: "Games"
            }
        }
    }

    /// Seasons fetched this visit, keyed by year — flipping back to a seen
    /// season costs nothing (TeamPage's caching pattern).
    /// The season's standings tables — one for a conference that ships
    /// its own, one per division for a divisional one (the Sun Belt,
    /// the 2019 AAC), which the page renders as separate tables.
    @State private var standingsByYear: [Int: [ConferenceStandings]] = [:]
    @State private var gamesByYear: [Int: [Game]] = [:]
    @State private var selectedYear = CFBSeason.year()
    /// The Games tab's team filter — a member's team id, nil for the whole
    /// slate. Kept across season switches: `activeTeamFilter` drops it
    /// wherever the team isn't in that season's conference, so flipping to
    /// 2019 and back keeps the pick without ever filtering to a team that
    /// season never had.
    @State private var teamFilter: String?
    /// How the Games tab heads its cards. Weeks is the season's own clock
    /// and stays the default; Date is the other answer, and both off is
    /// one chronological card (Andy, 2026-09-05).
    @State private var grouping: ConferenceSlate.Grouping = .week
    @State private var loadingYears: Set<Int> = []
    @State private var failedYears: Set<Int> = []
    @State private var gamesLoadingYears: Set<Int> = []
    @State private var gamesFailedYears: Set<Int> = []
    @State private var tab: Tab
    /// Which edge incoming tab content pushes from — right walking Games →
    /// Standings, left coming back (TeamPage's rule).
    @State private var tabSlideEdge: Edge = .trailing
    /// True once the hero title has scrolled under the nav bar — the bar's
    /// principal slot then carries the conference name (TeamPage's rule).
    @State private var showsInlineTitle = false

    /// Whether this page is the whole league rather than one of its
    /// conferences — the NFL's 32-team table (Andy, 2026-09-05).
    private var isLeagueWide: Bool {
        destination.conferenceId == Conference.leagueWideId(in: destination.league)
    }

    /// Scoped to this conference's league: group id 8 is the SEC in
    /// college football and the AFC in the NFL.
    private var client: any ScoresProviding {
        DataProvider.makeClient(league: destination.league)
    }

    /// Optional like TeamPage's: the live standings dots degrade to none
    /// wherever the scoreboard isn't in the environment.
    @Environment(LeagueScoreboards.self) private var scoreboards: LeagueScoreboards?

    /// The live board for this conference's league.
    private var liveBoard: ScoreboardStore? { scoreboards?.store(for: destination.league) }

    /// In-progress games for the standings dots — current season only; a
    /// past season's table gets no live claims.
    private var liveGames: [Game] {
        guard selectedYear == CFBSeason.year() else { return [] }
        return liveBoard?.boardGames.filter(\.isLive) ?? []
    }

    init(destination: ConferenceDestination) {
        self.destination = destination
        // Standings lead (Andy, 2026-08-31) — which is also where a
        // standings-anchored push (a team's "3rd in SEC" line) lands.
        _tab = State(initialValue: .standings)
    }

    /// The tables with something in them. A division that ships no entries
    /// yet isn't a card saying nothing.
    private var standingsTables: [ConferenceStandings] {
        (standingsByYear[selectedYear] ?? []).filter { !$0.entries.isEmpty }
    }

    /// Every table's teams: a divisional conference's hero count is the
    /// conference's, not one division's.
    private var teamCount: Int {
        standingsTables.reduce(0) { $0 + $1.entries.count }
    }

    /// Whether those tables are the conference's divisions rather than the
    /// conference itself — the payload's answer, which is the only one that
    /// can't go stale when a conference drops its divisions.
    private var isDivisional: Bool {
        standingsTables.contains { $0.parentId != nil }
    }
    private var isLoading: Bool { loadingYears.contains(selectedYear) }
    private var showsError: Bool { failedYears.contains(selectedYear) }
    private var gamesLoading: Bool { gamesLoadingYears.contains(selectedYear) }
    private var gamesError: Bool { gamesFailedYears.contains(selectedYear) }

    /// Rendered through the shared live merge: the season slate is
    /// fetched once per (conference, year) and never polled — right for a
    /// page that is mostly history — so without this a game that is live
    /// when the page opens freezes at that moment's score. Past seasons
    /// skip the merge outright; nothing in them can be live.
    private var games: [Game]? {
        guard let slate = gamesByYear[selectedYear] else { return nil }
        guard selectedYear == CFBSeason.year() else { return slate }
        return Game.merging(slate, withLive: liveBoard?.boardGames ?? [])
    }

    /// The season slate narrowed to the picked team, which is what the
    /// Games tab actually renders.
    private var filteredGames: [Game]? {
        games.map { ConferenceSlate.games($0, forTeamId: activeTeamFilter) }
    }

    /// The filter's roster: the conference's own members, from the
    /// season's standings — the one list that says who *belongs* rather
    /// than who showed up, since the slate also carries every non-
    /// conference opponent. Where ESPN ships no standings (its Sun Belt
    /// hole, an offseason table) the slate's teams stand in, because a
    /// filter with no names is no filter at all.
    private var filterableTeams: [Team] {
        let members = standingsTables.flatMap(\.entries).map(\.team)
        if !members.isEmpty { return members.sorted { $0.location < $1.location } }
        guard let slate = gamesByYear[selectedYear] else { return [] }
        var seen: Set<String> = []
        return slate
            .flatMap { [$0.away.team, $0.home.team] }
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.location < $1.location }
    }

    /// The pick, honored only while this season's conference actually has
    /// that team. A stale pick reads as "All teams" rather than emptying
    /// the pane with a name that means nothing here.
    private var activeTeamFilter: String? {
        guard let teamFilter,
              filterableTeams.contains(where: { $0.id == teamFilter }) else { return nil }
        return teamFilter
    }

    /// The picked team's own name, for the narrowed empty state.
    private var activeTeamName: String? {
        activeTeamFilter.flatMap { id in filterableTeams.first { $0.id == id }?.location }
    }

    /// Newest first, floored at 2014 — the CFP era, matching the Scores and
    /// TeamPage selectors.
    private var availableSeasons: [Int] {
        Array(stride(from: CFBSeason.year(), through: 2014, by: -1))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Lazy only for the pinning — the stack has two children,
                // and the section's content is the whole pane in one
                // subtree, so every standings row is still realized and
                // `scrollTo` below can find one.
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    heroIdentity
                    Section {
                        Group {
                            switch tab {
                            case .standings: standingsCard
                            case .games: gamesSection
                            }
                        }
                        // geometryGroup pins row logos to the sliding pane —
                        // TeamPage's fix (2026-08-31).
                        .geometryGroup()
                        .id(tab)
                        .transition(.push(from: tabSlideEdge))
                        // The week swipe's sibling (Andy, 2026-08-29): swipe
                        // the content to walk the tab pair; the buttons stay.
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { value in
                                    let dx = value.translation.width
                                    guard abs(dx) > 50,
                                          abs(dx) > abs(value.translation.height) * 1.5,
                                          let target = Tab(rawValue: tab.rawValue + (dx < 0 ? 1 : -1))
                                    else { return }
                                    select(tab: target)
                                }
                        )
                    } header: {
                        pinnedControls
                    }
                }
            }
            // The anchor scroll: a push from a TeamPage lands with the
            // team's own row in view, FotMob's table pattern. The Games
            // tab deliberately has no equivalent — the page opens at the
            // top with the hero in view (Andy, 2026-08-29, reverting the
            // scroll-to-current-week first cut).
            .onChange(of: standingsTables) { _, loaded in
                guard tab == .standings,
                      let target = destination.highlightTeamId,
                      loaded.contains(where: { table in
                          table.entries.contains { $0.team.id == target }
                      }) else { return }
                proxy.scrollTo(target, anchor: .center)
            }
        }
        // Once the hero's own title scrolls under the bar, the bar takes
        // over the identity — TeamPage's handoff. The threshold is this
        // hero's own: the title row ends ~68pt down (12 top + the 56pt
        // logo row), not TeamPage's 120.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 64
        } action: { _, scrolledPastHero in
            withAnimation(.easeInOut(duration: 0.15)) {
                showsInlineTitle = scrolledPastHero
            }
        }
        // The hero's top-bounce paint; the bar itself is solid bgCard
        // here, so this only shows while rubber-banding.
        .heroTopBand(Color.bgCard)
        .background(Color.bgRecessed)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgCard, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(destination.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .opacity(showsInlineTitle ? 1 : 0)
                    .accessibilityHidden(!showsInlineTitle)
            }
            // The follow pill rides the toolbar row, FotMob's pattern
            // (Andy, 2026-08-31), and the season chip came back up beside
            // it (Andy, 2026-09-05, superseding the move into the panes):
            // the season scopes the whole page, both tabs, so it belongs
            // with the page's identity rather than above one pane's cards.
            // Declaration order is left-to-right — season, then follow.
            ToolbarItemGroup(placement: .topBarTrailing) {
                SeasonMenuChip(current: selectedYear, seasons: availableSeasons,
                               style: .bar, onSelect: { select(year: $0) })
                ConferenceFollowPill(conference: destination.conference)
            }
        }
        .task { await load(year: selectedYear) }
    }

    // MARK: - Hero

    /// Just the identity now — the tab row moved into `pinnedControls`
    /// so it can stick (Andy, 2026-09-05). This block is what scrolls
    /// away and hands the nav bar its title.
    private var heroIdentity: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.md) {
                LogoImage(url: Conference.logoURL(for: destination.conference))
                    .frame(width: 44, height: 44)
                    // Navy marks (Big Ten, ACC) vanish on black; the backing
                    // disc is chrome, not color, so the budget holds.
                    .background(Circle().fill(Color.logoBacking).padding(-6))
                    .padding(6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.name)
                        .font(.heroTitle)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if teamCount > 0 {
                        Text("\(teamCount) teams")
                            .font(.chipEmphasis)
                            .foregroundStyle(.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            // The gap the tab row's own top padding used to make.
            .padding(.bottom, Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgCard)
    }

    /// The sticky header: the tab row and the chips that scope the pane
    /// under it, pinned once the identity scrolls away (Andy, 2026-09-05).
    /// A conference season is a long scroll, and switching tab, team, or
    /// year shouldn't cost a trip back to the top. Both strips paint their
    /// own surface — a pinned header content can slide under has to be
    /// opaque.
    private var pinnedControls: some View {
        VStack(spacing: 0) {
            tabRow
                .padding(.horizontal, Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                // The paint reaches above the strip's own frame: a pinned
                // header settles a few points under the bar, and the
                // scrolling hero shows through that seam. Exactly the
                // identity block's own bottom gap, so at rest the overhang
                // lands on empty bgCard and can never cover the subtitle —
                // whatever the text size does to it.
                .background(Color.bgCard.padding(.top, -Spacing.sm))
            VStack(spacing: 0) {
                controlRow(showsTeamFilter: tab == .games)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.sm)
                // The gap that used to be the pane's own top padding, so
                // pinned cards never touch the row above. Its own view
                // rather than the chip's padding: Standings has no chip,
                // and a collapsed gap there merges a bgCard table into the
                // bgCard tab strip (TeamPage's Overview shape).
                Color.clear.frame(height: Spacing.sm)
            }
            .frame(maxWidth: .infinity)
            .background(Color.bgRecessed)
        }
    }

    // HeroTabBar carries the Figma tab specs.
    private var tabRow: some View {
        HeroTabBar(tabs: [.standings, .games], selection: tab,
                   onSelect: { select(tab: $0) })
    }

    /// The pane's control row — the Games tab's Weeks / Date toggles and
    /// its team filter, the same set the Top 25's Games tab carries
    /// (Andy, 2026-09-05). The season chip left this row for the toolbar
    /// the same day: it scopes both tabs, so it belongs beside the page's
    /// identity, and the row is free for the controls that shape only
    /// these cards.
    @ViewBuilder
    private func controlRow(showsTeamFilter: Bool = false) -> some View {
        if showsTeamFilter {
            SlateControlRow(grouping: grouping,
                            onToggle: { toggle(grouping: $0) },
                            teams: filterableTeams,
                            teamSelection: activeTeamFilter,
                            onSelectTeam: { teamFilter = $0 })
        }
    }

    /// Turning a grouping on turns the other off — they're two answers to
    /// one question. Turning the on one off leaves the slate ungrouped.
    private func toggle(grouping value: ConferenceSlate.Grouping) {
        withAnimation(.default) {
            grouping = grouping == value ? .none : value
        }
    }

    /// Chip taps and content swipes share the one direction rule. The edge
    /// commits a transaction before the switch so the outgoing pane's
    /// `.push` resolves against it (TeamPage's split, 2026-08-31).
    private func select(tab value: Tab) {
        guard value != tab else { return }
        tabSlideEdge = value.rawValue > tab.rawValue ? .trailing : .leading
        Task { @MainActor in
            withAnimation(.default) { tab = value }
        }
    }

    // MARK: - Games

    private var gamesSection: some View {
        VStack(spacing: Spacing.sm) {
            if let filteredGames, !filteredGames.isEmpty {
                ConferenceGamesList(games: filteredGames, grouping: grouping)
            } else if let activeTeamName, games?.isEmpty == false {
                // The narrowed-empty state, Scores' rule (2026-08-29):
                // name what's hiding the games and offer them back, so a
                // filtered pane never reads as a missing schedule.
                StatusMessage(text: "No \(selectedYear) games for \(activeTeamName)",
                              actionTitle: "Show all teams",
                              retry: { teamFilter = nil })
                    .cardSurface()
            } else if gamesLoading {
                // A lone spinner gets no card — a surface around it hugs
                // into a floating pill (Andy, 2026-08-31).
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            } else if gamesError {
                StatusMessage(text: "Couldn't load the schedule.",
                              retry: { Task { await loadGames(year: selectedYear, force: true) } })
                    .cardSurface()
            } else {
                StatusMessage(text: "Schedule TBA")
                    .cardSurface()
            }
        }
        // No top padding: the pinned header carries it, so the gap is the
        // same whether the header is riding along or stuck.
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Standings

    // No CardHeader here: the Standings tab already names the card
    // (Andy, 2026-08-29).
    private var standingsCard: some View {
        VStack(spacing: Spacing.sm) {
            if !standingsTables.isEmpty {
                // One card per table. A divisional conference gets two (or
                // four), each headed by its division and each ranked from 1
                // — the standings' own shape. Merging them into a single
                // 1-through-14 table would number teams across divisions
                // ESPN never ranked against each other (Andy, 2026-09-05).
                ForEach(standingsTables, id: \.name) { table in
                    VStack(spacing: 0) {
                        if isDivisional {
                            CardHeader(title: table.divisionName(under: destination.name))
                        }
                        StandingsList(
                            entries: table.entries,
                            highlightTeamId: destination.highlightTeamId,
                            // A division's top two are not the conference's:
                            // in a divisional format the division winners
                            // meet, so the cut claims nothing here.
                            showsTitleGameCut: !isDivisional && Conference.titleGameIsTopTwo(
                                id: destination.conferenceId, year: selectedYear,
                                in: destination.league),
                            liveGames: liveGames
                        )
                    }
                    .padding(.bottom, Spacing.xs)
                    .cardSurface()
                }
            } else if isLoading {
                // A lone spinner gets no card — a surface around it hugs
                // into a floating pill (Andy, 2026-08-31).
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            } else if showsError {
                StatusMessage(text: "Couldn't load standings.",
                              retry: { Task { await loadStandings(year: selectedYear, force: true) } })
                    .cardSurface()
            } else {
                // ESPN's offseason standings can come back empty (Sun Belt
                // did), and an old season can omit a young conference.
                StatusMessage(text: "Standings TBA")
                    .cardSurface()
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Loads

    private func select(year: Int) {
        guard year != selectedYear else { return }
        selectedYear = year
        Task { await load(year: year) }
    }

    private func load(year: Int, force: Bool = false) async {
        async let standingsLoad: Void = loadStandings(year: year, force: force)
        async let gamesLoad: Void = loadGames(year: year, force: force)
        _ = await (standingsLoad, gamesLoad)
    }

    private func loadStandings(year: Int, force: Bool = false) async {
        guard standingsByYear[year] == nil || force else { return }
        guard !loadingYears.contains(year) else { return }
        loadingYears.insert(year)
        defer { loadingYears.remove(year) }
        do {
            // Nil for the current season keeps the shipped request shape;
            // an explicit past year is scoped with `season={year}`.
            let all = try await client.conferenceStandings(
                year: year == SeasonYear.year(for: destination.league) ? nil : year,
                division: Conference.division(for: destination.conferenceId,
                                              in: destination.league) ?? .fbs)
            if isLeagueWide {
                // The league's own page tables every team at once, built
                // from the same conference response — no table in it
                // "belongs to" the league by id.
                standingsByYear[year] = all.leagueTable(in: destination.league).map { [$0] } ?? []
            } else {
                // A divisional season splits one conference into two or four
                // tables (the Sun Belt's East and West, the 2019 AAC's). The
                // conference's own table when ESPN ships one, its divisions
                // otherwise — kept apart, because each division's order is the
                // only ranking the payload actually makes.
                let mine = all.filter { $0.belongs(to: destination.conference) }
                let own = mine.filter { $0.parentId == nil }
                standingsByYear[year] = own.isEmpty ? mine : own
            }
            failedYears.remove(year)
        } catch {
            failedYears.insert(year)
        }
    }

    private func loadGames(year: Int, force: Bool = false) async {
        guard gamesByYear[year] == nil || force else { return }
        guard !gamesLoadingYears.contains(year) else { return }
        gamesLoadingYears.insert(year)
        defer { gamesLoadingYears.remove(year) }
        do {
            gamesByYear[year] = try await client.conferenceGames(
                conferenceId: destination.conferenceId,
                year: year == CFBSeason.year() ? nil : year)
            gamesFailedYears.remove(year)
        } catch {
            gamesFailedYears.insert(year)
        }
    }
}
