import Foundation
import Observation
import os

/// The ESPN-style slate filter (Josh Vertucci's feedback, 2026-08-29):
/// narrow the whole screen to one conference — or to ranked matchups.
/// Persisted (Andy, same day, superseding the session-only first cut): the
/// labeled chip and the explanatory empty states mean a saved filter is
/// never a mystery.
///
/// A conference filter is a college-football-shaped question, so it hides
/// the other leagues' sections rather than emptying them.
enum ScoreFilter: Hashable {
    case top25
    /// League-qualified: group id 8 is the SEC in college football and the
    /// AFC in the NFL, so a bare id can't name a slate.
    case conference(ConferenceID)

    /// UserDefaults spelling — "top25" or "conference-8".
    var token: String {
        switch self {
        case .top25: "top25"
        case .conference(let id): "conference-\(id.token)"
        }
    }

    /// Pure parsing, and `UIStateStore.init` reaches it as an unapplied
    /// function reference (`flatMap(ScoreFilter.init(token:))`) — which
    /// is a nonisolated context, so the default MainActor isolation has
    /// to come off.
    nonisolated init?(token: String) {
        guard token == "top25" else {
            // A saved "conference-cfb-8" is deliberately *not* restored.
            // The view-options sheet retired on 2026-09-05 and Top 25 is
            // the only filter with a control, so a restored conference
            // filter would narrow the slate with nothing on screen able to
            // show or clear it — the unlabelled mystery state the July
            // "chips don't filter" objection was about. It degrades to the
            // full slate, which is the honest default.
            return nil
        }
        self = .top25
    }

    /// The league this filter can say anything about — nil for Top 25,
    /// which every league with a poll could answer but only college
    /// football does. A league the filter can't speak for is hidden, not
    /// emptied: "SEC" has no meaning in the NFL's slate.
    var league: League? {
        switch self {
        case .top25: .collegeFootball
        case .conference(let id): id.league
        }
    }

    /// What the sheet and empty state call the selection.
    var label: String {
        switch self {
        case .top25: "Top 25"
        case .conference(let id): Conference.name(for: id)
        }
    }

    /// The header chip's label — the long conference names get their
    /// common short forms so a full chip row still fits the screen.
    var chipLabel: String {
        guard case .conference(let id) = self, id.league == .collegeFootball else { return label }
        switch id.id {
        case 12: return "C-USA"
        case 17: return "MWC"
        case 18: return "Indep."
        default: return label
        }
    }

    /// The same claim rules the sections used before the day axis: any
    /// ranked participant for Top 25, either side's conference for a
    /// conference — so an FCS visitor's game stays visible under its FBS
    /// host's conference.
    func matches(_ game: Game) -> Bool {
        switch self {
        case .top25:
            game.involvesRankedTeam
        case .conference(let id):
            game.home.team.conference == id || game.away.team.conference == id
        }
    }
}

/// One ordered section of the scores screen. A game appears in every section
/// whose promise it satisfies — sections are complete, never deduplicated.
struct GameSection: Identifiable, Hashable {
    static let followingId = "following"
    /// League sections use ids like "league-nfl"; the prefix routes their
    /// expansion state to the defaults-open set in `UIStateStore`.
    static let leaguePrefix = "league-"
    /// Conference sections use ids like "conf-cfb-8" — the `FollowedTable`
    /// token, so a section and the table it belongs to spell themselves
    /// the same way. Same defaults-open routing.
    static let conferencePrefix = "conf-"
    /// A poll section — "poll-cfb": college football's Top 25, which leads
    /// that league's sections whether or not it's followed.
    static let pollPrefix = "poll-"
    /// Games no known conference in the fetched divisions can claim.
    static let otherPrefix = "other-"

    static func id(for league: League) -> String { "\(leaguePrefix)\(league.rawValue)" }

    let id: String
    let title: String
    let games: [Game]
    /// The league this section speaks for — set on every league,
    /// conference and poll section, nil only on Following, which spans
    /// them all.
    var league: League? = nil
    /// The mark beside the title. The one nil section is Following,
    /// which falls back to its star.
    var logoURL: URL? = nil
    /// The followable table this section *is*, where it is one. It is what
    /// hoists the section under Following when that table is followed, and
    /// what keeps a hoisted table from also appearing twice in the stack
    /// below (Andy, 2026-09-06).
    var table: FollowedTable? = nil
    /// True when this section's games come from more than one league —
    /// only Following ever can. Its rows then tag their league, since the
    /// section's own scope no longer answers for them.
    var spansLeagues = false
    /// True for Following and every hoisted table — the sections the Hide
    /// all/Show all control always leaves alone. `table != nil` isn't this:
    /// every conference section carries a `table` whether or not it's
    /// followed, since that's what lets a followed one be matched and
    /// hoisted rather than cloned.
    var isFollowed = false
}

/// One league's slate, held a day at a time.
///
/// The unit of time is the day, not the week (Andy, 2026-09-05): the Scores
/// screen shows every league at once, and a week strip can only be honest
/// about one of them. Each fetch is a five-day ESPN window centred on the
/// day being shown, which covers the selected day and both swipe
/// neighbours in a single request.
@Observable
final class ScoreboardStore {
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "scoreboard")

    private let client: any ScoresProviding

    /// The league this store answers for. One store per league; the Scores
    /// screen stacks them as accordions.
    let league: League

    /// Games by `DayFormat.id`, for every day fetched and still in range.
    private(set) var gamesByDay: [String: [Game]] = [:] {
        didSet { revision &+= 1 }
    }

    /// Bumped on every write to what the Scores sections are built from —
    /// `gamesByDay` and `divisions`. `LeagueScoreboards` keys its sections
    /// memo on it, so a cache hit is a counter compare rather than a deep
    /// compare of every game, and reading it still registers the
    /// observation a later write needs to invalidate the screen.
    private(set) var revision = 0
    private(set) var isLoading = false
    private(set) var lastError: String?

    /// Which divisions the slate covers. FBS alone unless someone opts
    /// into FCS (E8 scope (b), Andy 2026-09-01) — the second request is
    /// what the polite-guest rule is spending, so it only exists while
    /// FCS is actually surfaced.
    private(set) var divisions: Set<Conference.Division> = [.fbs] {
        didSet { revision &+= 1 }
    }

    /// The day the last window was centred on — what the poll refreshes.
    /// Observed, because `boardGames` is derived from it and a team page
    /// reads that on every render.
    private(set) var windowCenter: Date?
    /// Windows already in flight, so a re-render mid-swipe can't stack
    /// duplicate requests on the same days.
    @ObservationIgnored private var inFlight: Set<String> = []
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    /// When the whole window last came back, so a live tick knows whether
    /// it's time to ask for all of it again.
    @ObservationIgnored private var lastWindowFetch: Date?

    /// How often a live poll re-asks for the whole five-day window rather
    /// than just the days with games in play. Kickoff times, a game added
    /// or dropped, a neighbouring day's slate: none of it moves on a
    /// one-second clock, and the window is five requests to the live
    /// days' one (2026-09-26, when the poll went to 1s).
    static let windowRefreshInterval: TimeInterval = 30

    /// How far either side of the shown day each request reaches. Two days
    /// rather than one: ESPN reads `dates=` on the Eastern clock, so a
    /// user far enough west or east sees a local day that straddles two of
    /// ESPN's, and the extra day on each end absorbs that for every time
    /// zone.
    private static let windowRadius = 2
    /// Days kept in memory either side of the centre. Browsing a season
    /// day by day would otherwise accumulate every day it touched.
    private static let cacheRadius = 10

    /// The poll cadence, read once. Injectable so a test can watch the
    /// loop run without waiting out the real 30s.
    @ObservationIgnored private let pollInterval: Duration

    init(league: League = .collegeFootball,
         client: (any ScoresProviding)? = nil,
         pollInterval: Duration = DataProvider.pollInterval) {
        self.league = league
        self.client = client ?? DataProvider.makeClient(league: league)
        self.pollInterval = pollInterval
    }

    /// A game's pre-game line, carried past the payload that drops it.
    ///
    /// ESPN takes `odds` off a scoreboard event once it's final, and maybe
    /// sooner (unprobed for live events as of 2026-09-24). A line doesn't
    /// un-happen at kickoff, and the Tight filter needs to know who was
    /// favored while the game is being played. So a fresh game without a
    /// line keeps the one it had. In memory only: a relaunch mid-game loses
    /// it, and the filter's late-and-close rule doesn't need it anyway.
    static func keepingLines(_ fresh: [Game], from previous: [Game]) -> [Game] {
        guard previous.contains(where: { $0.line != nil }) else { return fresh }
        let lines = Dictionary(previous.compactMap { game in game.line.map { (game.id, $0) } },
                               uniquingKeysWith: { first, _ in first })
        return fresh.map { game in
            guard game.line == nil, let line = lines[game.id] else { return game }
            var game = game
            game.line = line
            return game
        }
    }

    // MARK: - Reading

    /// This league's games on a local calendar day, chronological.
    func games(on day: Date) -> [Game] {
        gamesByDay[DayFormat.id(for: day)] ?? []
    }

    /// Whether a day's slate has landed yet — an empty day and an unfetched
    /// one look identical otherwise, and only one of them should say
    /// "no games".
    func isLoaded(_ day: Date) -> Bool {
        gamesByDay[DayFormat.id(for: day)] != nil
    }

    /// The window's own three days — the fresher-copy source other
    /// screens merge against (a team page's schedule payload carries no
    /// live scores or clock).
    ///
    /// Bounded to the window rather than the whole cache on purpose: the
    /// merge builds a dictionary on every body evaluation, and a season's
    /// worth of browsed days would grow that by an order of magnitude for
    /// games no page is showing.
    var boardGames: [Game] {
        guard let windowCenter else { return [] }
        let calendar = Calendar.current
        return (-1...1).flatMap { offset -> [Game] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: windowCenter)
            else { return [] }
            return gamesByDay[DayFormat.id(for: day)] ?? []
        }
    }

    /// Any live game anywhere in the loaded window. Deliberately not
    /// scoped to the shown day: a followed game in the Following section
    /// has to keep ticking, and a late kick belongs to the previous local
    /// day in some time zones.
    var hasLiveGames: Bool {
        gamesByDay.values.contains { $0.contains(where: \.isLive) }
    }

    func hasLiveGames(on day: Date) -> Bool {
        games(on: day).contains(where: \.isLive)
    }

    // MARK: - Loading

    /// Fetch the window around `day` unless it is already covered.
    ///
    /// `force` is the poll and pull-to-refresh path: same window, fetched
    /// again for fresh scores.
    func load(around day: Date, force: Bool = false) async {
        let center = Calendar.current.startOfDay(for: day)
        windowCenter = center
        guard force || !covers(center) else {
            reschedulePolling()
            return
        }
        let key = DayFormat.id(for: center)
        guard force || !inFlight.contains(key) else { return }
        inFlight.insert(key)
        defer { inFlight.remove(key) }

        isLoading = true
        defer { isLoading = false }
        await fetchWindow(around: center)
        evict(around: center)
        reschedulePolling()
    }

    /// The first day from `start` onward with at least one game, searched
    /// in fortnight-sized windows.
    ///
    /// This is how the app avoids opening on a dead screen: an August
    /// Tuesday, or the day a past season is selected (which lands on the
    /// season's nominal start, weeks before anyone plays). Nil when the
    /// search runs out — a genuinely empty stretch, which the empty state
    /// then says plainly.
    func firstDayWithGames(from start: Date, searchingDays limit: Int = 42) async -> Date? {
        let calendar = Calendar.current
        var cursor = calendar.startOfDay(for: start)
        var searched = 0
        let step = 14
        while searched < limit {
            let end = calendar.date(byAdding: .day, value: step - 1, to: cursor) ?? cursor
            guard let board = try? await client.scoreboard(days: cursor...end,
                                                           divisions: divisions) else { return nil }
            let day = board.games.compactMap(\.date).map(calendar.startOfDay(for:)).min()
            if let day { return day }
            cursor = calendar.date(byAdding: .day, value: step, to: cursor) ?? cursor
            searched += step
        }
        return nil
    }

    /// Widen or narrow the slate's divisions. Async and explicit rather
    /// than a settable property, because the window has to be refetched:
    /// dropping the cache alone would leave the FBS-only slate on screen
    /// with no request in flight to replace it.
    func select(divisions newValue: Set<Conference.Division>) async {
        guard newValue != divisions, !newValue.isEmpty else { return }
        divisions = newValue
        // The narrower slate must never stand in for the wider one, and
        // in-flight requests carry the old divisions — drop both.
        gamesByDay = [:]
        inFlight = []
        guard let windowCenter else { return }
        await load(around: windowCenter, force: true)
    }

    func refresh() async {
        guard let windowCenter else { return }
        await load(around: windowCenter, force: true)
    }

    /// The game page's copy of a game, written into the slate when it is
    /// further along than the one held here.
    ///
    /// The page polls `/summary` and the slate polls `/scoreboard`, and the
    /// summary tends to be the fresher of the two (2026-09-26: 1:56 on the
    /// list against under 1:00 on the page). So the page hands each summary
    /// it loads to the slate, and the next scoreboard tick can't undo it:
    /// `fetchWindow` keeps whichever copy is further along. Only moves a
    /// game forward, and only a game this store already holds.
    func absorb(_ summary: GameSummary, gameId: String) {
        for (day, games) in gamesByDay {
            guard let index = games.firstIndex(where: { $0.id == gameId }) else { continue }
            let held = games[index]
            guard summary.status.isAhead(of: held.status) else { return }
            var updated = games
            updated[index] = held.withLiveState(
                status: summary.status,
                homeScore: summary.home?.score, homeWinner: summary.home?.winner,
                awayScore: summary.away?.score, awayWinner: summary.away?.winner)
            gamesByDay[day] = updated
            return
        }
    }

    /// Whether every day the shown window promises is already in hand.
    private func covers(_ center: Date) -> Bool {
        let calendar = Calendar.current
        return (-1...1).allSatisfy { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: center) else { return false }
            return gamesByDay[DayFormat.id(for: day)] != nil
        }
    }

    /// One live poll: the days with games in play, and the whole window
    /// only every `windowRefreshInterval`.
    ///
    /// A 1s poll that re-asks for five days is five requests a second per
    /// league, four of them for days where nothing is happening, and each
    /// a full slate (Andy, 2026-09-26: "do the today-only change"). So a
    /// tick between window refreshes asks ESPN only for the Eastern days
    /// that hold a game in play or past its kickoff, which is one request
    /// on almost every night, and patches those games in place.
    private func pollTick(around center: Date, now: Date = Date()) async {
        let windowIsFresh = lastWindowFetch.map {
            now.timeIntervalSince($0) < Self.windowRefreshInterval
        } ?? false
        let days = Self.liveDays(in: gamesByDay.values.flatMap { $0 }, now: now)
        guard windowIsFresh, !days.isEmpty else {
            await fetchWindow(around: center)
            return
        }
        await fetchLive(days: days)
    }

    /// One date per Eastern day that holds a game in play, or one past its
    /// kickoff that ESPN hasn't flipped to live yet, up to `kickoffGrace`
    /// past it: a cached game ESPN never flipped out of pre-game would
    /// otherwise name its day on every tick, forever.
    ///
    /// Eastern, because that's the day ESPN's `dates=` token names and the
    /// day its answers are clipped to. One *date* per day, because a span
    /// handed to `scoreboard(days:)` walks forward a local day at a time
    /// and would skip the second Eastern day of a span shorter than 24h.
    static func liveDays(in games: [Game], now: Date) -> [Date] {
        var byToken: [String: Date] = [:]
        for game in games {
            guard let date = game.date else { continue }
            let started: Bool
            switch game.status {
            case .live: started = true
            case .pre: started = date <= now && now.timeIntervalSince(date) < kickoffGrace
            case .final, .other: started = false
            }
            guard started else { continue }
            byToken[DayFormat.espnToken(for: date)] = date
        }
        return byToken.keys.sorted().compactMap { byToken[$0] }
    }

    /// The live days' games, patched into the slate by id. Adds and
    /// removes nothing: a partial answer can't say what isn't on a day,
    /// which is the window refresh's job.
    private func fetchLive(days: [Date]) async {
        do {
            var fresh: [String: Game] = [:]
            for day in days {
                let board = try await client.scoreboard(days: day...day, divisions: divisions)
                for game in board.games where fresh[game.id] == nil { fresh[game.id] = game }
            }
            var updated = gamesByDay
            for (id, games) in gamesByDay {
                updated[id] = Self.patching(games, with: fresh)
            }
            if updated != gamesByDay { gamesByDay = updated }
            if lastError != nil { lastError = nil }
        } catch is CancellationError {
            // Abandoned on purpose, as in `fetchWindow`.
        } catch let error as URLError where error.code == .cancelled {
            // The same thing, as URLSession spells it.
        } catch {
            // Keep last-good games on failure.
            lastError = describe(error)
            Self.logger.error("\(self.league.rawValue) live fetch failed: \(error)")
        }
    }

    /// Held games replaced by their fresh copies, under the same two rules
    /// a window refresh keeps: never backwards, and a line outlives the
    /// payload that drops it.
    static func patching(_ held: [Game], with fresh: [String: Game]) -> [Game] {
        held.map { old in
            guard let latest = fresh[old.id] else { return old }
            let kept = Game.keepingProgress([latest], from: [old])
            return keepingLines(kept, from: [old])[0]
        }
    }

    private func fetchWindow(around center: Date) async {
        let calendar = Calendar.current
        guard let from = calendar.date(byAdding: .day, value: -Self.windowRadius, to: center),
              let to = calendar.date(byAdding: .day, value: Self.windowRadius, to: center)
        else { return }
        do {
            let board = try await client.scoreboard(days: from...to, divisions: divisions)
            var bucketed: [String: [Game]] = [:]
            for game in board.games {
                guard let date = game.date else { continue }
                bucketed[DayFormat.id(for: date), default: []].append(game)
            }
            // Only the inner days are complete: the outermost day on each
            // end is whatever fell inside ESPN's Eastern window, which is
            // a partial answer for most time zones. Recording it as loaded
            // would let a half-slate pass for a whole one.
            var updated = gamesByDay
            for offset in -1...1 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: center) else { continue }
                let id = DayFormat.id(for: day)
                let held = gamesByDay[id] ?? []
                let fresh = Game.keepingProgress(chronological(bucketed[id] ?? []), from: held)
                updated[id] = Self.keepingLines(fresh, from: held)
            }
            // Equality guard: @Observable notifies on every set, so an
            // unconditional write would re-render the whole scores tree on
            // each 30s poll tick even when nothing moved.
            if updated != gamesByDay { gamesByDay = updated }
            lastWindowFetch = Date()
            if lastError != nil { lastError = nil }
        } catch is CancellationError {
            // Abandoned on purpose — the day moved out from under this
            // fetch. Not a failure, and never the refresh banner's copy.
        } catch let error as URLError where error.code == .cancelled {
            // The same thing, as URLSession spells it.
        } catch {
            // Keep last-good games on failure.
            lastError = describe(error)
            Self.logger.error("\(self.league.rawValue) window fetch failed: \(error)")
        }
    }

    private func evict(around center: Date) {
        let calendar = Calendar.current
        let keep = Set((-Self.cacheRadius...Self.cacheRadius).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: center).map { DayFormat.id(for: $0) }
        })
        guard !gamesByDay.keys.allSatisfy(keep.contains) else { return }
        gamesByDay = gamesByDay.filter { keep.contains($0.key) }
    }

    /// What the screen says when a window fails.
    ///
    /// Three failures, three sentences, because they need three different
    /// things from the reader: wait for signal, wait for ESPN, or tell us.
    /// The status code rides along on the third — ESPN's API is
    /// undocumented and can change without notice, and a screenshot
    /// carrying the number is the difference between "they moved the
    /// endpoint" and "your wifi is out".
    private func describe(_ error: Error) -> String {
        if error is DecodingError { return "Couldn't read the scoreboard." }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "No connection."
            case .timedOut:
                return "The scoreboard timed out."
            default:
                return "Couldn't reach the scoreboard."
            }
        }
        if let espn = error as? ESPNError, case .badStatus(let code) = espn {
            return "The scoreboard is unavailable (\(code))."
        }
        return "Couldn't reach the scoreboard."
    }

    private func chronological(_ games: [Game]) -> [Game] {
        games.sorted {
            switch ($0.date, $1.date) {
            case let (a?, b?) where a != b: a < b
            case (nil, _?): false
            case (_?, nil): true
            default: $0.id < $1.id
            }
        }
    }

    // MARK: - Polling
    // Live auto-poll (`DataProvider.pollInterval`), only while the scene is active and a game is live or
    // kicking off. Until the first kickoff the loop sleeps, and a sleep
    // makes no request.

    /// How long past its kickoff a game still showing pre-game keeps the
    /// poll alive. ESPN takes a minute or two to flip a game to `in`, and a
    /// weather delay can hold one at pre-game for an hour or more; three
    /// hours covers both. The cap is for the postponement ESPN never
    /// marks, which would otherwise poll all night.
    nonisolated static let kickoffGrace: TimeInterval = 3 * 60 * 60

    /// When the next scoreboard fetch is due, or nil when nothing on the
    /// slate needs one.
    ///
    /// A live game polls at `interval`. So does a pre-game game within
    /// `interval` of kickoff or up to `kickoffGrace` past it — the game
    /// is about to go live, or already has and ESPN hasn't said so. A
    /// later kickoff is a sleep until then. A `timeTBD` kickoff is a
    /// placeholder time, so it schedules nothing.
    nonisolated static func nextPollDelay(for games: [Game], now: Date,
                                          interval: Duration) -> Duration? {
        if games.contains(where: \.isLive) { return interval }
        let step = interval.timeInterval
        let kickoffs = games.compactMap { game -> Date? in
            guard case .pre = game.status, !game.timeTBD else { return nil }
            return game.date
        }
        if kickoffs.contains(where: { $0 >= now.addingTimeInterval(-kickoffGrace)
                                      && $0 <= now.addingTimeInterval(step) }) {
            return interval
        }
        guard let next = kickoffs.filter({ $0 > now }).min() else { return nil }
        return max(.milliseconds(Int(next.timeIntervalSince(now) * 1000)), interval)
    }

    /// This store's next fetch. Live games anywhere in the cache count (a
    /// followed game on a neighbouring day has to keep ticking); kickoffs
    /// only on the window's own days, because those are what a tick
    /// refetches.
    private func pollDelay(now: Date = Date()) -> Duration? {
        if hasLiveGames { return pollInterval }
        return Self.nextPollDelay(for: boardGames, now: now, interval: pollInterval)
    }

    func startPollingIfNeeded() {
        guard pollTask == nil, let first = pollDelay() else { return }
        logSchedule(first, verb: "started")
        pollTask = Task { [weak self] in
            var delay = first
            while !Task.isCancelled {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }
                guard self.windowCenter != nil, let next = self.pollDelay() else {
                    Self.logger.info("polling: stopped (nothing live or kicking off)")
                    self.pollTask = nil
                    return
                }
                if next > self.pollInterval {
                    // Woke early — the window moved to a quieter slate.
                    self.logSchedule(next, verb: "waiting")
                    delay = next
                    continue
                }
                guard let center = self.windowCenter else { return }
                Self.logger.info("polling: tick (\(self.league.rawValue), groups \(self.groupsLabel))")
                await self.pollTick(around: center)
                guard let after = self.pollDelay() else {
                    Self.logger.info("polling: stopped (nothing live or kicking off)")
                    self.pollTask = nil
                    return
                }
                if after > self.pollInterval { self.logSchedule(after, verb: "waiting") }
                delay = after
            }
        }
    }

    /// Start over against the current window. A loop asleep until an
    /// evening kickoff would otherwise sit through a day with a game live
    /// right now.
    private func reschedulePolling() {
        pollTask?.cancel()
        pollTask = nil
        startPollingIfNeeded()
    }

    func stopPolling() {
        if pollTask != nil {
            Self.logger.info("polling: stopped (scene inactive)")
        }
        pollTask?.cancel()
        pollTask = nil
    }

    private func logSchedule(_ delay: Duration, verb: String) {
        if delay > pollInterval {
            let minutes = Int(delay.timeInterval / 60)
            Self.logger.info("polling: \(verb), waiting for kickoff (\(self.league.rawValue), \(minutes) min)")
        } else {
            Self.logger.info("polling: \(verb) (\(self.league.rawValue), groups \(self.groupsLabel))")
        }
    }

    /// The groups in flight, for the poll log. A union doubles every tick
    /// into two requests, so the Saturday log archive has to say which
    /// ones it was (E8's polling-budget item).
    private var groupsLabel: String {
        divisions.map { String($0.groupId) }.sorted().joined(separator: "+")
    }

    /// The divisions the Scores slate covers: FBS and FCS both, since
    /// every FCS conference has a section of its own (Andy, 2026-09-26).
    /// Until then FCS was opt-in (E8 scope (b), 2026-09-01) and cost its
    /// second request only while someone followed or filtered to it.
    nonisolated static let slateDivisions = Set(Conference.Division.allCases)
}

private extension Duration {
    nonisolated var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
