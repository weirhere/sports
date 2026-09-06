import Foundation
import Observation

/// The Scores screen's model: one day, every league.
///
/// The day is the axis (Andy, 2026-09-05). A week strip could only ever be
/// honest about one league — college football's Week 2 and the NFL's are
/// different date ranges, and its single "Bowls" slot swallows four NFL
/// playoff rounds whole — so the leagues stack as accordions under one
/// shared calendar instead of taking turns behind a selector.
///
/// Each `ScoreboardStore` owns its league's games; this owns the day, the
/// season, and the assembly of the two into sections.
@Observable
@MainActor
final class LeagueScoreboards {
    private let stores: [League: ScoreboardStore]

    /// The day on screen, always a local start-of-day.
    private(set) var selectedDay: Date
    /// The season the strip is bounded to. Its own value rather than a
    /// derivation of `selectedDay`, because selecting a season is what
    /// moves the day, not the other way round.
    private(set) var seasonYear: Int
    /// The season "now" belongs to — the picker's top entry, and the one
    /// the day strip returns to.
    let currentSeasonYear: Int

    private(set) var isLoading = false

    /// Set while the app is looking for a day worth showing (an August
    /// Tuesday, or a freshly picked past season). The strip keeps its
    /// place until the answer lands rather than flashing an empty day.
    @ObservationIgnored private var snapTask: Task<Void, Never>?

    init(stores: [League: ScoreboardStore]? = nil,
         today: Date = .now,
         calendar: Calendar = .current) {
        self.stores = stores ?? Dictionary(
            uniqueKeysWithValues: League.allCases.map { ($0, ScoreboardStore(league: $0)) }
        )
        let season = SeasonSpan.year(containing: today, calendar: calendar)
        self.currentSeasonYear = season
        self.seasonYear = season
        // Today, unless today is outside the season entirely — the deep
        // offseason opens on the season's nominal start and then snaps
        // forward to the first day anyone plays.
        let span = SeasonSpan.days(year: season, calendar: calendar)
        let today = calendar.startOfDay(for: today)
        self.selectedDay = min(max(today, span.lowerBound), span.upperBound)
    }

    func store(for league: League) -> ScoreboardStore {
        // Every league has a store by construction; the fallback exists so
        // a lookup can't crash a screen.
        stores[league] ?? stores[.collegeFootball] ?? ScoreboardStore(league: league)
    }

    var all: [ScoreboardStore] { League.allCases.map(store(for:)) }

    /// The first error any league is reporting — the refresh banner's copy.
    var lastError: String? {
        all.compactMap(\.lastError).first
    }

    var hasLiveGames: Bool { all.contains(where: \.hasLiveGames) }

    /// Every game on the selected day, across every league. The screen's
    /// "is there anything here at all" question.
    var selectedDayGames: [Game] {
        all.flatMap { $0.games(on: selectedDay) }
    }

    /// Every game in memory, across every league and every cached day —
    /// the search corpus. Deliberately not a new fetch surface: search
    /// answers from what the Scores screen already loaded.
    var allLoadedGames: [Game] {
        all.flatMap { $0.gamesByDay.values.flatMap { $0 } }
    }

    /// A game by id, anywhere in memory — the widget and notification
    /// deep-link target. The search space is every day still cached across
    /// every league; an id outside it degrades to landing on Scores.
    func game(id: String) -> Game? {
        for store in all {
            for games in store.gamesByDay.values {
                if let game = games.first(where: { $0.id == id }) { return game }
            }
        }
        return nil
    }

    /// True once every league has answered for the selected day. An empty
    /// day and an unfetched one look identical, and only one of them
    /// should say "no games".
    var selectedDayIsLoaded: Bool {
        all.allSatisfy { $0.isLoaded(selectedDay) }
    }

    // MARK: - The day strip

    /// Selectable seasons, newest first. Floor is 2014 — the CFP era.
    var availableSeasons: [Int] {
        Array(stride(from: currentSeasonYear, through: League.collegeFootball.seasonFloor, by: -1))
    }

    /// Every day of the selected season, in order — the strip's contents.
    /// Bounded by the season rather than rolling forever, so scrolling has
    /// ends and a past season is a place you can actually be.
    func days(calendar: Calendar = .current) -> [DaySlot] {
        let span = SeasonSpan.days(year: seasonYear, calendar: calendar)
        var result: [DaySlot] = []
        var cursor = span.lowerBound
        while cursor <= span.upperBound {
            result.append(DaySlot(cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// The day `offset` steps from the selected one, or nil past either end
    /// of the season — where a swipe is a quiet no-op.
    func adjacentDay(offset: Int, calendar: Calendar = .current) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: offset, to: selectedDay) else { return nil }
        let span = SeasonSpan.days(year: seasonYear, calendar: calendar)
        guard day >= calendar.startOfDay(for: span.lowerBound),
              day <= span.upperBound else { return nil }
        return day
    }

    var isOnToday: Bool {
        Calendar.current.isDateInToday(selectedDay) && seasonYear == currentSeasonYear
    }

    // MARK: - Loading

    /// First load: the day the app opened on, plus a snap forward if
    /// nobody is playing then.
    func loadInitial() async {
        await load(around: selectedDay)
        snapForwardIfEmpty()
    }

    func select(day: Date) async {
        let day = Calendar.current.startOfDay(for: day)
        guard day != selectedDay else { return }
        snapTask?.cancel()
        selectedDay = day
        await load(around: day)
    }

    /// Switch seasons. The strip re-bounds and lands on the first day of
    /// that season anyone actually plays — its nominal August start is
    /// weeks of empty chips otherwise.
    func select(season year: Int) async {
        guard year != seasonYear else { return }
        snapTask?.cancel()
        seasonYear = year
        let span = SeasonSpan.days(year: year)
        selectedDay = year == currentSeasonYear
            ? min(max(Calendar.current.startOfDay(for: .now), span.lowerBound), span.upperBound)
            : span.lowerBound
        await load(around: selectedDay)
        snapForwardIfEmpty()
    }

    /// Back to today — the Live filter's landing, and the strip's home.
    func selectToday() async {
        if seasonYear != currentSeasonYear {
            await select(season: currentSeasonYear)
        } else {
            await select(day: .now)
        }
    }

    func refresh() async {
        let day = selectedDay
        await withTaskGroup(of: Void.self) { group in
            for store in all {
                group.addTask { await store.load(around: day, force: true) }
            }
        }
    }

    /// Every league's window in flight at once — two requests, not two
    /// round trips.
    private func load(around day: Date) async {
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: Void.self) { group in
            for store in all {
                group.addTask { await store.load(around: day) }
            }
        }
    }

    /// Move to the next day anyone is playing, when the one we landed on
    /// is empty.
    ///
    /// Only ever fires on a day the *app* chose — launch and season
    /// switches. A day the user picked stays picked, empty or not: an app
    /// that slides out from under a deliberate tap is a worse bug than an
    /// empty Tuesday.
    private func snapForwardIfEmpty() {
        guard selectedDayIsLoaded, selectedDayGames.isEmpty else { return }
        let from = selectedDay
        snapTask?.cancel()
        snapTask = Task { [weak self] in
            guard let self else { return }
            let found = await withTaskGroup(of: Date?.self) { group in
                for store in self.all {
                    group.addTask { await store.firstDayWithGames(from: from) }
                }
                return await group.reduce(into: [Date]()) { days, day in
                    if let day { days.append(day) }
                }.min()
            }
            guard !Task.isCancelled, let found, found != self.selectedDay else { return }
            // The user may have moved while the probe was out; their choice wins.
            guard self.selectedDay == from else { return }
            await self.select(day: found)
        }
    }

    // MARK: - Polling

    /// Polls every league that has something live. Each store starts its
    /// own loop only when it needs one, so a quiet league costs nothing.
    func startPollingIfNeeded() {
        for store in all { store.startPollingIfNeeded() }
    }

    func stopPolling() {
        for store in all { store.stopPolling() }
    }

    /// Widen or narrow every league's divisions together.
    func select(divisions: Set<Conference.Division>) async {
        await withTaskGroup(of: Void.self) { group in
            for store in all {
                group.addTask { await store.select(divisions: divisions) }
            }
        }
    }

    // MARK: - Sections

    /// The selected day, as the screen renders it: Following pinned first,
    /// then one accordion per league.
    ///
    /// Following stays cross-league — "my games" shouldn't care which sport
    /// they belong to — and a followed game appears in both it and its
    /// league's section, because sections are complete, never deduplicated.
    /// It orders by state rather than by clock: live at the top, finals at
    /// the bottom (see `byState`).
    ///
    /// Live composes with everything — it is a state, not a scope. The
    /// slate filter is a scope, so it narrows the league sections and
    /// leaves Following alone: narrowing "my games" to the SEC would
    /// silently empty the section for a Michigan fan, which is exactly the
    /// mystery state the labeled chip exists to avoid. A filter also hides
    /// the leagues it can't speak for outright rather than emptying them —
    /// "SEC" is not a question the NFL's slate can answer.
    func sections(day: Date? = nil,
                  followingIds: Set<String>,
                  followedConferenceIds: Set<ConferenceID> = [],
                  liveOnly: Bool = false,
                  filter: ScoreFilter? = nil) -> [GameSection] {
        let day = day ?? selectedDay
        var result: [GameSection] = []
        var following: [Game] = []

        func isFollowed(_ game: Game) -> Bool {
            followingIds.contains(game.home.team.followKey)
                || followingIds.contains(game.away.team.followKey)
                || game.home.team.conference.map(followedConferenceIds.contains) ?? false
                || game.away.team.conference.map(followedConferenceIds.contains) ?? false
        }

        var leagueSections: [GameSection] = []
        for league in League.allCases {
            var games = store(for: league).games(on: day)
            if liveOnly { games = games.filter(\.isLive) }
            // Followed games are claimed before the filter narrows the
            // league's own section, so a followed team stays visible under
            // Following while its league's list is scoped to one conference.
            following += games.filter(isFollowed)
            if let filter {
                guard filter.league == nil || filter.league == league else { continue }
                games = games.filter(filter.matches)
            }
            guard !games.isEmpty else { continue }
            leagueSections.append(GameSection(id: GameSection.id(for: league),
                                              title: league.displayName,
                                              games: games,
                                              league: league))
        }

        if !following.isEmpty {
            let leagues = Set(following.map(\.home.team.league))
            result.append(GameSection(id: GameSection.followingId, title: "Following",
                                      games: byState(following),
                                      spansLeagues: leagues.count > 1))
        }
        return result + leagueSections
    }

    /// Following's order: what's happening now, then what's about to, then
    /// what already did. The section is a Saturday's worth of one fan's
    /// games at once, so a final has nothing left to say while a live game
    /// changes every play — chronological alone buried the live row under
    /// the morning's results. Within a state the clock still orders them.
    private func byState(_ games: [Game]) -> [Game] {
        games.sorted {
            let (a, b) = (Self.stateRank($0.status), Self.stateRank($1.status))
            if a != b { return a < b }
            switch ($0.date, $1.date) {
            case let (x?, y?) where x != y: return x < y
            case (nil, _?): return false
            case (_?, nil): return true
            default: return $0.id < $1.id
            }
        }
    }

    /// Live first, then upcoming, then finals, then the postponed and
    /// canceled — a row with nothing to watch and no result sits last.
    private static func stateRank(_ status: GameStatus) -> Int {
        switch status {
        case .live: 0
        case .pre: 1
        case .final: 2
        case .other: 3
        }
    }
}
