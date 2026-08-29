import SwiftUI

/// One conference's home, on the TeamPage template (Andy's call,
/// 2026-08-25): hero header with the cluster top-right, Games and
/// Standings tabs (the Games tab joined 2026-08-29 — the season's full
/// conference slate, week by week), content as cards on the recessed
/// surface. Conferences ship no ESPN color, so the hero is the template's
/// monochrome variant. Standings stay in the provider's order
/// (seed-backed — never re-sorted here).
struct ConferencePage: View {
    let destination: ConferenceDestination

    private enum Tab { case games, standings }

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
        // A standings-anchored push (a team's "3rd in SEC" line) must land
        // on the table; everything else leads with the games.
        _tab = State(initialValue: destination.highlightTeamId == nil ? .games : .standings)
    }

    private var standings: ConferenceStandings? { standingsByYear[selectedYear] }
    private var isLoading: Bool { loadingYears.contains(selectedYear) }
    private var showsError: Bool { failedYears.contains(selectedYear) }
    private var games: [Game]? { gamesByYear[selectedYear] }
    private var gamesLoading: Bool { gamesLoadingYears.contains(selectedYear) }
    private var gamesError: Bool { gamesFailedYears.contains(selectedYear) }

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
                        case .games: gamesSection
                        case .standings: standingsCard
                        }
                    }
                    .id(tab)
                    .transition(.push(from: tabSlideEdge))
                    // The week swipe's sibling (Andy, 2026-08-29): swipe
                    // the content to walk the tab pair; the buttons stay.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                let dx = value.translation.width
                                guard abs(dx) > 50,
                                      abs(dx) > abs(value.translation.height) * 1.5 else { return }
                                select(tab: dx < 0 ? .standings : .games)
                            }
                    )
                }
                .animation(.default, value: tab)
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
        .background(Color.bgRecessed)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await load(year: selectedYear) }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.md) {
                Spacer()
                SeasonMenuChip(current: selectedYear, seasons: availableSeasons,
                               onSelect: { select(year: $0) })
                ConferenceFollowPill(conferenceId: destination.conferenceId)
            }
            .padding(.horizontal, Spacing.lg)

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
        .background(Color.bgPrimary)
    }

    // The Figma header component's tab specs, followed exactly (TeamPage's
    // row, monochrome ink): 40pt gap, 14pt vertical padding, bold 14 at
    // −2% tracking, 3pt bottom bar, inactive ink at 50%.
    private var tabRow: some View {
        HStack(spacing: 40) {
            tabButton("Games", .games)
            tabButton("Standings", .standings)
        }
    }

    /// Chip taps and content swipes share the one direction rule.
    private func select(tab value: Tab) {
        guard value != tab else { return }
        tabSlideEdge = value == .standings ? .trailing : .leading
        tab = value
    }

    private func tabButton(_ title: String, _ value: Tab) -> some View {
        Button {
            select(tab: value)
        } label: {
            Text(title)
                .font(.tab)
                .tracking(-0.28)
                .foregroundStyle(tab == value ? Color.textPrimary : Color.textPrimary.opacity(0.5))
                .padding(.vertical, 14)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(tab == value ? Color.textPrimary : Color.clear)
                        .frame(height: 3)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tab == value ? [.isSelected] : [])
    }

    // MARK: - Games

    private var gamesSection: some View {
        VStack(spacing: Spacing.sm) {
            if let games, !games.isEmpty {
                ConferenceGamesList(games: games)
            } else if gamesLoading {
                statusCard { ProgressView().padding(.vertical, Spacing.xl) }
            } else if gamesError {
                statusCard {
                    VStack(spacing: Spacing.sm) {
                        Text("Couldn't load the schedule.")
                            .font(.teamName)
                            .foregroundStyle(.textSecondary)
                        Button("Retry") {
                            Task { await loadGames(year: selectedYear, force: true) }
                        }
                        .font(.teamNameEmphasis)
                        .foregroundStyle(.textPrimary)
                    }
                    .padding(.vertical, Spacing.xl)
                }
            } else {
                statusCard {
                    Text("Schedule TBA")
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                }
            }
        }
        .padding(Spacing.sm)
    }

    private func statusCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity)
            .cardSurface()
    }

    // MARK: - Standings

    // No CardHeader here: the Standings tab already names the card
    // (Andy, 2026-08-29).
    private var standingsCard: some View {
        VStack(spacing: 0) {
            if let entries = standings?.entries, !entries.isEmpty {
                StandingsList(
                    entries: entries,
                    highlightTeamId: destination.highlightTeamId,
                    showsTitleGameCut: Conference.titleGameIsTopTwo(id: destination.conferenceId,
                                                                    year: selectedYear),
                    liveGames: liveGames
                )
            } else if isLoading {
                ProgressView().padding(.vertical, Spacing.xl)
            } else if showsError {
                VStack(spacing: Spacing.sm) {
                    Text("Couldn't load standings.")
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                    Button("Retry") {
                        Task { await loadStandings(year: selectedYear, force: true) }
                    }
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
                }
                .padding(.vertical, Spacing.xl)
            } else {
                // ESPN's offseason standings can come back empty (Sun Belt
                // did), and an old season can omit a young conference.
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
                year: year == CFBSeason.year() ? nil : year)
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
