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
    @State private var standingsByYear: [Int: ConferenceStandings] = [:]
    @State private var gamesByYear: [Int: [Game]] = [:]
    @State private var selectedYear = CFBSeason.year()
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

    private let client: any ScoresProviding = DataProvider.makeClient()

    /// Optional like TeamPage's: the live standings dots degrade to none
    /// wherever the scoreboard isn't in the environment.
    @Environment(ScoreboardStore.self) private var liveBoard: ScoreboardStore?

    /// In-progress games for the standings dots — current season only; a
    /// past season's table gets no live claims.
    private var liveGames: [Game] {
        guard selectedYear == CFBSeason.year() else { return [] }
        return liveBoard?.games.filter(\.isLive) ?? []
    }

    init(destination: ConferenceDestination) {
        self.destination = destination
        // Standings lead (Andy, 2026-08-31) — which is also where a
        // standings-anchored push (a team's "3rd in SEC" line) lands.
        _tab = State(initialValue: .standings)
    }

    private var standings: ConferenceStandings? { standingsByYear[selectedYear] }
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
        return Game.merging(slate, withLive: liveBoard?.games ?? [])
    }

    /// Newest first, floored at 2014 — the CFP era, matching the Scores and
    /// TeamPage selectors.
    private var availableSeasons: [Int] {
        Array(stride(from: CFBSeason.year(), through: 2014, by: -1))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    hero
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
                }
            }
            // The anchor scroll: a push from a TeamPage lands with the
            // team's own row in view, FotMob's table pattern. The Games
            // tab deliberately has no equivalent — the page opens at the
            // top with the hero in view (Andy, 2026-08-29, reverting the
            // scroll-to-current-week first cut).
            .onChange(of: standings) { _, loaded in
                guard tab == .standings,
                      let target = destination.highlightTeamId,
                      loaded?.entries.contains(where: { $0.team.id == target }) == true else { return }
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
            // (Andy, 2026-08-31); the season chip moved into the panes.
            ToolbarItem(placement: .topBarTrailing) {
                ConferenceFollowPill(conferenceId: destination.conferenceId)
            }
        }
        .task { await load(year: selectedYear) }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.md) {
                LogoImage(url: Conference.logoURL(for: destination.conferenceId))
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
                    if let count = standings?.entries.count, count > 0 {
                        Text("\(count) teams")
                            .font(.chipEmphasis)
                            .foregroundStyle(.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)

            tabRow
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgCard)
    }

    // HeroTabBar carries the Figma tab specs.
    private var tabRow: some View {
        HeroTabBar(tabs: [.standings, .games], selection: tab,
                   onSelect: { select(tab: $0) })
    }

    /// The season picker rides the pane, not the hero — the toolbar row
    /// holds the follow pill (Andy, 2026-08-31, matching TeamPage).
    private var seasonRow: some View {
        HStack {
            Spacer()
            SeasonMenuChip(current: selectedYear, seasons: availableSeasons,
                           onSelect: { select(year: $0) })
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
            seasonRow
            if let games, !games.isEmpty {
                ConferenceGamesList(games: games)
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
        .padding(Spacing.sm)
    }

    // MARK: - Standings

    // No CardHeader here: the Standings tab already names the card
    // (Andy, 2026-08-29).
    private var standingsCard: some View {
        VStack(spacing: Spacing.sm) {
            seasonRow
            if let entries = standings?.entries, !entries.isEmpty {
                VStack(spacing: 0) {
                    StandingsList(
                        entries: entries,
                        highlightTeamId: destination.highlightTeamId,
                        showsTitleGameCut: Conference.titleGameIsTopTwo(id: destination.conferenceId,
                                                                        year: selectedYear),
                        liveGames: liveGames
                    )
                }
                .padding(.bottom, Spacing.xs)
                .cardSurface()
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
        .padding(Spacing.sm)
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
                year: year == CFBSeason.year() ? nil : year,
                division: Conference.division(for: destination.conferenceId) ?? .fbs)
            standingsByYear[year] = all.first { $0.id == destination.conferenceId }
                ?? ConferenceStandings(id: destination.conferenceId,
                                       name: destination.name, entries: [])
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
