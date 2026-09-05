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
        if token == "top25" {
            self = .top25
        } else if token.hasPrefix("conference-"),
                  // A bare id is a pre-league token and reads as college
                  // football; `ConferenceID.init(token:)` handles both.
                  let id = ConferenceID(token: String(token.dropFirst("conference-".count))) {
            self = .conference(id)
        } else {
            return nil
        }
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
    /// League sections use ids like "league-cfb"; the prefix routes their
    /// expansion state to the defaults-open set in `UIStateStore`.
    static let leaguePrefix = "league-"

    static func id(for league: League) -> String { "\(leaguePrefix)\(league.rawValue)" }

    let id: String
    let title: String
    let games: [Game]
    /// The league this section speaks for — set on league sections, nil on
    /// Following, which spans them all.
    var league: League? = nil
    /// True when this section's games come from more than one league —
    /// only Following ever can. Its rows then tag their league, since the
    /// section's own scope no longer answers for them.
    var spansLeagues = false
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
    private(set) var gamesByDay: [String: [Game]] = [:]
    private(set) var isLoading = false
    private(set) var lastError: String?

    /// Which divisions the slate covers. FBS alone unless someone opts
    /// into FCS (E8 scope (b), Andy 2026-09-01) — the second request is
    /// what the polite-guest rule is spending, so it only exists while
    /// FCS is actually surfaced.
    private(set) var divisions: Set<Conference.Division> = [.fbs]

    /// The day the last window was centred on — what the poll refreshes.
    /// Observed, because `boardGames` is derived from it and a team page
    /// reads that on every render.
    private(set) var windowCenter: Date?
    /// Windows already in flight, so a re-render mid-swipe can't stack
    /// duplicate requests on the same days.
    @ObservationIgnored private var inFlight: Set<String> = []
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    /// How far either side of the shown day each request reaches. Two days
    /// rather than one: ESPN reads `dates=` on the Eastern clock, so a
    /// user far enough west or east sees a local day that straddles two of
    /// ESPN's, and the extra day on each end absorbs that for every time
    /// zone.
    private static let windowRadius = 2
    /// Days kept in memory either side of the centre. Browsing a season
    /// day by day would otherwise accumulate every day it touched.
    private static let cacheRadius = 10

    init(league: League = .collegeFootball,
         client: (any ScoresProviding)? = nil) {
        self.league = league
        self.client = client ?? DataProvider.makeClient(league: league)
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
            startPollingIfNeeded()
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
        startPollingIfNeeded()
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

    /// Whether every day the shown window promises is already in hand.
    private func covers(_ center: Date) -> Bool {
        let calendar = Calendar.current
        return (-1...1).allSatisfy { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: center) else { return false }
            return gamesByDay[DayFormat.id(for: day)] != nil
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
                updated[id] = chronological(bucketed[id] ?? [])
            }
            // Equality guard: @Observable notifies on every set, so an
            // unconditional write would re-render the whole scores tree on
            // each 30s poll tick even when nothing moved.
            if updated != gamesByDay { gamesByDay = updated }
            if lastError != nil { lastError = nil }
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

    private func describe(_ error: Error) -> String {
        if error is DecodingError { return "Couldn't read the scoreboard." }
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
    // 30s auto-poll, only while the scene is active and ≥1 game is live.

    func startPollingIfNeeded() {
        guard pollTask == nil, hasLiveGames else { return }
        Self.logger.info("polling: started (\(self.league.rawValue), groups \(self.groupsLabel))")
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: DataProvider.pollInterval)
                guard !Task.isCancelled, let self else { return }
                guard self.hasLiveGames, let center = self.windowCenter else {
                    Self.logger.info("polling: stopped (no live games)")
                    self.pollTask = nil
                    return
                }
                Self.logger.info("polling: tick (\(self.league.rawValue), groups \(self.groupsLabel))")
                await self.fetchWindow(around: center)
            }
        }
    }

    func stopPolling() {
        if pollTask != nil {
            Self.logger.info("polling: stopped (scene inactive)")
        }
        pollTask?.cancel()
        pollTask = nil
    }

    /// The groups in flight, for the poll log. A union doubles every tick
    /// into two requests, so the Saturday log archive has to say which
    /// ones it was (E8's polling-budget item).
    private var groupsLabel: String {
        divisions.map { String($0.groupId) }.sorted().joined(separator: "+")
    }

    /// The divisions a given set of user choices needs on the slate. FBS
    /// is always there — the app's default promise — and FCS joins only
    /// when someone selected an FCS conference in the filter sheet or
    /// follows one. That "only when asked" is the whole of scope (b), and
    /// it's what keeps the 30s poll at one request for everyone else.
    nonisolated static func divisions(
        filter: ScoreFilter?, followedConferenceIds: Set<ConferenceID>
    ) -> Set<Conference.Division> {
        var needed: Set<Conference.Division> = [.fbs]
        if case .conference(let id) = filter,
           Conference.division(for: id.id, in: id.league) == .fcs {
            needed.insert(.fcs)
        }
        if followedConferenceIds.contains(where: {
            Conference.division(for: $0.id, in: $0.league) == .fcs
        }) {
            needed.insert(.fcs)
        }
        return needed
    }
}
