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
/// season, and the assembly of the two into sections — see `sections` for
/// the shape those take.
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
    var selectedDayIsLoaded: Bool { isLoaded(selectedDay) }

    func isLoaded(_ day: Date) -> Bool {
        all.allSatisfy { $0.isLoaded(day) }
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

    /// The day `offset` steps from `from` (the selected one by default), or
    /// nil past either end of the season — where a swipe is a quiet no-op.
    ///
    /// `from` is what a settling swipe passes: the day committed the moment
    /// the thumb lifted is already selected, while the panes still show the
    /// one sliding out.
    func adjacentDay(offset: Int, from: Date? = nil, calendar: Calendar = .current) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: offset, to: from ?? selectedDay) else { return nil }
        let span = SeasonSpan.days(year: seasonYear, calendar: calendar)
        guard day >= calendar.startOfDay(for: span.lowerBound),
              day <= span.upperBound else { return nil }
        return day
    }

    var isOnToday: Bool {
        Calendar.current.isDateInToday(selectedDay) && seasonYear == currentSeasonYear
    }

    /// Whether the way back to today has anywhere to go — false when we are
    /// already there, and false in the offseason, where today is outside
    /// every league's span and `selectToday()` would land the strip on a
    /// day it cannot show. The span is the *current* season's, not the
    /// selected one's: jumping home switches season first.
    var canJumpToToday: Bool {
        guard !isOnToday else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let span = SeasonSpan.days(year: currentSeasonYear, calendar: calendar)
        return today >= calendar.startOfDay(for: span.lowerBound) && today <= span.upperBound
    }

    /// How far the strip can drift with today's chip still on screen. The
    /// strip centres its selection and the chips carry their month now, so
    /// the Today chip is already clipping at the leading edge two days out
    /// and gone at three (Andy, 2026-09-07).
    private static let todayChipReach = 2

    /// Whether today's own chip is still within reach on the strip — the
    /// floating button's other gate. A control that duplicates a chip the
    /// thumb can already see is chrome saying the same thing twice.
    ///
    /// A past season has no today chip at all, however close the dates
    /// look: the strip is bounded to the season it shows.
    func todayIsOnStrip(calendar: Calendar = .current) -> Bool {
        guard seasonYear == currentSeasonYear else { return false }
        let today = calendar.startOfDay(for: .now)
        let distance = calendar.dateComponents([.day], from: today, to: selectedDay).day ?? 0
        return abs(distance) <= Self.todayChipReach
    }

    /// The floating Today button's whole condition: somewhere to go, and
    /// today's chip out of view (Andy, 2026-09-07).
    var showsTodayJump: Bool {
        canJumpToToday && !todayIsOnStrip()
    }

    // MARK: - Loading

    /// First load: the day the app opened on, plus a snap forward if
    /// nobody is playing then.
    func loadInitial() async {
        await load(around: selectedDay)
        snapForwardIfEmpty()
    }

    func select(day: Date) async {
        guard show(day: day) else { return }
        await loadSelectedDay()
    }

    /// Move to `day` now, without waiting on the network — the synchronous
    /// half of `select(day:)`.
    ///
    /// The day strip, the header and the Today button all read
    /// `selectedDay`, and a swipe has to move them on the frame the thumb
    /// lifts (Andy, 2026-09-07). Callers that split the move from the fetch
    /// pair this with `loadSelectedDay()`. Returns whether the day moved.
    @discardableResult
    func show(day: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: day)
        guard day != selectedDay else { return false }
        snapTask?.cancel()
        selectedDay = day
        return true
    }

    /// Fetch whatever day is selected — the other half of the split above.
    func loadSelectedDay() async {
        await load(around: selectedDay)
    }

    /// Land on a specific day and fetch it — a deep link's arrival.
    ///
    /// Unlike `select(day:)` this re-bounds the strip first: the day comes
    /// from outside the app, so it can belong to a season the strip is not
    /// currently showing, and a selected day the strip has no chip for is
    /// a screen with no way back. The fetch itself is the ordinary window,
    /// which no-ops when the day is already in hand.
    func open(day: Date) async {
        let year = SeasonSpan.year(containing: day)
        if year != seasonYear {
            snapTask?.cancel()
            seasonYear = year
        }
        show(day: day)
        await loadSelectedDay()
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

    /// The selected day, as the screen renders it: Following, then the
    /// tables you follow, then the day's whole slate.
    ///
    /// **Following is your teams.** A followed conference used to pour its
    /// whole slate in here; since 2026-09-06 it doesn't (Andy) — a Big Ten
    /// follow is ~8 games on a Saturday, which buries the three you
    /// actually care about. A followed table earns a section of its own
    /// directly beneath Following instead, in the order you dragged them
    /// into on the tables hub.
    ///
    /// **College football breaks down by conference; the NFL doesn't**
    /// (Andy, 2026-09-06, superseding the one-accordion-per-league shape).
    /// A single "College Football" accordion is 60 rows on a Saturday with
    /// no way in; its conferences are the way fans already carve it up.
    /// The NFL's 16 games in one section is the whole slate at a glance,
    /// and splitting it by division would be four rows a section.
    ///
    /// Sections stay complete, never deduplicated: a game is in Following,
    /// in a followed table's section, and in its conference's. The one
    /// thing that never doubles is a section with itself — a followed
    /// conference *moves* up the page rather than being cloned, which is
    /// what `table` identifies.
    ///
    /// Live composes with everything — it is a state, not a scope. The
    /// slate filter is a scope, so it narrows the stack and leaves
    /// Following alone: narrowing "my games" to the SEC would silently
    /// empty the section for a Michigan fan, which is exactly the mystery
    /// state the labeled chip exists to avoid. A filter also hides the
    /// leagues it can't speak for outright rather than emptying them —
    /// "SEC" is not a question the NFL's slate can answer.
    func sections(day: Date? = nil,
                  followingIds: Set<String>,
                  followedTables: [FollowedTable] = [],
                  liveOnly: Bool = false,
                  filter: ScoreFilter? = nil) -> [GameSection] {
        let day = day ?? selectedDay
        var following: [Game] = []
        // Per league, the games the stack is allowed to show. Following is
        // claimed before the filter narrows anything, so a followed team
        // stays visible while the slate below is scoped.
        var visible: [League: [Game]] = [:]

        for league in League.allCases {
            var games = store(for: league).games(on: day)
            if liveOnly { games = games.filter(\.isLive) }
            following += games.filter { game in
                followingIds.contains(game.home.team.followKey)
                    || followingIds.contains(game.away.team.followKey)
            }
            if let filter {
                guard filter.league == nil || filter.league == league else { continue }
                games = games.filter(filter.matches)
            }
            visible[league] = games
        }

        // The full slate, in its resting order.
        var stack = conferenceSections(from: visible[.collegeFootball] ?? [])
        if let nfl = visible[.nfl], !nfl.isEmpty {
            stack.append(GameSection(id: GameSection.id(for: .nfl),
                                     title: League.nfl.displayName,
                                     games: nfl,
                                     league: .nfl,
                                     logoURL: League.nfl.logoURL,
                                     // The whole league standing as one
                                     // table — following the NFL on the
                                     // hub hoists this very section.
                                     table: Conference.leagueWideId(in: .nfl)
                                         .map { FollowedTable.conference(ConferenceID(.nfl, $0)) }))
        }

        // Followed tables lead the stack, in the user's order. One already
        // in it moves; one that isn't (a poll, an NFL conference) is built
        // here and added.
        var hoisted: [GameSection] = []
        var hoistedIds: Set<String> = []
        for table in followedTables {
            // A filter that can't speak for this table's league hides it,
            // the same way it hides that league's own sections.
            if let scope = filter?.league, scope != table.league { continue }
            if let existing = stack.first(where: { $0.table == table }) {
                guard hoistedIds.insert(existing.id).inserted else { continue }
                hoisted.append(existing)
                continue
            }
            let games = (visible[table.league] ?? []).filter(table.matches)
            guard !games.isEmpty else { continue }
            let section = GameSection(id: table.token, title: table.name, games: games,
                                      league: table.league, logoURL: table.logoURL,
                                      table: table)
            guard hoistedIds.insert(section.id).inserted else { continue }
            hoisted.append(section)
        }

        var result: [GameSection] = []
        if !following.isEmpty {
            let leagues = Set(following.map(\.home.team.league))
            result.append(GameSection(id: GameSection.followingId, title: "Following",
                                      games: byState(following),
                                      spansLeagues: leagues.count > 1))
        }
        return result + hoisted + stack.filter { !hoistedIds.contains($0.id) }
    }

    /// College football's slate, one section per conference — the way fans
    /// carve up a Saturday, and the app's shape until the day axis briefly
    /// flattened it (Andy, 2026-09-06, restoring it).
    ///
    /// A cross-conference game lands in both sections. "Other" is a last
    /// resort for games no section can claim: an FCS visitor at an FBS
    /// school stays in the host's conference only, or Week 1's ~48 FCS
    /// matchups would pile up in Other as duplicates.
    ///
    /// The buckets follow the *slate's* divisions, not the registry's
    /// knowledge: FCS is opt-in, so until someone follows an FCS
    /// conference a Big Sky visitor stays in its host's section rather
    /// than spawning a Big Sky one.
    private func conferenceSections(from games: [Game]) -> [GameSection] {
        guard !games.isEmpty else { return [] }
        let divisions = store(for: .collegeFootball).divisions
        var byConference: [ConferenceID?: [Game]] = [:]
        for game in games {
            let claimed = Set([game.home.team.conference, game.away.team.conference]
                .compactMap { conference -> ConferenceID? in
                    guard let conference else { return nil }
                    return Conference.division(for: conference.id, in: conference.league)
                        .map(divisions.contains) == true ? conference : nil
                })
            if claimed.isEmpty {
                byConference[nil, default: []].append(game)
            } else {
                for id in claimed {
                    byConference[id, default: []].append(game)
                }
            }
        }
        // P4 → G5 → Independents → FCS → Other, alphabetical within a tier.
        let ordered = byConference.keys.sorted { lhs, rhs in
            let (lt, rt) = (Conference.tier(for: lhs?.id, in: .collegeFootball),
                            Conference.tier(for: rhs?.id, in: .collegeFootball))
            return lt == rt
                ? Conference.name(for: lhs) < Conference.name(for: rhs)
                : lt < rt
        }
        return ordered.map { id in
            GameSection(id: id.map { GameSection.conferencePrefix + $0.token }
                            ?? (GameSection.otherPrefix + League.collegeFootball.rawValue),
                        title: Conference.name(for: id),
                        games: byConference[id] ?? [],
                        league: .collegeFootball,
                        logoURL: Conference.logoURL(for: id),
                        table: id.map(FollowedTable.conference))
        }
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
