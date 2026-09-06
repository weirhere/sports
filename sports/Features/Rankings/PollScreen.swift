import SwiftUI

/// The poll, on the entity-page template ConferencePage and TeamPage share
/// (Andy, 2026-09-05): hero mark and title, a Standings / Games tab pair,
/// content as cards on the recessed ground, and the toolbar row carrying
/// the season chip and the follow pill.
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
        case standings, games

        var title: String {
            switch self {
            case .standings: "Standings"
            case .games: "Games"
            }
        }
    }

    /// The current season's polls, already fetched by the hub.
    let polls: [Poll]
    /// Whose poll this is — the follow control's id.
    var league: League = .collegeFootball

    @Environment(UIStateStore.self) private var uiState
    @State private var showsInlineTitle = false
    @State private var tab: Tab = .standings
    /// Which edge incoming tab content pushes from — right walking Games →
    /// Standings, left coming back (TeamPage's rule).
    @State private var tabSlideEdge: Edge = .trailing

    /// Nil means the season in progress, which needs no fetch of its own.
    @State private var pickedYear: Int?
    /// Past seasons, cached per page visit like TeamPage's schedules.
    @State private var pollsByYear: [Int: [Poll]] = [:]
    @State private var loadingYears: Set<Int> = []
    @State private var failedYears: Set<Int> = []

    /// The ranked teams' season slate, per year — one request each, kept
    /// for the visit.
    @State private var gamesByYear: [Int: [Game]] = [:]
    @State private var gamesLoadingYears: Set<Int> = []
    @State private var gamesFailedYears: Set<Int> = []

    /// How the Games tab heads its cards, and whose games it shows.
    /// Weeks and Date are on/off toggles over the same slate — a view
    /// choice, not a narrowing — and they're alternatives, so turning one
    /// on turns the other off (Andy, 2026-09-05). Both off is one
    /// chronological card. Team is the filter.
    @State private var grouping: ConferenceSlate.Grouping = .week
    @State private var teamFilter: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                tabRow
                Group {
                    switch tab {
                    case .standings: standingsSection
                    case .games: gamesSection
                    }
                }
                .transition(.push(from: tabSlideEdge))
                .geometryGroup()
                .id(tab)
            }
        }
        // ConferencePage's handoff: once the hero's own title scrolls under
        // the bar, the bar takes over the identity.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 64
        } action: { _, scrolledPastHero in
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
            // Declaration order is left-to-right, so the season sits left
            // of Follow (Andy, 2026-09-05).
            ToolbarItemGroup(placement: .topBarTrailing) {
                SeasonMenuChip(current: year, seasons: availableSeasons, style: .bar,
                               onSelect: { select(year: $0) })
                PollFollowPill(league: league)
            }
        }
        .task { await loadGames(year: year) }
    }

    // MARK: - Season

    private var currentYear: Int { SeasonYear.year(for: league) }

    private var year: Int { pickedYear ?? currentYear }

    private var availableSeasons: [Int] {
        Array(stride(from: currentYear, through: league.seasonFloor, by: -1))
    }

    /// The shown season's polls. The current one came in with the push;
    /// every other is fetched on demand and kept.
    private var seasonPolls: [Poll] {
        year == currentYear ? Self.displayed(polls) : (pollsByYear[year] ?? [])
    }

    private var selectedPoll: Poll? {
        seasonPolls.first { $0.type == uiState.pollChoice } ?? seasonPolls.first
    }

    private func select(year value: Int) {
        guard value != year else { return }
        pickedYear = value
        // The grouping is a view choice and carries over; the team pick
        // survives only where the team is still ranked (`activeTeamId`).
        Task {
            async let poll: Void = load(year: value)
            async let games: Void = loadGames(year: value)
            _ = await (poll, games)
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
        // The season in progress arrived with the push, and a season
        // already fetched is a season already fetched.
        guard value != currentYear else { return }
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

    /// The conference hero's shape with a glyph where the mark goes: the
    /// poll has no logo, and the trophy is the one the hub's row and the
    /// Scores section header already spend on it.
    private var hero: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.textSecondary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.logoBacking).padding(-6))
                .padding(6)
            VStack(alignment: .leading, spacing: 2) {
                Text("Top 25")
                    .font(.heroTitle)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                // ESPN's own line for the poll ("2026 AP Poll: Preseason")
                // — which poll, and how far into the season it is. It moved
                // up here from the card, where it read as a caption. On a
                // past season it names the year too, so the page can't be
                // mistaken for this week's.
                if let subtitle {
                    Text(subtitle)
                        .font(.chipEmphasis)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgCard)
    }

    /// The poll's own headline, or the bare season while there's no poll
    /// to headline — the hero must never say 2026 under a 2019 table.
    private var subtitle: String? {
        selectedPoll?.headline ?? (year == currentYear ? nil : String(year))
    }

    private var tabRow: some View {
        HeroTabBar(tabs: [.standings, .games], selection: tab,
                   onSelect: { select(tab: $0) })
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .background(Color.bgCard)
    }

    // MARK: - Standings

    private var standingsSection: some View {
        VStack(spacing: Spacing.sm) {
            if seasonPolls.count > 1 { pollRow }
            standingsContent
        }
        .padding(Spacing.sm)
    }

    /// The poll picker, trailing above the table it scopes — the pane
    /// control row's slot on every other entity page.
    private var pollRow: some View {
        HStack {
            Spacer()
            PollMenuChip(polls: seasonPolls, current: selectedPoll?.type,
                         onSelect: { uiState.pollChoice = $0 })
        }
    }

    @ViewBuilder
    private var standingsContent: some View {
        if let poll = selectedPoll, !poll.ranks.isEmpty {
            pollCard(poll)
        } else if loadingYears.contains(year) {
            // A lone spinner gets no card — a surface around it hugs into
            // a floating pill (Andy, 2026-08-31).
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
        } else if failedYears.contains(year) {
            StatusMessage(text: "Couldn't load the poll.",
                          retry: { Task { await load(year: year, force: true) } })
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
    private var rankedGames: [Game]? {
        guard let games = gamesByYear[year], let poll = selectedPoll else { return nil }
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

    private var filteredGames: [Game]? {
        guard let rankedGames else { return nil }
        return ConferenceSlate.games(rankedGames, forTeamId: activeTeamId)
    }

    private var gamesSection: some View {
        VStack(spacing: Spacing.sm) {
            filterRow
            gamesContent
        }
        .padding(Spacing.sm)
    }

    private var filterRow: some View {
        SlateControlRow(grouping: grouping,
                        onToggle: { toggle($0) },
                        teams: filterableTeams,
                        teamSelection: activeTeamId,
                        onSelectTeam: { teamFilter = $0 })
    }

    /// Turning a grouping on turns the other off — they're two answers to
    /// one question. Turning the on one off leaves the slate ungrouped.
    private func toggle(_ value: ConferenceSlate.Grouping) {
        withAnimation(.default) {
            grouping = grouping == value ? .none : value
        }
    }

    @ViewBuilder
    private var gamesContent: some View {
        if let filteredGames, !filteredGames.isEmpty {
            ConferenceGamesList(games: filteredGames, grouping: grouping)
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
