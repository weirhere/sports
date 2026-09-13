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
        case overview, games, standings, roster

        var title: String {
            switch self {
            case .overview: "Overview"
            case .games: "Games"
            case .standings: "Standings"
            case .roster: "Roster"
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
    /// The season's standings response, stored whole: the pane reads its
    /// own tables out of it per scope, and re-scoping must never re-fetch
    /// (ConferencePage's rule).
    @State private var standingsByYear: [Int: [ConferenceStandings]] = [:]
    /// The divisional tables, fetched only once a scope asks for them —
    /// ESPN's shipped standings response stops at the conferences, so this
    /// is the one scope that costs a request.
    @State private var divisionsByYear: [Int: [ConferenceStandings]] = [:]
    @State private var standingsLoadingYears: Set<Int> = []
    @State private var standingsFailedYears: Set<Int> = []
    @State private var divisionLoadingYears: Set<Int> = []
    @State private var divisionFailedYears: Set<Int> = []
    /// The current roster, fetched once on first visit to the tab and held
    /// for the page's life. Not keyed by year like the schedules and the
    /// standings: ESPN's roster endpoint has no season axis at all (see
    /// `ScoresProviding.roster`), which is also why the season chip stands
    /// down on this tab.
    @State private var roster: TeamRoster?
    /// Which team the cached roster describes. Belt and braces against the
    /// navigation-identity trap the `.id(team.followKey)` on every Team
    /// destination closes (2026-09-10): a reused page must not paint the
    /// previous team's squad under this one's crest, whatever the routing
    /// layer does. A fetch-once guard is only safe if it knows what it
    /// fetched.
    @State private var rosterTeamKey: String?
    @State private var rosterLoading = false
    @State private var rosterFailed = false

    /// The roster, but only if it belongs to the team on screen.
    private var currentRoster: TeamRoster? {
        rosterTeamKey == team.followKey ? roster : nil
    }
    /// How wide the Standings tab tables its teams — the team's league,
    /// its conference, or its division (Andy, 2026-09-07). Session-scoped
    /// like ConferencePage's, and only the NFL's pages offer the choice.
    @State private var scope: StandingsScope = .conference

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

    /// Newest first, floored at the league's own floor — the CFP era for
    /// all four, matching the ConferencePage selector.
    private var availableSeasons: [Int] {
        Array(stride(from: seasonNow, through: pageLeague.seasonFloor, by: -1))
    }

    /// The season "now" belongs to, on this page's league's clock. A
    /// college-football rollover applied to a hockey page would call June
    /// "next season" while the Stanley Cup was still being played for.
    ///
    /// Distinct from `currentSeasonYear`, which is the season the *loaded
    /// schedule* turned out to describe.
    private var seasonNow: Int { SeasonYear.year(for: pageLeague) }

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
        Game.merging(game, withLive: liveBoard?.boardGames ?? [])
    }

    /// Any division we can name a conference for. The gate was FBS-only
    /// while `conferenceStandings` could only ask for group 80; it now
    /// asks for the team's own division, so an FCS team gets a real table
    /// instead of a permanent "Standings TBA". `.other` still hides the
    /// tab — an id we can't name has no table to show.
    private var showsStandingsTab: Bool {
        // College football gates on the division registry; the NFL knows
        // all 32 of its teams, so any id its table answers for has a table.
        pageLeague == .collegeFootball
            ? Conference.division(for: resolvedConferenceId, in: pageLeague) != nil
            : Conference.isKnown(standingsGroupId, in: pageLeague)
    }

    /// Which table this team's standings live in. An NFL team's own group
    /// is its division (NFC West), but ESPN's standings response is keyed
    /// by conference, and a fan reads playoff seeding at that level anyway
    /// — so the division resolves up to its parent.
    private var standingsGroupId: Int? {
        guard let id = resolvedConferenceId else { return nil }
        return Conference.parent(of: id, in: pageLeague) ?? id
    }

    var body: some View {
        ScrollView {
            // Lazy only for the pinning — two children, and the section's
            // content is the whole pane in one subtree, so nothing inside
            // it is actually deferred.
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                heroIdentity
                Section {
                    Group {
                        switch tab {
                        case .overview: overviewContent
                        case .games: gamesContent
                        case .standings: standingsContent
                        case .roster: rosterContent
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
                                      let target = neighbour(of: tab, step: dx < 0 ? 1 : -1)
                                else { return }
                                select(tab: target)
                            }
                    )
                } header: {
                    pinnedControls
                }
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
                seasonChip
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

    /// Just the identity now — the tab row moved into `pinnedControls`
    /// so it can stick (Andy, 2026-09-05). This block is what scrolls
    /// away and hands the nav bar its title.
    private var heroIdentity: some View {
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
            // The gap the tab row's own top padding used to make.
            .padding(.bottom, Spacing.sm)
            // 8pt more on each side of the identity block (Andy,
            // 2026-09-09): the mark, the name and the badges were sitting
            // tight against the bar above and the tabs below, and the
            // header reads as its own band with the room.
            .padding(.vertical, Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The strip above — through the bar and the top bounce — is
        // heroTopBand's job: an in-content extension never escaped the
        // ScrollView's clip (2026-08-31).
        .background(Color.bgCard)
    }

    /// The sticky header: the tab row and the chip that scopes the pane
    /// under it, pinned once the identity scrolls away (Andy, 2026-09-05).
    /// A season's schedule is a long scroll, and switching tab or year
    /// shouldn't cost a trip back to the top. Both strips paint their own
    /// surface — a pinned header content can slide under has to be opaque.
    private var pinnedControls: some View {
        VStack(spacing: 0) {
            // Overview and Games always exist, so the row always renders;
            // only Standings is conference-gated.
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
                // The Standings tab's own control: how wide the table is
                // (Andy, 2026-09-07). Only the NFL's team pages have one —
                // a college team belongs to a conference and nothing else,
                // so there is no other level to read it at.
                if showsScopeChip {
                    HStack(spacing: Spacing.sm) {
                        StandingsScopeChip(
                            scopes: availableScopes, selection: scope,
                            isNarrowed: resolvedConference.map {
                                scope.isNarrower(than: StandingsScope.default(forTeamIn: $0))
                            } ?? false,
                            onSelect: { select(scope: $0) })
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.sm)
                }
                // The gap that used to be the pane's own top padding, so
                // pinned cards never touch the row above. Its own view
                // rather than the chip's padding: every other tab has no
                // chip, and a collapsed gap there merges a bgCard card into
                // the bgCard tab row (ConferencePage's shape).
                Color.clear.frame(height: Spacing.sm)
            }
            .frame(maxWidth: .infinity)
            .background(Color.bgRecessed)
        }
    }

    /// The scope chip rides the Standings tab only — it has nothing to say
    /// about a schedule — and only where the league nests deep enough to
    /// give it more than one answer.
    private var showsScopeChip: Bool {
        tab == .standings && availableScopes.count > 1
    }

    /// Bare mark on the card-color header — dark mode reads the `500-dark`
    /// variant through LogoImage, so no backing disc (Andy, 2026-08-31).
    private var logoMark: some View {
        LogoImage(url: team.logoURL)
            .frame(width: 56, height: 56)
    }

    /// Where this team sits, and the way there: its own group, then the
    /// league that group belongs to.
    ///
    /// Both rungs are links (Andy, 2026-09-09: "include what league
    /// they're a part of (not just what division) … link to that league
    /// like we do for college football conferences"). A pro team's group
    /// is its *division*, which named a race with no route to the league
    /// above it — and the line linked at all only for college football,
    /// because the gate asked whether the id had an FBS/FCS division
    /// rather than whether it had a page.
    ///
    /// College football is unchanged: its conferences sit under a division
    /// of the sport rather than a league table, so there is no second rung
    /// and the line stays one link.
    @ViewBuilder
    private var conferenceLine: some View {
        let label = resolvedConference.map { Conference.name(for: $0) } ?? ""
        HStack(spacing: Spacing.xs) {
            if let id = resolvedConference, Conference.isKnown(id.id, in: id.league) {
                // Widest first in the pro leagues — [NBA] [Atlantic] —
                // because the league is the identity and the division is
                // the detail inside it.
                //
                // College football reads the other way (Andy, 2026-09-09):
                // Miami is an ACC team that happens to play in FBS, not an
                // FBS team that happens to be in the ACC. The conference is
                // the identity there and the subdivision is the
                // classification around it, so it goes second.
                if pageLeague.hasCollegeDivisions {
                    groupLink(id, label: label)
                    leagueDestination.map(leagueLink)
                } else {
                    leagueDestination.map(leagueLink)
                    groupLink(id, label: label)
                }
            } else if !label.isEmpty {
                // An id we can't name renders as plain text — there's no
                // page to send it to.
                Text(label)
                    .font(.chipEmphasis)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private func groupLink(_ id: ConferenceID, label: String) -> some View {
        NavigationLink(value: ConferenceDestination(conference: id,
                                                    name: Conference.name(for: id),
                                                    highlightTeamId: team.id)) {
            HeaderLinkBadge(title: label)
        }
        .buttonStyle(.plain)
        .accessibilityHint("View standings")
    }

    private func leagueLink(_ destination: ConferenceDestination) -> some View {
        NavigationLink(value: destination) {
            HeaderLinkBadge(title: destination.name)
        }
        .buttonStyle(.plain)
        .accessibilityHint("View league standings")
    }

    /// The list this team's group sits in: a pro league's whole-league
    /// table, or the college-football division its conference plays in.
    private var leagueDestination: ConferenceDestination? {
        guard let own = resolvedConference,
              let id = Conference.root(above: own) else { return nil }
        return ConferenceDestination(conference: id, name: Conference.name(for: id),
                                     highlightTeamId: team.id)
    }

    private var tabRow: some View {
        HeroTabBar(tabs: visibleTabs, selection: tab,
                   onSelect: { select(tab: $0) })
    }

    private var visibleTabs: [Tab] {
        var tabs: [Tab] = [.overview, .games]
        if showsStandingsTab { tabs.append(.standings) }
        if showsRosterTab { tabs.append(.roster) }
        return tabs
    }

    /// Only where the backend has a roster to serve. ESPN does for every
    /// league; CFBD and the UI-test fixture don't, and an empty pane behind a
    /// permanent tab is worse than no tab.
    private var showsRosterTab: Bool { client.providesRoster }

    /// The tab one step along the row — the *visible* row, not the enum's.
    /// Standings is conference-gated, so a hidden tab sits in the middle of
    /// the raw-value order on plenty of college pages; walking the ordinals
    /// there would swipe onto a tab that isn't on screen.
    private func neighbour(of tab: Tab, step: Int) -> Tab? {
        guard let index = visibleTabs.firstIndex(of: tab) else { return nil }
        let target = index + step
        guard visibleTabs.indices.contains(target) else { return nil }
        return visibleTabs[target]
    }

    /// Switching scope re-reads the same season. Division is the only one
    /// that can need a fetch, and it asks for it here rather than on every
    /// appearance — a page nobody scopes down pays for nothing.
    private func select(scope value: StandingsScope) {
        guard value != scope else { return }
        withAnimation(.default) { scope = value }
        guard value == .division else { return }
        Task { await loadDivisions() }
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
    private var standingsYear: Int { selectedYear ?? seasonNow }
    /// The tables with something in them — one, or a division each.
    private var selectedStandings: [ConferenceStandings] {
        tables(for: scope).filter { !$0.entries.isEmpty }
    }

    /// The season's response read at one scope. Every level here is one
    /// the team itself belongs to, so its own row is in whichever table
    /// comes back — the AFC North's four, the AFC's sixteen, the league's
    /// thirty-two.
    private func tables(for scope: StandingsScope) -> [ConferenceStandings] {
        let all = standingsByYear[standingsYear] ?? []
        switch scope {
        case .league:
            // The merged 32, built from the conference tables already in
            // hand — the Tables hub's league row, and ConferencePage's.
            return all.leagueTable(in: pageLeague).map { [$0] } ?? []
        case .conference:
            // A divisional conference splits into two or four tables (the
            // Sun Belt's East and West). The conference's own table when
            // ESPN ships one, its divisions otherwise — kept apart,
            // because each division's order is the only ranking the
            // payload actually makes.
            guard let id = standingsGroupId else { return [] }
            let mine = all.filter { $0.belongs(to: ConferenceID(pageLeague, id)) }
            let own = mine.filter { $0.parentId == nil }
            return own.isEmpty ? mine : own
        case .division:
            // The team's own division, not all eight — every scope on a
            // team page is a group the team is in.
            guard let own = resolvedConference else { return [] }
            return (divisionsByYear[standingsYear] ?? [])
                .filter { $0.conference == own }
        }
    }

    /// The scopes this page can offer, from where the team sits in its
    /// league's hierarchy. Empty everywhere college football goes — its
    /// teams belong to a conference and nothing else — which is what hides
    /// the control.
    private var availableScopes: [StandingsScope] {
        resolvedConference.map { StandingsScope.scopes(forTeamIn: $0) } ?? []
    }

    /// Whether those tables are divisions rather than the conference —
    /// the payload's answer, the only one that can't go stale.
    private var standingsAreDivisional: Bool {
        selectedStandings.contains { $0.parentId != nil }
    }
    private var standingsLoading: Bool {
        scope == .division
            ? divisionLoadingYears.contains(standingsYear)
            : standingsLoadingYears.contains(standingsYear)
    }
    private var standingsFailed: Bool {
        scope == .division
            ? divisionFailedYears.contains(standingsYear)
            : standingsFailedYears.contains(standingsYear)
    }

    /// The team's own row in its conference table — the record card's
    /// source while the season is current, whatever year the chip shows.
    private var ownStanding: ConferenceStanding? {
        guard let year = currentSeasonYear else { return nil }
        return (standingsByYear[year] ?? []).lazy
            .compactMap { $0.entries.first { $0.team.id == team.id } }
            .first
    }

    /// The season picker rides the toolbar row (Andy, 2026-09-05,
    /// superseding the 2026-08-31 move into the panes) — it scopes the
    /// schedule and the standings alike, so it sits with the page's
    /// identity rather than above one pane's cards.
    ///
    /// Overview is the exception it has always been: its record card is
    /// pinned to the current season, so there is nothing there for a year
    /// to scope, and a control that does nothing is worse than no control.
    ///
    /// Roster is the second exception, for a harder reason: ESPN's roster
    /// endpoint has no season axis, so a past year can't be asked for at all
    /// (probed live 2026-09-10 — `?season=2019` answers 200 with zero
    /// athletes). A chip there wouldn't do nothing; it would show this year's
    /// roster under last decade's label.
    @ViewBuilder
    private var seasonChip: some View {
        if let selectedYear, tab != .overview, tab != .roster {
            SeasonMenuChip(current: selectedYear, seasons: availableSeasons, league: pageLeague,
                           style: .bar, onSelect: { select(year: $0) })
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
                TeamRecordCard(league: pageLeague,
                               conferenceRecord: overviewConferenceRecord,
                               overallRecord: overviewOverallRecord)
                    .cardSurface()
            } else if nextGame == nil, schedule?.homeVenue == nil {
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
            // Last, because it is the tab's least time-sensitive card —
            // a stadium doesn't move between refreshes, where the next
            // game and the record do.
            if let venue = schedule?.homeVenue {
                TeamVenueCard(venue: venue)
                    .cardSurface()
            }
        }
        // No top padding: the pinned header carries it, so the gap is
        // the same whether the header is riding along or stuck.
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    private var gamesContent: some View {
        VStack(spacing: Spacing.sm) {
            if let nextGame {
                NextGameCard(game: nextGame)
                    .cardSurface()
            }
            // A card per phase of the season (Andy, 2026-09-06). The
            // phases the team has no games in produce no card, so a college
            // page with neither a preseason nor a bowl is one card, as
            // before — and the loading/error/empty states still need a card
            // of their own when there are no games to split at all.
            let scheduleGames = Game.merging(schedule?.games ?? [],
                                             withLive: liveBoard?.boardGames ?? [])
            let phases = scheduleGames.bySeasonPhase()
            if phases.isEmpty {
                scheduleCard(title: "Schedule", games: [], byeWeek: nil)
            } else {
                ForEach(phases, id: \.phase) { phase, games in
                    // The bye is a regular-season fact: it sits between two
                    // real weeks, and there is no such thing as a preseason
                    // bye to slot.
                    scheduleCard(title: phase.title, games: games,
                                 byeWeek: phase == .regular ? schedule?.byeWeek : nil)
                }
            }
        }
        // No top padding: the pinned header carries it, so the gap is
        // the same whether the header is riding along or stuck.
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    private func scheduleCard(title: String, games: [Game], byeWeek: Int?) -> some View {
        VStack(spacing: 0) {
            TeamScheduleSection(
                teamId: team.id,
                title: title,
                games: games,
                isLoading: isLoadingSelected,
                showsError: showsErrorForSelected,
                byeWeek: byeWeek,
                onRetry: { Task { await retry() } }
            )
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    // No CardHeader here: the Standings tab already names the card
    // (Andy, 2026-08-29, matching ConferencePage).
    private var standingsContent: some View {
        VStack(spacing: Spacing.sm) {
            if !selectedStandings.isEmpty {
                // One card per table, divisions headed by their own name —
                // ConferencePage's rule, so a Sun Belt team's tab and the
                // conference it links to say the same thing.
                ForEach(selectedStandings, id: \.name) { table in
                    VStack(spacing: 0) {
                        if standingsAreDivisional {
                            CardHeader(title: table.divisionName(
                                under: Conference.name(for: resolvedConferenceId, in: pageLeague)))
                        }
                        StandingsList(
                            entries: table.entries,
                            highlightTeamId: team.id,
                            // A division's top two are not the conference's.
                            showsTitleGameCut: !standingsAreDivisional
                                && Conference.titleGameIsTopTwo(
                                    id: resolvedConferenceId, year: standingsYear, in: pageLeague),
                            // Live claims are current-season only (ConferencePage's rule).
                            liveGames: standingsYear == currentSeasonYear
                                ? (liveBoard?.boardGames.filter(\.isLive) ?? []) : []
                        )
                    }
                    .padding(.bottom, Spacing.xs)
                    .cardSurface()
                }
            } else if standingsLoading {
                // A lone spinner gets no card — a surface around it hugs
                // into a floating pill (Andy, 2026-08-31).
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            } else if standingsFailed {
                StatusMessage(text: "Couldn't load standings.",
                              retry: { Task { await loadStandings(scope: scope, force: true) } })
                    .cardSurface()
            } else {
                StatusMessage(text: "Standings TBA")
                    .cardSurface()
            }
        }
        // No top padding: the pinned header carries it, so the gap is
        // the same whether the header is riding along or stuck.
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        // Re-fires on year flips while the tab is up; first visit to a
        // year fetches lazily, a seen year is a cache hit. The divisional
        // fetch rides along only for a pane already scoped to it — a page
        // nobody scopes down pays for nothing.
        .task(id: standingsYear) { await loadStandings(scope: scope) }
    }

    /// Who plays here — FotMob's squad screen, in the app's table language.
    ///
    /// No season chip above it (see `seasonChip`), and no `Game` anywhere in
    /// it, so nothing on this tab needs the schedule or the live board.
    private var rosterContent: some View {
        VStack(spacing: Spacing.sm) {
            if let roster = currentRoster, !roster.isEmpty {
                RosterList(roster: roster, league: pageLeague)
            } else if rosterLoading {
                // A lone spinner gets no card — a surface around it hugs
                // into a floating pill (Andy, 2026-08-31).
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            } else if rosterFailed {
                StatusMessage(text: "Couldn't load the roster.",
                              retry: { Task { await loadRoster(force: true) } })
                    .cardSurface()
            } else {
                StatusMessage(text: "Roster TBA")
                    .cardSurface()
            }
        }
        // No top padding: the pinned header carries it, so the gap is
        // the same whether the header is riding along or stuck.
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        // First visit fetches; every visit after is a hit. One request per
        // page, never polled — a roster doesn't change during a game. Keyed
        // by the team so a reused page re-fetches rather than keeping the
        // last one's squad.
        .task(id: team.followKey) { await loadRoster() }
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
            let year = loaded.year ?? seasonNow
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

    /// The one roster request. No year: the endpoint takes none.
    private func loadRoster(force: Bool = false) async {
        let key = team.followKey
        // A page handed a different team drops what it was holding — the
        // fetch-once guard below is only safe about a roster it can name.
        if rosterTeamKey != key {
            roster = nil
            rosterFailed = false
        }
        guard force || currentRoster == nil, !rosterLoading else { return }
        rosterLoading = true
        defer { rosterLoading = false }
        do {
            let loaded = try await client.roster(teamId: team.id)
            // And the page may have been handed another team while this was
            // in flight.
            guard team.followKey == key else { return }
            roster = loaded
            rosterTeamKey = key
            rosterFailed = false
        } catch {
            guard team.followKey == key else { return }
            rosterFailed = true
        }
    }

    private func retry() async {
        if let selectedYear {
            await load(year: selectedYear)
        } else {
            await loadInitial()
        }
    }

    /// Both fetches a scope can need. The shipped response is always
    /// worth having — the Overview record card reads the team's own row
    /// out of it, and scoping back out must never land on a blank table —
    /// while the divisional one rides along only for a pane scoped to it.
    private func loadStandings(scope: StandingsScope, force: Bool = false) async {
        async let shipped: Void = loadStandings(force: force)
        async let divisions: Void = loadDivisionsIfShowing(scope: scope, force: force)
        _ = await (shipped, divisions)
    }

    private func loadDivisionsIfShowing(scope: StandingsScope, force: Bool) async {
        guard scope == .division else { return }
        await loadDivisions(force: force)
    }

    /// The team's division table, the one scope that costs a second
    /// request (ConferencePage's rule, 2026-09-06). Cached per year like
    /// the rest, so flipping scopes and seasons back and forth stays free
    /// after the first look.
    private func loadDivisions(force: Bool = false) async {
        // The same fact that makes Division a real scope: a team with no
        // group above its own has no divisional table to ask for.
        guard Conference.parent(of: resolvedConferenceId, in: pageLeague) != nil else { return }
        let year = standingsYear
        guard force || divisionsByYear[year] == nil else { return }
        guard !divisionLoadingYears.contains(year) else { return }
        divisionLoadingYears.insert(year)
        defer { divisionLoadingYears.remove(year) }
        do {
            divisionsByYear[year] = try await client.divisionStandings(
                year: year == SeasonYear.year(for: pageLeague) ? nil : year)
            divisionFailedYears.remove(year)
        } catch {
            divisionFailedYears.insert(year)
        }
    }

    private func loadStandings(force: Bool = false) async {
        // The NFL's table is keyed by conference, so a division resolves up.
        guard let id = standingsGroupId else { return }
        let year = standingsYear
        // The id re-check also covers a conference that resolved differently
        // once the schedule payload landed.
        // Keyed by "does what we cached still belong to this conference" —
        // a divisional cache holds division ids, never the conference's.
        guard force || standingsByYear[year]?
            .contains(where: { $0.belongs(to: ConferenceID(pageLeague, id)) }) != true else { return }
        guard !standingsLoadingYears.contains(year) else { return }
        standingsLoadingYears.insert(year)
        defer { standingsLoadingYears.remove(year) }
        do {
            // Nil for the current season keeps the shipped request shape;
            // an explicit past year is scoped with `season={year}`.
            let all = try await client.conferenceStandings(
                year: year == SeasonYear.year(for: pageLeague) ? nil : year,
                division: Conference.division(for: id, in: pageLeague) ?? .fbs)
            let target = ConferenceID(pageLeague, id)
            // Stored whole: which tables this pane draws is `tables(for:)`'s
            // job, and the League scope reads the conferences the team's own
            // table came in beside. A response carrying nothing for this
            // conference still caches an empty table under its id, so the
            // guard above sees a fetched season and the tab says "TBA"
            // instead of refetching on every visit.
            let mine = all.filter { $0.belongs(to: target) }
            standingsByYear[year] = mine.isEmpty
                ? all + [ConferenceStandings(id: id,
                                             name: Conference.name(for: id, in: pageLeague),
                                             entries: [], league: pageLeague)]
                : all
            standingsFailedYears.remove(year)
        } catch {
            standingsFailedYears.insert(year)
        }
    }
}
