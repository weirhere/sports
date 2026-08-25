import SwiftUI

/// One team's home: a hero header in the team's own color (the budget's
/// fourth exception — Andy's call, 2026-08-25), Games and Standings tabs,
/// and a schedule for any season back to the CFP era.
struct TeamPage: View {
    let team: Team

    /// Optional form: previews/tests without RootView's environment degrade
    /// to the pushed value instead of trapping.
    @Environment(TeamDirectoryStore.self) private var directory: TeamDirectoryStore?

    private enum Tab { case games, standings }

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

    @State private var tab: Tab = .games
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
    private var resolvedConferenceId: Int? {
        schedule?.team?.conferenceId
            ?? team.conferenceId
            ?? directory?.allTeams.first(where: { $0.id == team.id })?.conferenceId
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
        }
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
                switch tab {
                case .games: gamesContent
                case .standings: standingsContent
                }
            }
        }
        .background(Color.bgRecessed)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(heroColor ?? Color.bgPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(heroColor == nil ? nil : (heroOnDark ? .dark : .light),
                            for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: team.shareText(schedule: currentSchedule)) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(heroOnDark ? .white : Color.textPrimary)
                }
                .accessibilityLabel("Share this team")
            }
        }
        .task { await loadInitial() }
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

            if showsStandingsTab {
                tabRow
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
            } else {
                Color.clear.frame(height: Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        HStack(spacing: Spacing.xl) {
            tabButton("Games", .games)
            tabButton("Standings", .standings)
        }
    }

    private func tabButton(_ title: String, _ value: Tab) -> some View {
        Button {
            tab = value
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.chipEmphasis)
                    .foregroundStyle(tab == value ? heroInk : heroInkSecondary)
                Capsule()
                    .fill(tab == value ? heroInk : Color.clear)
                    .frame(height: 3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tab == value ? [.isSelected] : [])
    }

    // MARK: - Tab content

    private var gamesContent: some View {
        VStack(spacing: Spacing.sm) {
            if let nextGame {
                NextGameCard(game: nextGame, teamId: team.id)
                    .cardSurface()
            }
            VStack(spacing: 0) {
                TeamScheduleSection(
                    teamId: team.id,
                    games: schedule?.games ?? [],
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

    private var standingsContent: some View {
        VStack(spacing: 0) {
            CardHeader(title: "Standings")
            if let entries = conferenceStandings?.entries, !entries.isEmpty {
                ForEach(entries) { standing in
                    NavigationLink(value: standing.team) {
                        ConferenceStandingRow(standing: standing)
                    }
                    .buttonStyle(.plain)
                    // This team's own row gets the anchor treatment.
                    .background(standing.team.id == team.id ? Color.bgHeader : Color.clear)
                    if standing.id != entries.last?.id {
                        Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                    }
                }
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
