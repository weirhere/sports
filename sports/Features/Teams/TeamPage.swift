import SwiftUI

/// One team's home: a card-color hero header (the team-color paint retired
/// 2026-08-31 — headers match the cards, FotMob-style), Overview, Games,
/// and Standings tabs, and a schedule for any season back to the CFP era.
struct TeamPage: View {
    let team: Team

    /// Optional form: previews/tests without RootView's environment degrade
    /// to the pushed value instead of trapping.
    @Environment(TeamDirectoryStore.self) private var directory: TeamDirectoryStore?
    /// Optional like the directory: the fresher-game merge degrades to the
    /// schedule payload wherever the scoreboard isn't in the environment.
    @Environment(LeagueScoreboards.self) private var scoreboards: LeagueScoreboards?

    /// The live board for *this page's* league — an NFL team's scores come
    /// from the NFL scoreboard, never college football's.
    private var liveBoard: ScoreboardStore? { scoreboards?.store(for: pageLeague) }

    /// Raw values order the tabs — the slide direction is an ordinal
    /// comparison, so a third tab can't break the choreography.
    private enum Tab: Int, HeroTabItem {
        case overview, games, standings

        var title: String {
            switch self {
            case .overview: "Overview"
            case .games: "Games"
            case .standings: "Standings"
            }
        }
    }

    /// Seasons fetched this visit, keyed by year — flipping back to a
    /// seen season costs ESPN nothing (each season is two requests).
    @State private var schedules: [Int: TeamSchedule] = [:]
    /// Nil until the first load lands; set from the payload's year so the
    /// chip label can't drift from the data (the current-season fetch may
    /// fall back a season while the next one is unpublished).
    @State private var selectedYear: Int?
    /// Where the first load landed. The share always describes this
    /// season, whatever the chip is showing.
    @State private var currentSeasonYear: Int?
    @State private var loadingYears: Set<Int> = []
    @State private var failedYears: Set<Int> = []
    @State private var initialLoading = false
    @State private var initialFailed = false

    @State private var tab: Tab = .overview
    /// True once the hero title has scrolled under the nav bar — the bar's
    /// principal slot then carries the team name.
    @State private var showsInlineTitle = false
    /// Which edge incoming tab content pushes from — right when walking
    /// Games → Standings, left coming back, matching the tab order.
    @State private var tabSlideEdge: Edge = .trailing
    /// The Standings tab's tables, keyed by year like the schedules —
    /// ConferencePage's caching pattern. The tab gained past seasons when
    /// the season chip moved into the panes (Andy, 2026-08-31).
    @State private var standingsByYear: [Int: ConferenceStandings] = [:]
    @State private var standingsLoadingYears: Set<Int> = []
    @State private var standingsFailedYears: Set<Int> = []

    /// Scoped to the page's own league. ESPN team ids collide — id 5 is
    /// the Cleveland Browns and UAB — so a league-less client here fetches
    /// a different team's schedule entirely.
    private var client: any ScoresProviding { DataProvider.makeClient(league: pageLeague) }

    private var schedule: TeamSchedule? {
        selectedYear.flatMap { schedules[$0] }
    }

    private var currentSchedule: TeamSchedule? {
        currentSeasonYear.flatMap { schedules[$0] }
    }

    /// Newest first, floored at 2014 — the CFP era, matching the Scores
    /// header's selector.
    private var availableSeasons: [Int] {
        Array(stride(from: CFBSeason.year(), through: 2014, by: -1))
    }

    /// The selected season's payload wins (groups is season-scoped, so a
    /// realignment year reads correctly under the season chip), then the
    /// pushed value (instant, pre-fetch), then the team directory (covers
    /// Rankings/game-detail entry paths that push no id).
    ///
    /// The claim check lives in `ConferenceClaim` — a rule that has been
    /// wrong twice belongs somewhere a test can reach it.
    /// The league this page belongs to — the pushed team's, which the
    /// ESPN mapper stamped from the client that fetched it.
    private var pageLeague: League { team.league }

    /// The conference, qualified by league, for lookups and pushes.
    private var resolvedConference: ConferenceID? {
        resolvedConferenceId.map { ConferenceID(pageLeague, $0) }
    }

    private var resolvedConferenceId: Int? {
        // The directory is league-scoped on purpose: ESPN team ids collide,
        // so an unfiltered lookup would hand the Cleveland Browns UAB's
        // conference (both are id 5).
        let leagueDirectory = (directory?.allTeams ?? []).filter { $0.league == pageLeague }
        let claimed = schedule?.team?.conferenceId
            ?? team.conferenceId
            ?? leagueDirectory.first(where: { $0.id == team.id })?.conferenceId
        // The claim check is a college-football rule — it defends against
        // an opponent from outside the divisions we fetch (D-II, D-III).
        // Every NFL team is inside the one league we fetch, and its
        // registry answers for all 32, so there is nothing to disprove.
        guard pageLeague == .collegeFootball else {
            return Conference.isKnown(claimed, in: pageLeague) ? claimed : nil
        }
        return ConferenceClaim.resolve(claimed: claimed, teamId: team.id,
                                       directory: leagueDirectory)
    }

    private var isLoadingSelected: Bool {
        guard let selectedYear else { return initialLoading }
        return loadingYears.contains(selectedYear)
    }

    private var showsErrorForSelected: Bool {
        guard let selectedYear else { return initialFailed }
        return failedYears.contains(selectedYear)
    }

    /// The current season's first unplayed (or in-progress) game. Only the
    /// current season leads with it — a past season is history, and its
    /// "next game" would be a lie.
    private var nextGame: Game? {
        guard selectedYear == currentSeasonYear else { return nil }
        return schedule?.games.first { game in
            switch game.status {
            case .pre, .live: true
            case .final, .other: false
            }
        }.map(fresher)
    }

    /// The schedule payload carries no live scores or clock mid-game (the
    /// dashed-score bug, Andy 2026-08-29); the scoreboard polls every 30s.
    /// `Game.merging` is the shared rule — ConferencePage's season slate
    /// renders through the same one.
    private func fresher(_ game: Game) -> Game {
        Game.merging(game, withLive: liveBoard?.games ?? [])
    }

    /// Any division we can name a conference for. The gate was FBS-only
    /// while `conferenceStandings` could only ask for group 80; it now
    /// asks for the team's own division, so an FCS team gets a real table
    /// instead of a permanent "Standings TBA". `.other` still hides the
    /// tab — an id we can't name has no table to show.
    private var showsStandingsTab: Bool {
        Conference.division(for: resolvedConferenceId, in: pageLeague) != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                Group {
                    switch tab {
                    case .overview: overviewContent
                    case .games: gamesContent
                    case .standings: standingsContent
                    }
                }
                // geometryGroup pins every child (row logos included) to
                // the pane while it slides — without it, subtrees resolve
                // their own positions and marks sat still as cards moved.
                .geometryGroup()
                .id(tab)
                .transition(.push(from: tabSlideEdge))
                // The week swipe's sibling (Andy, 2026-08-29): a horizontal
                // swipe on the content walks the tabs; the tab buttons
                // stay, so nothing is swipe-gated. Simultaneous with a
                // dominance check so vertical scrolling never tab-flips.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            let dx = value.translation.width
                            guard abs(dx) > 50,
                                  abs(dx) > abs(value.translation.height) * 1.5,
                                  let target = Tab(rawValue: tab.rawValue + (dx < 0 ? 1 : -1)),
                                  target != .standings || showsStandingsTab else { return }
                            select(tab: target)
                        }
                )
            }
        }
        // Once the hero's own title scrolls under the bar, the bar takes
        // over the identity (Andy, 2026-08-29): the team name fades into
        // the principal slot between back and share.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 120
        } action: { _, scrolledPastHero in
            withAnimation(.easeInOut(duration: 0.15)) {
                showsInlineTitle = scrolledPastHero
            }
        }
        // The card color through the status-bar strip and the top bounce.
        .heroTopBand(Color.bgCard)
        .background(Color.bgRecessed)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Solid card-color bar, seamless against the bgCard hero at rest —
        // the transparent-until-scrolled dance retired with the team-color
        // paint it existed for (2026-08-31).
        .toolbarBackground(Color.bgCard, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(team.location)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .opacity(showsInlineTitle ? 1 : 0)
                    .accessibilityHidden(!showsInlineTitle)
            }
            // The control row, FotMob's pattern (Andy, 2026-08-31): bell,
            // follow, and share ride beside the system back button. The
            // season chip moved into the tab panes to make the room.
            ToolbarItemGroup(placement: .topBarTrailing) {
                NotificationBell()
                FollowPill(team: team)
                shareButton
            }
        }
        // Sequential: standings need the schedule's conference id. The
        // Overview record card wants them up front now, not on first visit
        // to the Standings tab (whose own task stays as an idempotent
        // retry).
        .task {
            await loadInitial()
            await loadStandings()
        }
    }

    private var shareButton: some View {
        ShareLink(item: team.shareText(schedule: currentSchedule)) {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(.textPrimary)
        }
        .accessibilityLabel("Share this team")
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.md) {
                logoMark
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.location)
                        .font(.heroTitle)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    conferenceLine
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)

            // Overview and Games always exist, so the row always renders;
            // only Standings is conference-gated.
            tabRow
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The strip above — through the bar and the top bounce — is
        // heroTopBand's job: an in-content extension never escaped the
        // ScrollView's clip (2026-08-31).
        .background(Color.bgCard)
    }

    /// Bare mark on the card-color header — dark mode reads the `500-dark`
    /// variant through LogoImage, so no backing disc (Andy, 2026-08-31).
    private var logoMark: some View {
        LogoImage(url: team.logoURL)
            .frame(width: 56, height: 56)
    }

    /// The conference name; the record moved into Overview's Record card,
    /// and the placement string into the Standings tab, where it's a table
    /// instead of a claim. Links to the full conference page when there is one.
    @ViewBuilder
    private var conferenceLine: some View {
        // Both divisions link now: the conference page fetches standings
        // for its own division, and ESPN serves its Games tab off the same
        // `groups={id}` scoreboard call either way (probed 2026-09-03:
        // Big Sky 2026 returns 96 events). An id we can't name still
        // renders as plain text — there's no page to send it to.
        let label = resolvedConference.map { Conference.name(for: $0) } ?? ""
        if let id = resolvedConference, Conference.division(for: id.id, in: id.league) != nil {
            NavigationLink(value: ConferenceDestination(conference: id,
                                                        name: Conference.name(for: id),
                                                        highlightTeamId: team.id)) {
                HStack(spacing: Spacing.xs) {
                    Text(label)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.chipEmphasis)
                .foregroundStyle(.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityHint("View conference standings")
        } else if !label.isEmpty {
            Text(label)
                .font(.chipEmphasis)
                .foregroundStyle(.textSecondary)
        }
    }

    private var tabRow: some View {
        HeroTabBar(tabs: visibleTabs, selection: tab,
                   onSelect: { select(tab: $0) })
    }

    private var visibleTabs: [Tab] {
        showsStandingsTab ? [.overview, .games, .standings] : [.overview, .games]
    }

    /// Chip taps and content swipes share the one direction rule, the
    /// week-select pattern. The edge commits a transaction BEFORE the
    /// switch: the outgoing pane's `.push` resolves against the pre-change
    /// tree, so setting both together replayed the previous direction
    /// (the week swipe's `select(week:)` split, adopted 2026-08-31).
    private func select(tab value: Tab) {
        guard value != tab else { return }
        tabSlideEdge = value.rawValue > tab.rawValue ? .trailing : .leading
        Task { @MainActor in
            withAnimation(.default) { tab = value }
        }
    }

    // MARK: - Tab content

    /// The chip's year before the first schedule load pins it.
    private var standingsYear: Int { selectedYear ?? CFBSeason.year() }
    private var selectedStandings: ConferenceStandings? { standingsByYear[standingsYear] }
    private var standingsLoading: Bool { standingsLoadingYears.contains(standingsYear) }
    private var standingsFailed: Bool { standingsFailedYears.contains(standingsYear) }

    /// The team's own row in its conference table — the record card's
    /// source while the season is current, whatever year the chip shows.
    private var ownStanding: ConferenceStanding? {
        currentSeasonYear.flatMap { standingsByYear[$0] }?
            .entries.first { $0.team.id == team.id }
    }

    /// The season picker rides the pane, not the hero — the toolbar row
    /// holds bell/follow/share and had no room (Andy, 2026-08-31).
    @ViewBuilder
    private var seasonRow: some View {
        if let selectedYear {
            HStack {
                Spacer()
                SeasonMenuChip(current: selectedYear, seasons: availableSeasons,
                               onSelect: { select(year: $0) })
            }
        }
    }

    /// Conference W-L is only knowable from the standings payload, which
    /// always describes the current season — a past season shows overall
    /// only (tiebreakers make conference records non-derivable; the
    /// summaries-trust rule).
    private var overviewConferenceRecord: String? {
        guard selectedYear == currentSeasonYear else { return nil }
        return ownStanding?.conferenceRecord
    }

    private var overviewOverallRecord: String? {
        guard selectedYear == currentSeasonYear else { return schedule?.derivedRecord }
        return ownStanding?.overallRecord ?? schedule?.record ?? schedule?.derivedRecord
    }

    private var overviewContent: some View {
        VStack(spacing: Spacing.sm) {
            if let nextGame {
                NextGameCard(game: nextGame)
                    .cardSurface()
            }
            if TeamRecordCard.hasContent(conferenceRecord: overviewConferenceRecord,
                                         overallRecord: overviewOverallRecord) {
                TeamRecordCard(conferenceRecord: overviewConferenceRecord,
                               overallRecord: overviewOverallRecord)
                    .cardSurface()
            } else if nextGame == nil {
                // Nothing to lead with: mirror the schedule's status
                // treatment so the tab is never silently blank. A lone
                // spinner gets no card — a surface around it hugs into a
                // floating pill (Andy, 2026-08-31).
                if isLoadingSelected {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                } else if showsErrorForSelected {
                    StatusMessage(text: "Couldn't load the season.",
                                  retry: { Task { await retry() } })
                        .cardSurface()
                } else {
                    StatusMessage(text: "Season TBA")
                        .cardSurface()
                }
            }
        }
        .padding(Spacing.sm)
    }

    private var gamesContent: some View {
        VStack(spacing: Spacing.sm) {
            seasonRow
            if let nextGame {
                NextGameCard(game: nextGame)
                    .cardSurface()
            }
            VStack(spacing: 0) {
                TeamScheduleSection(
                    teamId: team.id,
                    games: Game.merging(schedule?.games ?? [], withLive: liveBoard?.games ?? []),
                    isLoading: isLoadingSelected,
                    showsError: showsErrorForSelected,
                    onRetry: { Task { await retry() } }
                )
            }
            .padding(.bottom, Spacing.xs)
            .cardSurface()
        }
        .padding(Spacing.sm)
    }

    // No CardHeader here: the Standings tab already names the card
    // (Andy, 2026-08-29, matching ConferencePage).
    private var standingsContent: some View {
        VStack(spacing: Spacing.sm) {
            seasonRow
            if let entries = selectedStandings?.entries, !entries.isEmpty {
                VStack(spacing: 0) {
                    StandingsList(
                        entries: entries,
                        highlightTeamId: team.id,
                        showsTitleGameCut: Conference.titleGameIsTopTwo(
                            id: resolvedConferenceId, year: standingsYear, in: pageLeague),
                        // Live claims are current-season only (ConferencePage's rule).
                        liveGames: standingsYear == currentSeasonYear
                            ? (liveBoard?.games.filter(\.isLive) ?? []) : []
                    )
                }
                .padding(.bottom, Spacing.xs)
                .cardSurface()
            } else if standingsLoading {
                // A lone spinner gets no card — a surface around it hugs
                // into a floating pill (Andy, 2026-08-31).
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            } else if standingsFailed {
                StatusMessage(text: "Couldn't load standings.",
                              retry: { Task { await loadStandings(force: true) } })
                    .cardSurface()
            } else {
                StatusMessage(text: "Standings TBA")
                    .cardSurface()
            }
        }
        .padding(Spacing.sm)
        // Re-fires on year flips while the tab is up; first visit to a
        // year fetches lazily, a seen year is a cache hit.
        .task(id: standingsYear) { await loadStandings() }
    }

    // MARK: - Loads

    private func loadInitial() async {
        guard selectedYear == nil, !initialLoading else { return }
        initialLoading = true
        defer { initialLoading = false }
        do {
            let loaded = try await client.teamSchedule(teamId: team.id)
            // Register the result under the year it really is, so
            // explicitly re-picking the fallback season is a cache hit.
            let year = loaded.year ?? CFBSeason.year()
            schedules[year] = loaded
            currentSeasonYear = year
            selectedYear = year
            initialFailed = false
        } catch {
            initialFailed = true
        }
    }

    private func select(year: Int) {
        guard year != selectedYear else { return }
        selectedYear = year
        guard schedules[year] == nil, !loadingYears.contains(year) else { return }
        Task { await load(year: year) }
    }

    private func load(year: Int) async {
        loadingYears.insert(year)
        defer { loadingYears.remove(year) }
        do {
            schedules[year] = try await client.teamSchedule(teamId: team.id, year: year)
            failedYears.remove(year)
        } catch {
            failedYears.insert(year)
        }
    }

    private func retry() async {
        if let selectedYear {
            await load(year: selectedYear)
        } else {
            await loadInitial()
        }
    }

    private func loadStandings(force: Bool = false) async {
        guard let id = resolvedConferenceId else { return }
        let year = standingsYear
        // The id re-check also covers a conference that resolved differently
        // once the schedule payload landed.
        guard force || standingsByYear[year]?.id != id else { return }
        guard !standingsLoadingYears.contains(year) else { return }
        standingsLoadingYears.insert(year)
        defer { standingsLoadingYears.remove(year) }
        do {
            // Nil for the current season keeps the shipped request shape;
            // an explicit past year is scoped with `season={year}`.
            let all = try await client.conferenceStandings(
                year: year == SeasonYear.year(for: pageLeague) ? nil : year,
                division: Conference.division(for: id, in: pageLeague) ?? .fbs)
            standingsByYear[year] = all.first { $0.id == id }
                ?? ConferenceStandings(id: id, name: Conference.name(for: id, in: pageLeague),
                                       entries: [], league: pageLeague)
            standingsFailedYears.remove(year)
        } catch {
            standingsFailedYears.insert(year)
        }
    }
}
