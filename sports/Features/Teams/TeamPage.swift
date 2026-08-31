import SwiftUI

/// One team's home: a hero header in the team's own color (the budget's
/// fourth exception — Andy's call, 2026-08-25), Games and Standings tabs,
/// and a schedule for any season back to the CFP era.
struct TeamPage: View {
    let team: Team

    /// Optional form: previews/tests without RootView's environment degrade
    /// to the pushed value instead of trapping.
    @Environment(TeamDirectoryStore.self) private var directory: TeamDirectoryStore?
    /// Optional like the directory: the fresher-game merge degrades to the
    /// schedule payload wherever the scoreboard isn't in the environment.
    @Environment(ScoreboardStore.self) private var liveBoard: ScoreboardStore?
    @Environment(\.dismiss) private var dismiss

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
    /// The Standings tab's data, fetched lazily on first visit.
    @State private var conferenceStandings: ConferenceStandings?
    @State private var standingsLoading = false
    @State private var standingsFailed = false

    private let client: any ScoresProviding = DataProvider.makeClient()

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
    /// One veto, disproof-shaped (refined 2026-08-29): an FCS opponent's
    /// payload can reuse a group id that collides with our FBS table, so
    /// an unknown team's claim stands only when the directory can't
    /// disprove it — the claimed conference has a roster and this team
    /// isn't on it. An EMPTY roster proves nothing: ESPN ships the Sun
    /// Belt with zero standings entries (still true 2026-08-29), and the
    /// old know-the-team-or-nothing veto was silently stripping every
    /// Sun Belt page of its conference line and Standings tab. (The
    /// veto's original NDSU example aged out — their Mountain West line
    /// is real 2026 realignment, confirmed against the standings.)
    private var resolvedConferenceId: Int? {
        let claimed = schedule?.team?.conferenceId
            ?? team.conferenceId
            ?? directory?.allTeams.first(where: { $0.id == team.id })?.conferenceId
        if let directory, !directory.allTeams.isEmpty,
           !directory.allTeams.contains(where: { $0.id == team.id }),
           let claimed,
           directory.allTeams.contains(where: { $0.conferenceId == claimed }) {
            return nil
        }
        return claimed
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

    /// The scoreboard's copy of a schedule game when it has one: the
    /// schedule payload carries no live scores or clock mid-game (the
    /// dashed-score bug, Andy 2026-08-29), while the scoreboard polls
    /// every 30s. A game outside the scoreboard's selected week falls
    /// back to the schedule's own snapshot.
    private func fresher(_ game: Game) -> Game {
        liveBoard?.games.first { $0.id == game.id } ?? game
    }

    // MARK: - Hero paint

    /// The schedule payload is the only source that serves `color`; the
    /// hero starts monochrome and takes the team's color when it lands.
    private var heroColorHex: String? { schedule?.team?.colorHex ?? team.colorHex }
    private var heroColor: Color? { Color(espnHex: heroColorHex) }
    /// White ink on the team color, except the handful of colors too light
    /// to carry it. Monochrome fallback uses the theme tokens.
    private var heroOnDark: Bool { heroColor != nil && !Color.espnHexIsLight(heroColorHex) }
    private var heroInk: Color {
        heroColor == nil ? .textPrimary : (heroOnDark ? .white : .black)
    }
    private var heroInkSecondary: Color {
        heroColor == nil ? .textSecondary : heroInk.opacity(0.6)
    }

    private var showsStandingsTab: Bool {
        resolvedConferenceId.map { Conference.tier(for: $0) != .other } ?? false
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
        // Team color through the status-bar strip while the hero is up —
        // the glass back/share buttons refract it, FotMob-style (Andy,
        // 2026-08-29; mechanism replaced 2026-08-31).
        .heroTopBand(heroColor ?? Color.bgPrimary)
        .background(Color.bgRecessed)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(heroColor ?? Color.bgPrimary, for: .navigationBar)
        // Transparent while the hero is at the top — the glass buttons
        // sit directly on team color; solid once the hero scrolls under,
        // exactly when the inline title arrives.
        .toolbarBackground(showsInlineTitle ? .visible : .hidden, for: .navigationBar)
        .toolbarColorScheme(heroColor == nil ? nil : (heroOnDark ? .dark : .light),
                            for: .navigationBar)
        // Custom back and share: dark-tinted glass circles with white ink,
        // legible on team color where the system's untinted glass washed
        // out (Andy, 2026-08-29). The system's own glass wrapper hides on
        // iOS 26 so the tinted circle isn't glass-on-glass; swipe-back
        // survives the hidden system button under NavigationStack.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarLeading) { backButton }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarLeading) { backButton }
            }
            ToolbarItem(placement: .principal) {
                Text(team.location)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(heroOnDark ? .white : Color.textPrimary)
                    .lineLimit(1)
                    .opacity(showsInlineTitle ? 1 : 0)
                    .accessibilityHidden(!showsInlineTitle)
            }
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarTrailing) { shareButton }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) { shareButton }
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

    private var barInk: Color { heroOnDark ? .white : Color.textPrimary }
    private var barGlassTint: Color {
        heroOnDark ? Color.black.opacity(0.35) : Color.white.opacity(0.4)
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(barInk)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassCircleInteractive(tint: barGlassTint,
                                fallback: heroOnDark ? Color.black.opacity(0.3) : Color.bgElevated)
        .accessibilityLabel("Back")
    }

    private var shareButton: some View {
        ShareLink(item: team.shareText(schedule: currentSchedule)) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(barInk)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassCircleInteractive(tint: barGlassTint,
                                fallback: heroOnDark ? Color.black.opacity(0.3) : Color.bgElevated)
        .accessibilityLabel("Share this team")
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.md) {
                Spacer()
                NotificationBell(onDark: heroOnDark)
                if let selectedYear {
                    SeasonMenuChip(current: selectedYear, seasons: availableSeasons,
                                   onSelect: { select(year: $0) }, onDark: heroOnDark)
                }
                FollowPill(teamId: team.id, onDark: heroOnDark)
            }
            .padding(.horizontal, Spacing.lg)

            HStack(spacing: Spacing.md) {
                logoMark
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.location)
                        .font(.heroTitle)
                        .foregroundStyle(heroInk)
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
        // The strip above — through the transparent bar and the top bounce
        // — is heroTopBand's job: an in-content extension never escaped
        // the ScrollView's clip (2026-08-31).
        .background(heroColor ?? Color.bgPrimary)
    }

    /// On a colored hero the mark sits in a white disc so dark artwork
    /// (Ohio State's lettering) never sinks into the team color — the same
    /// job `logoBacking` does in dark mode. Monochrome fallback goes bare.
    @ViewBuilder
    private var logoMark: some View {
        if heroColor != nil {
            ZStack {
                Circle().fill(.white)
                LogoImage(url: team.logoURL)
                    .frame(width: 44, height: 44)
            }
            .frame(width: 56, height: 56)
        } else {
            LogoImage(url: team.logoURL)
                .frame(width: 56, height: 56)
        }
    }

    /// Conference plus record on one line ("Big Ten · 10-1"); the placement
    /// string moved into the Standings tab, where it's a table instead of a
    /// claim. Links to the full conference page when there is one.
    @ViewBuilder
    private var conferenceLine: some View {
        // A past season's record derives from its final results — the
        // provider's summary only describes the current season (the mapper
        // nils it otherwise).
        let record = schedule?.record ?? schedule?.derivedRecord
        let name = resolvedConferenceId.map { Conference.name(for: $0) }
        let label = [name, record].compactMap { $0 }.joined(separator: " · ")
        if let id = resolvedConferenceId, Conference.tier(for: id) != .other {
            NavigationLink(value: ConferenceDestination(conferenceId: id,
                                                        name: Conference.name(for: id),
                                                        highlightTeamId: team.id)) {
                HStack(spacing: Spacing.xs) {
                    Text(label)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.chipEmphasis)
                .foregroundStyle(heroInkSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityHint("View conference standings")
        } else if !label.isEmpty {
            Text(label)
                .font(.chipEmphasis)
                .foregroundStyle(heroInkSecondary)
        }
    }

    private var tabRow: some View {
        HeroTabBar(tabs: visibleTabs, selection: tab, ink: heroInk,
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

    /// The team's own row in its conference table — the record card's
    /// source while the season is current.
    private var ownStanding: ConferenceStanding? {
        conferenceStandings?.entries.first { $0.team.id == team.id }
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
                // treatment so the tab is never silently blank.
                VStack(spacing: 0) {
                    if isLoadingSelected {
                        ProgressView().padding(.vertical, Spacing.xl)
                    } else if showsErrorForSelected {
                        VStack(spacing: Spacing.sm) {
                            Text("Couldn't load the season.")
                                .font(.teamName)
                                .foregroundStyle(.textSecondary)
                            Button("Retry") { Task { await retry() } }
                                .font(.teamNameEmphasis)
                                .foregroundStyle(.textPrimary)
                        }
                        .padding(.vertical, Spacing.xl)
                    } else {
                        Text("Season TBA")
                            .font(.teamName)
                            .foregroundStyle(.textSecondary)
                            .padding(.vertical, Spacing.xl)
                    }
                }
                .frame(maxWidth: .infinity)
                .cardSurface()
            }
        }
        .padding(Spacing.sm)
    }

    private var gamesContent: some View {
        VStack(spacing: Spacing.sm) {
            if let nextGame {
                NextGameCard(game: nextGame)
                    .cardSurface()
            }
            VStack(spacing: 0) {
                TeamScheduleSection(
                    teamId: team.id,
                    games: (schedule?.games ?? []).map(fresher),
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
        VStack(spacing: 0) {
            if let entries = conferenceStandings?.entries, !entries.isEmpty {
                StandingsList(
                    entries: entries,
                    highlightTeamId: team.id,
                    // The tab always shows the current season.
                    showsTitleGameCut: Conference.titleGameIsTopTwo(id: resolvedConferenceId,
                                                                    year: CFBSeason.year()),
                    liveGames: liveBoard?.games.filter(\.isLive) ?? []
                )
            } else if standingsLoading {
                ProgressView().padding(.vertical, Spacing.xl)
            } else if standingsFailed {
                VStack(spacing: Spacing.sm) {
                    Text("Couldn't load standings.")
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                    Button("Retry") { Task { await loadStandings(force: true) } }
                        .font(.teamNameEmphasis)
                        .foregroundStyle(.textPrimary)
                }
                .padding(.vertical, Spacing.xl)
            } else {
                Text("Standings TBA")
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
        .padding(Spacing.sm)
        .task { await loadStandings() }
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
        guard force || conferenceStandings?.id != id else { return }
        guard !standingsLoading else { return }
        standingsLoading = true
        defer { standingsLoading = false }
        do {
            let all = try await client.conferenceStandings()
            conferenceStandings = all.first { $0.id == id }
            standingsFailed = false
        } catch {
            standingsFailed = true
        }
    }
}
