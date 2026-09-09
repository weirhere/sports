import Foundation

/// The domain-facing contract. If ESPN's API dies, a CFBD-backed client
/// conforms to this same protocol and the rest of the app never notices.
nonisolated protocol ScoresProviding: Sendable {
    /// Which league this client answers for. Every id it returns — team,
    /// conference, event — belongs to this league's namespace.
    var league: League { get }

    /// Fetch the scoreboard. Pass nil for everything to get ESPN's current
    /// week. `year` selects a season (ESPN's `dates=` param, verified live
    /// 2026-07-21); always pair it with an explicit week — a bare year
    /// request dumps the entire season's events.
    ///
    /// `divisions` is one request per division, merged by event id. FCS is
    /// opt-in (E8 scope (b), Andy 2026-09-01), so the app asks for
    /// `[.fbs]` unless someone has selected or followed an FCS conference
    /// — which is what keeps the 30s poll at one request on an ordinary
    /// Saturday.
    ///
    /// Divisions are a college-football concept. The NFL's scoreboard takes
    /// no group filter at all, so an NFL client ignores this and always
    /// makes exactly one request.
    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard

    /// Every game kicking off inside a range of days — the Scores screen's
    /// only fetch since the day strip replaced the week strip (2026-09-05).
    ///
    /// The range is read on ESPN's Eastern clock (`DayFormat.espnToken`),
    /// so the store asks for a window two days wider than the day it is
    /// showing: that absorbs the ET-to-local offset for any time zone, and
    /// it warms the swipe's ±1 neighbours in the same request rather than
    /// spending three.
    ///
    /// The season is implied by the dates, so there is no `year` here —
    /// a 2019 range returns 2019 games (verified live 2026-09-05).
    func scoreboard(days: ClosedRange<Date>,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard
    /// The polls, in the provider's order. `year` selects a season; nil
    /// means the one in progress.
    ///
    /// An explicit past year returns that season's *closing* polls — the
    /// final AP and Coaches votes, and the CFP's selection-day table —
    /// because a finished season has no "current" ranking to serve.
    func rankings(year: Int?) async throws -> [Poll]
    /// One division's conferences and their member teams, for browse,
    /// search, and onboarding. Alphabetical by conference — the browse
    /// screen re-sorts by tier itself.
    func conferences(in division: Conference.Division) async throws -> [ConferenceTeams]
    /// All FBS conferences' standings in one call, each in the provider's
    /// standings order (ESPN's encodes tiebreakers). Empty conferences are
    /// kept — offseason responses can have zero entries and the page needs
    /// to say "Standings TBA", not error.
    /// Conference standings tables. `year` selects a season; nil means the
    /// current one. An explicit year returns exactly that season's tables —
    /// membership included (realignment years read correctly).
    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings]
    /// The league's divisional tables — the NFL's eight, AFC East through
    /// NFC West, each carrying the conference it hangs under. A second
    /// request, made only when a page is actually showing divisions.
    /// `year` selects a season; nil means the current one.
    func divisionStandings(year: Int?) async throws -> [ConferenceStandings]
    /// One team's schedule. `year` selects a season; nil means the current
    /// one, with the provider free to fall back to last season while the
    /// next is unpublished. An explicit year returns exactly that season —
    /// a user who picked 2019 must never silently get 2018.
    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule
    /// One conference's full-season slate — every game with a side in the
    /// conference, postseason included where the provider carries it.
    /// `year` selects a season; nil means the current one. An explicit
    /// year returns exactly that season.
    func conferenceGames(conferenceId: Int, year: Int?) async throws -> [Game]
    /// A whole division's season — every FBS game, which is what makes the
    /// Top 25's Games tab a filter over one slate rather than 25 schedule
    /// fetches. `year` selects a season; nil means the current one.
    func seasonGames(year: Int?) async throws -> [Game]
    func gameSummary(eventId: String) async throws -> GameSummary
}

nonisolated extension ScoresProviding {
    /// A backend with no division-wide request answers with the division
    /// as a conference — ESPN reads group 80 that way, and a provider that
    /// doesn't returns nothing rather than a wrong slate.
    func seasonGames(year: Int?) async throws -> [Game] {
        try await conferenceGames(conferenceId: Conference.fbsGroupId, year: year)
    }

    /// A league that nests nothing under its conferences has no divisional
    /// tables, and neither does a backend that can't ask for them. Empty
    /// rather than an error: the page hides the scope, it doesn't fail.
    func divisionStandings(year: Int?) async throws -> [ConferenceStandings] { [] }

    /// The season in progress.
    func rankings() async throws -> [Poll] {
        try await rankings(year: nil)
    }

    /// The current season (with the unpublished-season fallback).
    func teamSchedule(teamId: String) async throws -> TeamSchedule {
        try await teamSchedule(teamId: teamId, year: nil)
    }

    // The FBS-only forms. Every caller that predates E8 keeps them, so
    // "did this change what we fetch?" has one answer for the whole app:
    // no, unless a call site names another division.

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?) async throws -> Scoreboard {
        try await scoreboard(weekValue: weekValue, seasonType: seasonType,
                             year: year, divisions: [.fbs])
    }

    func scoreboard(days: ClosedRange<Date>) async throws -> Scoreboard {
        try await scoreboard(days: days, divisions: [.fbs])
    }

    /// One day's slate, on its own terms.
    func scoreboard(day: Date) async throws -> Scoreboard {
        try await scoreboard(days: day...day, divisions: [.fbs])
    }

    func conferenceStandings(year: Int?) async throws -> [ConferenceStandings] {
        try await conferenceStandings(year: year, division: .fbs)
    }

    /// The current season's standings.
    func conferenceStandings() async throws -> [ConferenceStandings] {
        try await conferenceStandings(year: nil, division: .fbs)
    }

}

nonisolated enum ESPNError: Error {
    case invalidURL
    case badStatus(Int)
}

/// Talks to ESPN's unofficial API. An actor so fetching and decoding stay
/// off the main thread (the project defaults types to MainActor).
actor ESPNClient: ScoresProviding {
    /// The sport path segment is the only thing separating the two leagues'
    /// endpoints — verified live 2026-09-05: scoreboard, standings, summary
    /// and team-schedule responses are shape-identical.
    nonisolated let league: League

    private let base: String
    // Conference membership lives on the standings API (apis/v2, not
    // site/v2); the /teams endpoint carries no conference data.
    private let standingsBase: String

    // Historical rankings live on the core API, which is ref-shaped and
    // season-scoped where the site API is latest-only.
    private let coreBase: String

    private let session: URLSession
    private let decoder = JSONDecoder()

    /// The `/teams` directory, resolved once per client (see `teamDirectory`).
    private var teamsById: [String: Team]?

    /// Stadium capacities by venue id, asked once each per client — a
    /// nil value is a resolved "no number for this one". Unlike the team
    /// directory, this caches failures too: the caller is the game
    /// detail's 30s poll loop, so an un-cached miss would re-ask twice a
    /// minute for as long as the page is open, and the cost of giving up
    /// is one absent line on one card.
    private var venueCapacities: [String: Int?] = [:]

    init(league: League = .collegeFootball, session: URLSession = .shared) {
        self.league = league
        self.session = session
        // The sport segment sits above the league's own in every ESPN
        // path — `football/nfl`, `basketball/nba`, `hockey/nhl` — and it
        // was a literal here until the app covered more than one sport.
        let sport = league.sportSegment
        self.base = "https://site.api.espn.com/apis/site/v2/sports/\(sport)/\(league.pathSegment)"
        self.standingsBase = "https://site.api.espn.com/apis/v2/sports/\(sport)/\(league.pathSegment)"
        self.coreBase =
            "https://sports.core.api.espn.com/v2/sports/\(sport)/leagues/\(league.pathSegment)"
    }

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        var items: [URLQueryItem] = []
        if let weekValue {
            items.append(URLQueryItem(name: "week", value: String(weekValue)))
        }
        if let seasonType {
            items.append(URLQueryItem(name: "seasontype", value: String(seasonType)))
        }
        if let year {
            items.append(URLQueryItem(name: "dates", value: String(league.espnSeason(for: year))))
        }
        return try await scoreboard(query: items, divisions: divisions)
    }

    func scoreboard(days: ClosedRange<Date>,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        // `dates=20260904-20260908` — verified live 2026-09-05 for both
        // leagues, past seasons included (a 2019 range returns 2019 games).
        // What it does *not* return is the season calendar or an honest
        // `season.year`: both come back empty or pinned to the current
        // season, which is why the day strip's bounds come from the plain
        // launch request instead.
        let from = DayFormat.espnToken(for: days.lowerBound)
        let to = DayFormat.espnToken(for: days.upperBound)
        let value = from == to ? from : "\(from)-\(to)"
        return try await scoreboard(query: [URLQueryItem(name: "dates", value: value)],
                                    divisions: divisions)
    }

    /// The shared half of every scoreboard request: one call per division,
    /// merged by event id.
    private func scoreboard(query: [URLQueryItem],
                            divisions: Set<Conference.Division>) async throws -> Scoreboard {
        // Deterministic order, and FBS first when it's in the set: it is
        // the canonical payload for anything both divisions carry. FBS and
        // FCS are college football's own axis — every other league asks
        // once with no group filter, because there is nothing to filter by
        // and (for the NBA at least) ESPN ignores `groups=` outright.
        let ordered = league.hasCollegeDivisions
            ? divisions.sorted { $0.groupId < $1.groupId }.map { $0 }
            : [Conference.Division?.none]
        guard let primary = ordered.first else {
            throw ESPNError.invalidURL
        }

        func board(for division: Conference.Division?) async throws -> Scoreboard {
            // 400, not the 300 the week form used: a five-day college
            // football window in September runs ~80 events, but a bowl
            // fortnight or a wide range can carry far more, and a silent
            // truncation would look like missing games.
            var items = [URLQueryItem(name: "limit", value: "400")]
            if let division {
                items.insert(URLQueryItem(name: "groups", value: String(division.groupId)), at: 0)
            }
            items += query
            let dto: ScoreboardDTO = try await fetch(path: "/scoreboard", query: items)
            return ESPNMapper.scoreboard(from: dto, league: league)
        }

        guard ordered.count > 1 else { return try await board(for: primary) }

        // Both halves in flight at once — a union must not cost two round
        // trips end to end.
        async let primaryBoard = board(for: primary)
        let secondaries = ordered.dropFirst()
        async let secondaryBoards = withTaskGroup(of: Scoreboard?.self) { group in
            for division in secondaries {
                group.addTask { try? await board(for: division) }
            }
            return await group.reduce(into: [Scoreboard]()) { boards, board in
                if let board { boards.append(board) }
            }
        }
        // The primary's failure is the request's failure; a secondary's is
        // not. Losing the FCS half should narrow the slate, never blank a
        // Saturday that group 80 answered fine.
        let base = try await primaryBoard
        return ESPNMapper.merged(base, with: await secondaryBoards)
    }

    func conferenceGames(conferenceId: Int, year: Int?) async throws -> [Game] {
        // The season's own window, not `dates={year}`: a bare year is the
        // *calendar* year, which smuggles last season's January bowls into
        // this season's slate (verified live 2026-09-05 — `dates=2026`
        // opens with ten `season.year: 2025` postseason events). A range
        // returns exactly the season asked for, types 2 and 3, each event
        // stamped with its own week. A conference's season runs ~100–200
        // events, so one 400-cap request still covers it.
        let items = [
            URLQueryItem(name: "groups", value: String(conferenceId)),
            URLQueryItem(name: "limit", value: "400"),
            URLQueryItem(name: "dates", value: Self.datesToken(
                for: SeasonSpan.days(of: league, year: year ?? SeasonYear.year(for: league)))),
        ]
        let dto: ScoreboardDTO = try await fetch(path: "/scoreboard", query: items)
        return ESPNMapper.scoreboard(from: dto, league: league).games
    }

    /// A whole division's season, for the Top 25's Games tab — which is a
    /// filter over one slate rather than 25 schedule fetches.
    ///
    /// Two requests, because ESPN's scoreboard truncates at its `limit`
    /// and a full FBS season is ~950 events (measured live 2026-09-05:
    /// 605 through October, 350 after). The split lands on November 1, so
    /// each half comes back whole; the halves don't overlap, and the merge
    /// dedupes by event id anyway. Either half failing fails the request —
    /// half a season passing for a whole one is the one outcome worse than
    /// an error.
    func seasonGames(year: Int?) async throws -> [Game] {
        let season = year ?? SeasonYear.year(for: league)
        let windows = Self.seasonWindows(of: league, year: season)
        var byId: [String: Game] = [:]
        var order: [String] = []
        for games in try await withThrowingTaskGroup(of: [Game].self, returning: [[Game]].self, body: { group in
            for window in windows {
                group.addTask { try await self.seasonBoard(days: window) }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }) {
            for game in games where byId[game.id] == nil {
                byId[game.id] = game
                order.append(game.id)
            }
        }
        return order.compactMap { byId[$0] }
    }

    /// One window of a season. `limit=900` rather than the shared path's
    /// 400: a three-month range runs ~600 events, and a silent truncation
    /// would look like missing games.
    private func seasonBoard(days: ClosedRange<Date>) async throws -> [Game] {
        var items = [URLQueryItem(name: "limit", value: "900"),
                     URLQueryItem(name: "dates", value: Self.datesToken(for: days))]
        // Only college football's scoreboard takes a group filter.
        if league.hasCollegeDivisions {
            items.insert(URLQueryItem(name: "groups", value: String(Conference.fbsGroupId)), at: 0)
        }
        let dto: ScoreboardDTO = try await fetch(path: "/scoreboard", query: items)
        return ESPNMapper.scoreboard(from: dto, league: league).games
    }

    /// The season split into windows small enough to come back whole,
    /// on November 1 — before it the schedule is dense (~600 events),
    /// after it the postseason thins out.
    static func seasonWindows(of league: League, year: Int,
                              calendar: Calendar = .current) -> [ClosedRange<Date>] {
        let span = SeasonSpan.days(of: league, year: year, calendar: calendar)
        guard let split = calendar.date(from: DateComponents(year: year, month: 11, day: 1)),
              span.contains(split),
              let beforeSplit = calendar.date(byAdding: .day, value: -1, to: split),
              beforeSplit >= span.lowerBound
        else { return [span] }
        return [span.lowerBound...beforeSplit, split...span.upperBound]
    }

    /// `20260801-20270131` — ESPN reads both ends on the Eastern clock.
    private static func datesToken(for days: ClosedRange<Date>) -> String {
        let from = DayFormat.espnToken(for: days.lowerBound)
        let to = DayFormat.espnToken(for: days.upperBound)
        return from == to ? from : "\(from)-\(to)"
    }

    func rankings(year: Int?) async throws -> [Poll] {
        // `/nfl/rankings` is a 404 — the NFL has no poll and never will.
        // An empty list is the honest answer; callers hide the section.
        guard league == .collegeFootball else { return [] }
        // The site endpoint is latest-only: it ignores `season`, `week`,
        // `year` and `dates` alike and always answers with the newest poll
        // it has (probed live 2026-09-05). So it can speak for the season
        // in progress and nothing else — a past season goes to the core
        // API instead.
        guard let year, year != SeasonYear.year(for: league) else {
            let dto: RankingsResponseDTO = try await fetch(path: "/rankings", query: [])
            return ESPNMapper.polls(from: dto)
        }
        return try await finalRankings(year: year)
    }

    /// A finished season's closing polls, from ESPN's core API — the one
    /// surface that carries a season/week axis for rankings.
    ///
    /// Two requests' worth of shape, not one: the AP and Coaches polls end
    /// in the postseason (`types/3/weeks/1`, headlined "Final Rankings"),
    /// while the CFP's last table is selection day's — the final week of
    /// the regular season, since `types/3/.../rankings/21` is a 404. All
    /// three resolve for every season back to the 2014 floor (verified
    /// live 2026-09-05).
    ///
    /// A poll that doesn't come back is dropped rather than failing the
    /// season; all three missing is the season failing.
    private func finalRankings(year: Int) async throws -> [Poll] {
        async let directoryFetch = teamDirectory()
        async let ap = coreRanking(year: year, seasonType: 3, week: 1, rankingId: 1)
        async let coaches = coreRanking(year: year, seasonType: 3, week: 1, rankingId: 2)
        async let cfp = finalCFPRanking(year: year)

        let directory = await directoryFetch
        let dtos = await [ap, coaches, cfp].compactMap { $0 }
        // An empty directory would name none of the 25, so it is the same
        // failure as no poll at all — better a retry than a table of
        // dashes.
        guard !dtos.isEmpty, !directory.isEmpty else { throw ESPNError.badStatus(404) }
        return dtos.map { ESPNMapper.poll(from: $0, teams: directory) }
    }

    /// The CFP's closing table, whose week is the season's last regular
    /// one — 15 or 16 depending on the year, so it's read off the weeks
    /// collection rather than assumed.
    private func finalCFPRanking(year: Int) async -> CoreRankingDTO? {
        let weeks: CoreCollectionDTO? = try? await fetch(
            base: coreBase, path: "/seasons/\(year)/types/2/weeks",
            query: [URLQueryItem(name: "limit", value: "1")]
        )
        guard let last = weeks?.count, last > 0 else { return nil }
        return await coreRanking(year: year, seasonType: 2, week: last, rankingId: 21)
    }

    private func coreRanking(year: Int, seasonType: Int, week: Int,
                             rankingId: Int) async -> CoreRankingDTO? {
        try? await fetch(
            base: coreBase,
            path: "/seasons/\(year)/types/\(seasonType)/weeks/\(week)/rankings/\(rankingId)",
            query: []
        )
    }

    /// Every team ESPN knows, by id — the core API's ranks carry their
    /// team as a `$ref` and nothing else, so the names and marks have to
    /// come from somewhere. One `/teams` request answers for all 760 of
    /// them (FCS included), and it's cached for the client's life: team
    /// names don't change inside a session, and flipping through seasons
    /// then costs one request per poll.
    private func teamDirectory() async -> [String: Team] {
        if let teamsById { return teamsById }
        let dto: TeamsResponseDTO? = try? await fetch(
            path: "/teams", query: [URLQueryItem(name: "limit", value: "1000")]
        )
        let teams = ESPNMapper.teamsById(from: dto, league: league)
        // Never cache a miss — a flaky request must not poison the season
        // picker for the rest of the session.
        if !teams.isEmpty { teamsById = teams }
        return teams
    }

    func conferences(in division: Conference.Division) async throws -> [ConferenceTeams] {
        // A pro league's standings response is already the whole league
        // (AFC and NFC, East and West), so it takes no group filter — only
        // college football splits into FBS and FCS.
        let query = league.hasCollegeDivisions
            ? [URLQueryItem(name: "group", value: String(division.groupId))]
            : []
        let dto: StandingsResponseDTO = try await fetch(
            base: standingsBase, path: "/standings", query: query
        )
        return ESPNMapper.conferences(from: dto, league: league)
    }

    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings] {
        var query = league.hasCollegeDivisions
            ? [URLQueryItem(name: "group", value: String(division.groupId))]
            : []
        // Verified live 2026-08-25: `season` scopes records AND membership,
        // so realignment years read correctly.
        if let year {
            query.append(URLQueryItem(name: "season", value: String(league.espnSeason(for: year))))
        }
        let dto: StandingsResponseDTO = try await fetch(
            base: standingsBase, path: "/standings", query: query
        )
        return ESPNMapper.conferenceStandings(from: dto, league: league)
    }

    /// The eight NFL divisions, from the same endpoint at `level=3` — the
    /// depth the ids in `Conference` were read off in the first place. The
    /// shipped request stops at the conferences (AFC 16, NFC 16), so a
    /// division table can only come from a second call, and it's made only
    /// when a page is actually showing divisions.
    ///
    /// College football asks for nothing: its conferences nest only in a
    /// divisional era, and `conferenceStandings` already returns those
    /// divisions from the shipped response.
    func divisionStandings(year: Int?) async throws -> [ConferenceStandings] {
        // Any league whose registry nests divisions under conferences —
        // the NFL's eight, the NBA's six, the NHL's four.
        guard !league.hasCollegeDivisions,
              Conference.leagueWideId(in: league) != nil else { return [] }
        var query = [URLQueryItem(name: "level", value: "3")]
        if let year {
            query.append(URLQueryItem(name: "season", value: String(league.espnSeason(for: year))))
        }
        let dto: StandingsResponseDTO = try await fetch(
            base: standingsBase, path: "/standings", query: query
        )
        return ESPNMapper.divisionStandings(from: dto, league: league)
    }

    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        if let year {
            return try await fetchSchedule(teamId: teamId, year: year)
        }
        let current = SeasonYear.year(for: league)
        let schedule = try await fetchSchedule(teamId: teamId, year: current)
        guard schedule.games.isEmpty else { return schedule }
        // Next season's schedule isn't published yet; show last season instead.
        return try await fetchSchedule(teamId: teamId, year: current - 1)
    }

    private func fetchSchedule(teamId: String, year: Int) async throws -> TeamSchedule {
        // A bare /schedule request inherits ESPN's "current" season type, which
        // is the empty preseason from February until kickoff — so ask for the
        // season explicitly. Each phase is its own request (verified live
        // 2026-09-06: `seasontype=1` returns the NFL's three preseason games
        // with `seasonType.type: 1`).
        //
        // The regular season is the one that must succeed; the other two
        // degrade to no games rather than failing the page — a team with no
        // preseason and no bowl is the normal case, not an error.
        let path = "/teams/\(teamId)/schedule"
        func query(_ seasonType: Int) -> [URLQueryItem] {
            [URLQueryItem(name: "season", value: String(league.espnSeason(for: year))),
             URLQueryItem(name: "seasontype", value: String(seasonType))]
        }
        async let preseasonFetch: ScheduleResponseDTO? = try? fetch(path: path, query: query(1))
        async let regularFetch: ScheduleResponseDTO = fetch(path: path, query: query(2))
        async let postseasonFetch: ScheduleResponseDTO? = try? fetch(path: path, query: query(3))
        let regular = try await regularFetch
        let extras = (await preseasonFetch?.events?.elements ?? [])
            + (await postseasonFetch?.events?.elements ?? [])
        return ESPNMapper.teamSchedule(from: regular, extraEvents: extras, league: league)
    }

    func gameSummary(eventId: String) async throws -> GameSummary {
        let dto: SummaryResponseDTO = try await fetch(
            path: "/summary", query: [URLQueryItem(name: "event", value: eventId)]
        )
        var summary = ESPNMapper.gameSummary(from: dto, league: league)
        // The site API's venue object stops at name, address, surface —
        // capacity only exists on the core API's venue resource, so the
        // "how full was it" half of the info card costs one extra
        // request, cached per venue and never blocking the summary.
        if summary.venueCapacity == nil, let venueId = dto.gameInfo?.venue?.id {
            summary.venueCapacity = await venueCapacity(venueId: venueId)
        }
        return summary
    }

    /// One core-API venue lookup, memoized. A miss is a quiet nil: the
    /// capacity line degrades away exactly like every other optional
    /// field on this card.
    private func venueCapacity(venueId: String) async -> Int? {
        if let cached = venueCapacities[venueId] { return cached }
        let dto: CoreVenueDTO? = try? await fetch(
            base: coreBase, path: "/venues/\(venueId)", query: []
        )
        venueCapacities[venueId] = dto?.capacity
        return dto?.capacity
    }

    private func fetch<T: Decodable>(path: String, query: [URLQueryItem]) async throws -> T {
        try await fetch(base: base, path: path, query: query)
    }

    private func fetch<T: Decodable>(base: String, path: String, query: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(string: base + path) else {
            throw ESPNError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else { throw ESPNError.invalidURL }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ESPNError.badStatus(http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - DTO → domain mapping

nonisolated enum ESPNMapper {
    static func scoreboard(from dto: ScoreboardDTO,
                           league: League = .collegeFootball) -> Scoreboard {
        Scoreboard(
            seasonYear: dto.season?.year,
            seasonType: dto.season?.type,
            currentWeekNumber: dto.week?.number,
            weeks: weekSlots(from: dto),
            games: (dto.events?.elements ?? []).compactMap { game(from: $0, league: league) }
        )
    }

    /// Union two or more division payloads into one week.
    ///
    /// The overlap is real duplication at the source, not a modelling
    /// choice: every FCS-at-FBS game ships in *both* group 80 and group
    /// 81 (37 of them in Week 2 2026), so the merge dedupes **by event
    /// id** and the base payload's copy wins. That keeps the app's
    /// "sections are complete, never deduplicated" rule where it belongs —
    /// about sections, not about the same event arriving twice.
    ///
    /// Week metadata comes from the base. ESPN serves group 81 the
    /// byte-identical calendar (probed 2026-09-01), so there is nothing
    /// to reconcile; if that ever stops being true, the base division is
    /// the one the user's slate is shaped around.
    static func merged(_ base: Scoreboard, with others: [Scoreboard]) -> Scoreboard {
        guard !others.isEmpty else { return base }
        var games = base.games
        var seen = Set(games.map(\.id))
        for board in others {
            for game in board.games where !seen.contains(game.id) {
                seen.insert(game.id)
                games.append(game)
            }
        }
        return Scoreboard(
            seasonYear: base.seasonYear,
            seasonType: base.seasonType,
            currentWeekNumber: base.currentWeekNumber,
            weeks: base.weeks.isEmpty ? (others.first { !$0.weeks.isEmpty }?.weeks ?? []) : base.weeks,
            games: games
        )
    }

    static func weekSlots(from dto: ScoreboardDTO) -> [WeekSlot] {
        let periods = dto.leagues?.elements.first?.calendar?.elements ?? []
        return periods.flatMap { period -> [WeekSlot] in
            guard let type = period.value?.value, type == 2 || type == 3 else { return [] }
            return (period.entries ?? []).compactMap { entry in
                guard let value = entry.value?.value else { return nil }
                let label = entry.label ?? entry.alternateLabel ?? "Week \(value)"
                return WeekSlot(
                    label: label,
                    shortLabel: entry.alternateLabel ?? label,
                    seasonType: type,
                    value: value,
                    startDate: ESPNDate.parse(entry.startDate),
                    endDate: ESPNDate.parse(entry.endDate)
                )
            }
        }
    }

    static func game(from event: EventDTO, league: League = .collegeFootball) -> Game? {
        guard let id = event.id,
              let competition = event.competitions?.first,
              let competitors = competition.competitors,
              let homeDTO = competitors.first(where: { $0.homeAway == "home" }),
              let awayDTO = competitors.first(where: { $0.homeAway == "away" }),
              let home = competitor(from: homeDTO, league: league),
              let away = competitor(from: awayDTO, league: league)
        else { return nil }

        return Game(
            id: id,
            date: ESPNDate.parse(event.date),
            timeTBD: competition.timeValid == false,
            name: event.name,
            shortName: event.shortName,
            weekNumber: event.week?.number,
            seasonType: event.season?.type,
            headline: competition.notes?.first?.headline,
            status: status(from: event.status, situation: competition.situation),
            home: home,
            away: away,
            // ESPN sends "" (not nil) before a broadcast is announced —
            // normalized here so every `if let broadcast` surface stays
            // honest instead of rendering an empty TV line.
            broadcast: nonEmpty(competition.broadcast)
                ?? nonEmpty(competition.broadcasts?.first?.names?.first)
        )
    }

    private static func nonEmpty(_ string: String?) -> String? {
        guard let string, !string.isEmpty else { return nil }
        return string
    }

    static func status(from dto: StatusDTO?, situation: SituationDTO?) -> GameStatus {
        let detail = dto?.type?.shortDetail ?? dto?.type?.detail
        switch dto?.type?.state {
        case "pre":
            return .pre(detail: detail)
        case "in":
            return .live(
                displayClock: dto?.displayClock,
                period: dto?.period,
                detail: detail,
                phase: livePhase(from: dto?.type?.name),
                possessionTeamId: situation?.possession
            )
        case "post" where dto?.type?.completed == true:
            return .final(detail: detail)
        default:
            return .other(detail: detail)
        }
    }

    /// ESPN's halftime and end-of-quarter arrive as `state: "in"` with the
    /// clock at 0:00 — only the status type name says the clock isn't
    /// running (observed live 2026-08-29: `STATUS_HALFTIME`, period 2,
    /// displayClock "0:00").
    static func livePhase(from statusName: String?) -> LivePhase {
        switch statusName {
        case "STATUS_HALFTIME": .halftime
        case "STATUS_END_PERIOD": .endOfPeriod
        default: .playing
        }
    }

    static func competitor(from dto: CompetitorDTO,
                           league: League = .collegeFootball) -> Competitor? {
        guard let team = team(from: dto.team, league: league) else { return nil }
        let rank = dto.curatedRank?.current?.value
        return Competitor(
            team: team,
            score: dto.score?.value,
            record: dto.records?.first(where: { $0.type == "total" || $0.name == "overall" })?.summary,
            rank: rank.flatMap { (1...25).contains($0) ? $0 : nil },
            isHome: dto.homeAway == "home",
            winner: dto.winner
        )
    }

    static func team(from dto: TeamDTO?, league: League = .collegeFootball) -> Team? {
        guard let dto, let id = dto.id else { return nil }
        let logo = dto.logo ?? dto.logos?.first?.href
        return Team(
            id: id,
            location: dto.location ?? dto.displayName ?? dto.name ?? "—",
            name: dto.name ?? dto.nickname,
            abbreviation: dto.abbreviation,
            displayName: dto.displayName,
            shortDisplayName: dto.shortDisplayName,
            logoURL: logo.flatMap(URL.init(string:)),
            // The NFL scoreboard ships no conferenceId, so the registry
            // supplies the division; college football carries its own.
            conferenceId: dto.conferenceId?.value
                ?? Conference.division(forTeamId: id, in: league),
            league: league
        )
    }

    /// Flattens ESPN's standings tree to the groups that actually carry a
    /// table, each paired with the conference it hangs under.
    ///
    /// A conference with entries is one group. A conference with none but
    /// with children is *divisional* — the 2019 AAC's East and West, the
    /// Sun Belt's to this day, or any `level=3` request — and yields its
    /// divisions, because standings order is per-division and folding them
    /// into one table would invent a cross-division ranking out of records,
    /// which is exactly the tiebreaker guesswork the standings contract
    /// forbids. A group with neither is kept, so an empty conference can
    /// still say "Standings TBA".
    static func standingsGroups(
        in dto: StandingsResponseDTO
    ) -> [(group: StandingsGroupDTO, parentId: Int?)] {
        (dto.children ?? []).flatMap { group -> [(StandingsGroupDTO, Int?)] in
            let entries = group.standings?.entries?.elements ?? []
            let children = group.children ?? []
            guard entries.isEmpty, !children.isEmpty else { return [(group, nil)] }
            return children.map { ($0, group.id?.value) }
        }
    }

    /// Every group in the tree that carries a table, paired with the id of
    /// the group it hangs under. Where `standingsGroups` chooses one depth
    /// or the other, this keeps them all — the reading a `level=3` response
    /// needs, since ESPN can ship the conferences' own tables alongside
    /// their divisions'.
    static func allStandingsGroups(
        in dto: StandingsResponseDTO
    ) -> [(group: StandingsGroupDTO, parentId: Int?)] {
        func walk(_ groups: [StandingsGroupDTO],
                  parentId: Int?) -> [(group: StandingsGroupDTO, parentId: Int?)] {
            groups.flatMap { group -> [(group: StandingsGroupDTO, parentId: Int?)] in
                let entries = group.standings?.entries?.elements ?? []
                let mine: [(group: StandingsGroupDTO, parentId: Int?)] =
                    entries.isEmpty ? [] : [(group: group, parentId: parentId)]
                return mine + walk(group.children ?? [], parentId: group.id?.value)
            }
        }
        return walk(dto.children ?? [], parentId: nil)
    }

    /// The browse roster takes the opposite view of a divisional conference
    /// from the standings above: membership has no order to lose, so the
    /// divisions fold back into their conference and the Sun Belt is one
    /// 14-team list rather than two halves nobody asked for.
    ///
    /// This is what was hiding the whole Sun Belt from browse, search and
    /// onboarding (BACKLOG E7): the conference ships zero entries of its
    /// own and hangs all 14 teams under East and West, so the mapper's
    /// `guard !teams.isEmpty` dropped it outright.
    static func conferences(from dto: StandingsResponseDTO,
                            league: League = .collegeFootball) -> [ConferenceTeams] {
        (dto.children ?? []).compactMap { group in
            let id = group.id?.value
            // Prefer our short names ("SEC") over ESPN's long ones
            // ("Southeastern Conference") when the id is known.
            let name = Conference.tier(for: id, in: league) == .other
                ? (group.shortName ?? group.name ?? "Conference")
                : Conference.name(for: id, in: league)
            // The conference's own entries when it has them, its divisions'
            // otherwise.
            let ownEntries = group.standings?.entries?.elements ?? []
            let entries = ownEntries.isEmpty
                ? (group.children ?? []).flatMap { $0.standings?.entries?.elements ?? [] }
                : ownEntries
            let teams = entries.compactMap { entry -> Team? in
                guard let mapped = team(from: entry.team, league: league) else { return nil }
                return Team(
                    id: mapped.id, location: mapped.location, name: mapped.name,
                    abbreviation: mapped.abbreviation, displayName: mapped.displayName,
                    shortDisplayName: mapped.shortDisplayName, logoURL: mapped.logoURL,
                    conferenceId: id, league: league
                )
            }
            guard !teams.isEmpty else { return nil }
            return ConferenceTeams(id: id, name: name,
                                   teams: teams.sorted { $0.location < $1.location },
                                   league: league)
        }
        .sorted { lhs, rhs in
            let (lt, rt) = (Conference.tier(for: lhs.id, in: league),
                            Conference.tier(for: rhs.id, in: league))
            return lt == rt ? lhs.name < rhs.name : lt < rt
        }
    }

    /// Standings sibling of `conferences(from:)` over the same response.
    /// Differences are the contract: entry order is ESPN's standings order
    /// — `playoffSeed` when the conference is fully seeded (past-season
    /// payloads arrive sorted by overall record, which is not the
    /// standings), payload order otherwise — and empty conferences are
    /// kept so the page can render "Standings TBA". Never sorted from
    /// records here: tiebreakers aren't derivable.
    static func conferenceStandings(from dto: StandingsResponseDTO,
                                    league: League = .collegeFootball) -> [ConferenceStandings] {
        standingsGroups(in: dto)
            .map { standings(from: $0.group, parentId: $0.parentId, league: league) }
            .sorted { lhs, rhs in
                let (lt, rt) = (Conference.tier(for: lhs.id, in: league),
                                Conference.tier(for: rhs.id, in: league))
                return lt == rt ? lhs.name < rhs.name : lt < rt
            }
    }

    /// The divisional tables out of a `level=3` response — the NFL's eight
    /// (Andy, 2026-09-06). Deliberately not `standingsGroups`: that one
    /// collapses a parent *or* its children by whether the parent carries
    /// entries, and a deeper response can legitimately carry both. This
    /// walks the whole tree and keeps the groups the registry knows as
    /// divisions, so it reads a response the same way whether or not the
    /// conferences above them ship tables of their own.
    ///
    /// Parentage comes from our own registry first — those ids are
    /// hardcoded because the NFL scoreboard ships no group at all, so they
    /// are the surer of the two — and from the payload's nesting when the
    /// registry has never seen the id, so a realignment costs a page its
    /// division's *name*, never the division. A group with no parent at
    /// either source is dropped: that one is a conference, not a division.
    static func divisionStandings(from dto: StandingsResponseDTO,
                                  league: League = .collegeFootball) -> [ConferenceStandings] {
        allStandingsGroups(in: dto).compactMap { group, payloadParent in
            let id = group.id?.value
            guard let parent = Conference.parent(of: id, in: league) ?? payloadParent,
                  parent != id else { return nil }
            return standings(from: group, parentId: parent, league: league)
        }
        .sorted { $0.name < $1.name }
    }

    /// One group's table. Shared so a conference, a division, and a
    /// `level=3` response all read their entries the same way.
    private static func standings(from group: StandingsGroupDTO, parentId: Int?,
                                  league: League) -> ConferenceStandings {
        let id = group.id?.value
        let name = Conference.tier(for: id, in: league) == .other
            ? (group.shortName ?? group.name ?? "Conference")
            : Conference.name(for: id, in: league)
        let entries = (group.standings?.entries?.elements ?? []).compactMap { entry -> ConferenceStanding? in
            guard let mapped = team(from: entry.team, league: league) else { return nil }
            func stat(_ type: String) -> StandingsStatDTO? {
                entry.stats?.first { $0.type == type }
            }
            return ConferenceStanding(
                team: Team(
                    id: mapped.id, location: mapped.location, name: mapped.name,
                    abbreviation: mapped.abbreviation, displayName: mapped.displayName,
                    shortDisplayName: mapped.shortDisplayName, logoURL: mapped.logoURL,
                    conferenceId: id, league: league
                ),
                // Both leagues ship `vsconf`. The NFL also ships a
                // division record, spelled `divisionrecord` — the
                // camel-cased fallback that used to sit here never
                // matched a payload, so the column has always held the
                // conference record and now says so.
                conferenceRecord: stat("vsconf")?.summary,
                overallRecord: overallRecord(stat, league: league),
                streak: stat("streak")?.displayValue,
                playoffSeed: stat("playoffseed")?.value.map(Int.init),
                winPercent: stat("winpercent")?.value,
                winLossOTL: winLossOTL(stat),
                gamesPlayed: stat("gamesplayed")?.value.map(Int.init),
                points: stat("points")?.value.map(Int.init),
                gamesBehind: stat("gamesbehind")?.displayValue
            )
        }
        return ConferenceStandings(id: id, name: name,
                                   entries: ConferenceStandings.seedOrdered(entries),
                                   league: league, parentId: parentId)
    }

    /// Hockey's three-number record, composed rather than taken from the
    /// payload: ESPN's `total` summary for the NHL is "53-22-7, 113 PTS",
    /// which is a sentence and not a column. Nil unless all three numbers
    /// are there, so a half-built string can never reach a table.
    private static func winLossOTL(_ stat: (String) -> StandingsStatDTO?) -> String? {
        guard let wins = stat("wins")?.value,
              let losses = stat("losses")?.value,
              let otLosses = stat("otlosses")?.value else { return nil }
        return "\(Int(wins))-\(Int(losses))-\(Int(otLosses))"
    }

    /// The overall record, minus the tail the NHL appends to it — and
    /// composed from the numbers where ESPN ships no summary at all.
    ///
    /// The **divisional** response (`level=3`) carries no `total`: it
    /// sends `divisionstandings` in its place. So a division's page had a
    /// W-L column of dashes while the conference's, off a different
    /// request, was full. Wins and losses are in every response, and the
    /// OT-loss form is preferred where the league keeps one, or hockey's
    /// record would come back two numbers short.
    private static func overallRecord(_ stat: (String) -> StandingsStatDTO?,
                                      league: League) -> String? {
        if let summary = stat("total")?.summary {
            // "53-22-7, 113 PTS" → "53-22-7". The points live in their own
            // column; repeating them inside the record reads as a typo.
            return summary.split(separator: ",").first.map(String.init) ?? summary
        }
        if let withOTLosses = winLossOTL(stat) { return withOTLosses }
        guard let wins = stat("wins")?.value, let losses = stat("losses")?.value else { return nil }
        return "\(Int(wins))-\(Int(losses))"
    }

    static func teamSchedule(
        from dto: ScheduleResponseDTO, extraEvents: [ScheduleEventDTO] = [],
        league: League = .collegeFootball
    ) -> TeamSchedule {
        let selfTeam = dto.team.flatMap { scheduleTeam -> Team? in
            guard let id = scheduleTeam.id else { return nil }
            let logo = scheduleTeam.logo ?? scheduleTeam.logos?.first?.href
            return Team(
                id: id,
                location: scheduleTeam.location ?? scheduleTeam.displayName ?? "—",
                name: scheduleTeam.name ?? scheduleTeam.nickname,
                abbreviation: scheduleTeam.abbreviation,
                displayName: scheduleTeam.displayName,
                shortDisplayName: scheduleTeam.shortDisplayName,
                logoURL: logo.flatMap(URL.init(string:)),
                conferenceId: conferenceId(from: scheduleTeam.groups, league: league),
                league: league
            )
        }
        let games = ((dto.events?.elements ?? []) + extraEvents)
            .compactMap { game(from: $0, league: league) }
        // recordSummary/standingSummary always describe ESPN's *current*
        // season — under a past season's games they'd be this year's
        // numbers, so they only survive when the seasons match. groups is
        // different: it describes the season the response contains, so the
        // self-team's conferenceId is honest for past-season requests too.
        let summariesTrusted = dto.season?.year != nil && dto.season?.year == dto.requestedSeason?.year
        return TeamSchedule(
            team: selfTeam,
            record: summariesTrusted ? dto.team?.recordSummary : nil,
            standing: summariesTrusted ? dto.team?.standingSummary : nil,
            // Back onto our own axis: ESPN answers an NBA request for
            // `season=2027` with `requestedSeason.year: 2027`, and the
            // page that asked knows that season as 2026.
            year: dto.requestedSeason?.year.map(league.seasonYear(fromESPN:)),
            games: games.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) },
            byeWeek: dto.byeWeek?.value
        )
    }

    /// `groups` is the team's most specific group, and college football
    /// nests it differently from the three pro leagues.
    ///
    /// College football: when the group IS the conference, its parent is FBS
    /// (80) — never walk up. When it's a division (isConference false or
    /// absent), the parent is the conference.
    ///
    /// The NFL, NBA and NHL all ship the division with the conference as
    /// its parent (verified live: Seattle is `{id: "3", parent: {id: "7"}}`
    /// — NFC West under the NFC, 2026-09-05; the Lakers are
    /// `{id: "4", parent: {id: "6"}}` — Pacific under the West,
    /// 2026-09-08) and all mark `isConference` false, so walking up is
    /// always right. We keep the division id, which is the more specific
    /// and more useful group; `Conference.parent(of:in:)` recovers the
    /// conference.
    ///
    /// A wrong pick degrades safely: an unknown id is "Other" tier, which
    /// hides the affordance and lets callers fall back.
    static func conferenceId(from groups: TeamGroupsDTO?,
                             league: League = .collegeFootball) -> Int? {
        guard let groups else { return nil }
        if !league.hasCollegeDivisions {
            let id = groups.id?.value
            return Conference.isKnown(id, in: league) ? id : groups.parent?.id?.value
        }
        return groups.isConference == true ? groups.id?.value : groups.parent?.id?.value
    }

    static func game(from event: ScheduleEventDTO, league: League = .collegeFootball) -> Game? {
        guard let id = event.id,
              let competition = event.competitions?.first,
              let competitors = competition.competitors,
              let home = competitors.first(where: { $0.homeAway == "home" })
                  .flatMap({ competitor(from: $0, league: league) }),
              let away = competitors.first(where: { $0.homeAway == "away" })
                  .flatMap({ competitor(from: $0, league: league) })
        else { return nil }
        return Game(
            id: id,
            date: ESPNDate.parse(event.date ?? competition.date),
            timeTBD: (event.timeValid ?? competition.timeValid) == false,
            name: event.name,
            shortName: event.shortName,
            weekNumber: event.week?.number,
            seasonType: event.seasonType?.type,
            status: status(from: competition.status, situation: nil),
            home: home,
            away: away,
            broadcast: competition.broadcasts?.first?.media?.shortName
        )
    }

    static func competitor(from dto: ScheduleCompetitorDTO,
                           league: League = .collegeFootball) -> Competitor? {
        guard let team = team(from: dto.team, league: league) else { return nil }
        let rank = dto.curatedRank?.current?.value
        let score = dto.score?.displayValue.flatMap(Int.init) ?? dto.score?.value.map(Int.init)
        return Competitor(
            team: team,
            score: score,
            record: dto.record?.first(where: { $0.type == "total" })
                .flatMap { $0.summary ?? $0.displayValue },
            rank: rank.flatMap { (1...25).contains($0) ? $0 : nil },
            isHome: dto.homeAway == "home",
            winner: dto.winner
        )
    }

    /// Stamps every scoring play with the side whose number went up.
    /// A running score is the only honest source: a pick six scores for
    /// the defense, and the drive's team says the opposite.
    static func attributingScores(previous: [Drive], current: Drive?)
        -> (previous: [Drive], current: Drive?) {
        var away = 0
        var home = 0
        func stamp(_ drive: Drive) -> Drive {
            var drive = drive
            drive.plays = drive.plays.map { play in
                guard let a = play.awayScore, let h = play.homeScore else { return play }
                var play = play
                if play.isScoringPlay {
                    play.scoringSide = a > away ? .away : (h > home ? .home : nil)
                }
                away = a
                home = h
                return play
            }
            return drive
        }
        return (previous.map(stamp), current.map(stamp))
    }

    /// The same stamp over a flat feed. Hockey's goals are the reason:
    /// which side scored is the row's whole point, and a flat play carries
    /// no drive to read it off.
    static func attributingScores(_ plays: [Play]) -> [Play] {
        var away = 0
        var home = 0
        return plays.map { play in
            guard let a = play.awayScore, let h = play.homeScore else { return play }
            var play = play
            if play.isScoringPlay {
                play.scoringSide = a > away ? .away : (h > home ? .home : nil)
            }
            away = a
            home = h
            return play
        }
    }

    /// One drive and its plays. Shared by the drive log and the live
    /// current drive — ESPN ships them in the same shape, so the strip and
    /// the play list can't disagree about a possession.
    static func drive(from dto: DriveDTO, fallbackId: String) -> Drive {
        Drive(
            id: dto.id ?? fallbackId,
            teamId: dto.team?.id,
            result: dto.displayResult?.trimmingCharacters(in: .whitespaces),
            isScore: dto.isScore ?? false,
            summary: dto.description,
            period: dto.start?.period?.number,
            plays: plays(from: dto.plays?.elements ?? [],
                         idPrefix: dto.id ?? fallbackId)
        )
    }

    /// One play feed, drive-nested or flat — the same mapping either way,
    /// so the two can't describe a play differently.
    static func plays(from dtos: [PlayDTO], idPrefix: String) -> [Play] {
        dtos.enumerated().map { index, play in
            Play(
                id: play.id ?? "\(idPrefix)-play-\(index)",
                text: play.text?.trimmingCharacters(in: .whitespaces),
                downDistanceText: play.start?.downDistanceText,
                nextDownDistanceText: play.end?.shortDownDistanceText
                    ?? play.end?.downDistanceText,
                possessionText: play.end?.possessionText,
                yardsToEndzone: play.end?.yardsToEndzone,
                clock: play.clock?.displayValue,
                period: play.period?.number,
                typeText: play.type?.text,
                isScoringPlay: play.scoringPlay ?? false,
                awayScore: play.awayScore,
                homeScore: play.homeScore,
                teamId: play.team?.id
            )
        }
    }

    /// The Scoring card's rows: ESPN's own `scoringPlays` where it ships
    /// them, and otherwise the scoring plays picked out of the flat feed.
    ///
    /// Only for leagues that want the card at all — hockey does, because a
    /// goal is an event; basketball doesn't, because ~98 of them is the box
    /// score with worse formatting, which is what `scoringCardTitle`
    /// answers.
    static func scoringPlays(from dto: SummaryResponseDTO, flatPlays: [Play],
                             league: League) -> [ScoringPlay] {
        if let shipped = dto.scoringPlays, !shipped.isEmpty {
            return shipped.enumerated().map { index, play in
                ScoringPlay(
                    id: play.id ?? "play-\(index)",
                    period: play.period?.number,
                    clock: play.clock?.displayValue,
                    text: play.text?.trimmingCharacters(in: .whitespaces),
                    typeAbbreviation: play.type?.abbreviation,
                    teamId: play.team?.id,
                    awayScore: play.awayScore,
                    homeScore: play.homeScore
                )
            }
        }
        guard league.scoringCardTitle != nil else { return [] }
        // Only plays that actually moved the game score. A hockey
        // shootout is the reason: ESPN flags every attempt as a scoring
        // play and stamps it with the *shootout tally* rather than the
        // game score (1-2 on all three attempts of a 2-2 game, verified
        // live), so a plain `isScoringPlay` filter listed three goals
        // whose running score went nowhere and disagreed with the header.
        // A shootout is worth one goal, awarded at the end, and the line
        // score's SO column is where it belongs.
        return flatPlays.filter { $0.isScoringPlay && $0.scoringSide != nil }.map { play in
            ScoringPlay(
                id: play.id,
                period: play.period,
                clock: play.clock,
                text: play.text,
                typeAbbreviation: play.typeText,
                teamId: play.teamId,
                awayScore: play.awayScore,
                homeScore: play.homeScore
            )
        }
    }

    static func gameSummary(from dto: SummaryResponseDTO,
                            league: League = .collegeFootball) -> GameSummary {
        let competition = dto.header?.competitions?.first
        let competitors = competition?.competitors ?? []

        func side(_ homeAway: String) -> GameSummary.Side? {
            guard let comp = competitors.first(where: { $0.homeAway == homeAway }),
                  let team = team(from: comp.team, league: league) else { return nil }
            let rank = comp.rank?.value
            return GameSummary.Side(
                team: team,
                score: comp.score?.value,
                record: comp.record?.first(where: { $0.type == "total" })
                    .flatMap { $0.summary ?? $0.displayValue },
                rank: rank.flatMap { (1...25).contains($0) ? $0 : nil },
                winner: comp.winner,
                linescores: (comp.linescores ?? []).compactMap(\.displayValue)
            )
        }

        // One chronological pass over every play, current drive included,
        // so each scoring play knows whose points it put up before any
        // view asks. Split back apart after — the strip wants the drive
        // in progress on its own.
        let previousDrives = (dto.drives?.previous?.elements ?? []).enumerated().map { index, driveDTO in
            drive(from: driveDTO, fallbackId: "drive-\(index)")
        }
        let currentDrive = dto.drives?.current.map { drive(from: $0, fallbackId: "drive-current") }
        let stampedDrives = attributingScores(previous: previousDrives, current: currentDrive)
        // Football's plays already live inside its drives; carrying them
        // twice would print the same rows in two places. A league with no
        // drives keeps the flat feed, which is the only one it gets.
        let flatPlays = previousDrives.isEmpty && currentDrive == nil
            ? attributingScores(plays(from: dto.plays?.elements ?? [], idPrefix: "play"))
            : []

        return GameSummary(
            home: side("home"),
            away: side("away"),
            status: status(from: competition?.status, situation: nil),
            scoringPlays: scoringPlays(from: dto, flatPlays: flatPlays, league: league),
            drives: stampedDrives.previous,
            currentDrive: stampedDrives.current,
            teamStats: teamStats(from: dto.boxscore, league: league),
            leaders: leaders(from: dto.leaders?.elements ?? [], competitors: competitors,
                             league: league),
            boxScore: boxScore(from: dto.boxscore),
            plays: flatPlays,
            venue: dto.gameInfo?.venue?.fullName,
            attendance: dto.gameInfo?.attendance,
            venueCity: {
                let joined = [dto.gameInfo?.venue?.address?.city,
                              dto.gameInfo?.venue?.address?.state]
                    .compactMap { $0 }.joined(separator: ", ")
                return joined.isEmpty ? nil : joined
            }(),
            venueCapacity: dto.gameInfo?.venue?.capacity,
            grassSurface: dto.gameInfo?.venue?.grass,
            weatherCondition: dto.gameInfo?.weather?.displayValue,
            weatherTemperature: dto.gameInfo?.weather?.temperature.map(Int.init)
        )
    }

    static func boxScore(from boxscore: BoxscoreDTO?) -> [BoxScore] {
        (boxscore?.players ?? []).compactMap { entry -> BoxScore? in
            guard let teamId = entry.team?.id else { return nil }
            let categories = (entry.statistics ?? []).compactMap { group -> BoxScore.Category? in
                // Football splits its box score into named groups
                // (passing, rushing, …). Basketball ships **one** group
                // with `name: null`, because there is only one table to
                // ship — and requiring a name dropped every NBA box score
                // on the floor. The columns are what a box score is; the
                // name is only how we label a section when there are
                // several.
                let name = group.name ?? group.text ?? "players"
                // No headers, nothing to align stats against.
                let columns = group.labels ?? []
                guard !columns.isEmpty else { return nil }

                let players = (group.athletes?.elements ?? []).compactMap { row -> BoxScore.Player? in
                    guard let athlete = row.athlete,
                          let name = athlete.displayName ?? athlete.shortName,
                          let stats = row.stats,
                          // A row that doesn't match the header would put
                          // every number under the wrong column. Drop it
                          // rather than render a lie.
                          stats.count == columns.count
                    else { return nil }
                    return BoxScore.Player(
                        id: athlete.id ?? "\(teamId)-\(name)",
                        name: name,
                        jersey: athlete.jersey,
                        headshotURL: athlete.headshot?.href.flatMap(URL.init(string:)),
                        stats: stats)
                }
                // ESPN ships all ten categories for every game whether or
                // not anyone recorded one. An interception group with no
                // interceptions isn't a section, it's noise.
                guard !players.isEmpty else { return nil }

                let totals = group.totals ?? []
                return BoxScore.Category(
                    id: name,
                    label: categoryLabel(name: name, text: group.text, team: entry.team),
                    columns: columns,
                    players: players,
                    totals: totals.count == columns.count ? totals : [])
            }
            guard !categories.isEmpty else { return nil }
            return BoxScore(teamId: teamId, categories: categories)
        }
    }

    /// ESPN's group text is the team-prefixed "Miami Passing"; the card
    /// header already says whose table this is, so the prefix comes off.
    /// Falls back to un-camel-casing the group name ("kickReturns").
    static func categoryLabel(name: String, text: String?, team: TeamDTO?) -> String {
        for prefix in [team?.displayName, team?.location, team?.name].compactMap(\.self) {
            if let text, text.hasPrefix(prefix) {
                let stripped = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                if !stripped.isEmpty { return stripped }
            }
        }
        if let text, !text.isEmpty, team == nil { return text }
        var words = ""
        for character in name {
            if character.isUppercase, !words.isEmpty { words.append(" ") }
            words.append(character)
        }
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    static func teamStats(from boxscore: BoxscoreDTO?,
                          league: League = .collegeFootball) -> [StatComparison] {
        let teams = boxscore?.teams ?? []
        guard teams.count == 2 else { return [] }
        // boxscore.teams has no homeAway on some responses; ESPN orders it
        // away-first, matching the scoreboard convention.
        let away = teams.first { $0.homeAway == "away" } ?? teams[0]
        let home = teams.first { $0.homeAway == "home" } ?? teams[1]

        func value(_ name: String, of team: BoxscoreTeamDTO) -> String? {
            team.statistics?.first { $0.name == name }?.displayValue
        }

        return league.comparedStats.compactMap { stat in
            guard let awayDisplay = value(stat.name, of: away),
                  let homeDisplay = value(stat.name, of: home) else { return nil }
            return StatComparison(
                id: stat.name,
                label: stat.label,
                away: awayDisplay,
                home: homeDisplay,
                awayValue: statMagnitude(awayDisplay),
                homeValue: statMagnitude(homeDisplay)
            )
        }
    }

    /// Parses a stat displayValue into a bar magnitude: plain numbers,
    /// "made-attempts" fractions, and "MM:SS" possession clocks.
    static func statMagnitude(_ display: String) -> Double? {
        if let number = Double(display) { return number }
        let dashParts = display.split(separator: "-")
        if dashParts.count == 2, let made = Double(dashParts[0]), let attempts = Double(dashParts[1]) {
            return attempts > 0 ? made / attempts : 0
        }
        let clockParts = display.split(separator: ":")
        if clockParts.count == 2, let minutes = Double(clockParts[0]), let seconds = Double(clockParts[1]) {
            return minutes * 60 + seconds
        }
        return nil
    }

    /// The three offensive leader categories, one entry per category with
    /// both sides filled in.
    static func leaders(from teamLeaders: [SummaryTeamLeadersDTO],
                        competitors: [HeaderCompetitorDTO],
                        league: League = .collegeFootball) -> [LeaderCategory] {
        let awayId = competitors.first { $0.homeAway == "away" }?.team?.id
        let homeId = competitors.first { $0.homeAway == "home" }?.team?.id

        func leader(teamId: String?, category: String) -> LeaderCategory.Leader? {
            guard let teamId,
                  let entry = teamLeaders.first(where: { $0.team?.id == teamId })?
                      .leaders?.first(where: { $0.name == category })?
                      .leaders?.first,
                  let name = entry.athlete?.displayName ?? entry.athlete?.shortName
            else { return nil }
            return LeaderCategory.Leader(
                name: name,
                statLine: entry.displayValue ?? "",
                headshotURL: entry.athlete?.headshot?.href.flatMap(URL.init(string:)))
        }

        func build(_ categories: [(name: String, label: String)]) -> [LeaderCategory] {
            categories.compactMap { category in
                let away = leader(teamId: awayId, category: category.name)
                let home = leader(teamId: homeId, category: category.name)
                guard away != nil || home != nil else { return nil }
                return LeaderCategory(id: category.name, label: category.label,
                                      away: away, home: home)
            }
        }
        let named = build(league.leaderCategories)
        guard named.isEmpty else { return named }
        // Whatever ESPN actually shipped, in its own order, first three.
        // The league's list is the app's preferred spelling, not a
        // requirement — a category we didn't think to name beats an empty
        // card, and it is how a league we haven't tuned still says
        // something.
        let shipped = (teamLeaders.first?.leaders ?? [])
            .compactMap { category -> (name: String, label: String)? in
                guard let name = category.name else { return nil }
                return (name, category.displayName ?? name.capitalized)
            }
            .prefix(3)
        return build(Array(shipped))
    }

    /// One historical poll, whose ranks name their team by `$ref` alone —
    /// the id is parsed out of that URL and resolved against the `/teams`
    /// directory. A rank whose team we can't name is dropped: a row
    /// reading "—" is worse than a gap the rank numbers already explain.
    static func poll(from dto: CoreRankingDTO, teams: [String: Team]) -> Poll {
        let ranks = (dto.ranks?.elements ?? []).compactMap { rank -> RankedTeam? in
            guard let current = rank.current,
                  let id = rank.team?.teamId,
                  let team = teams[id] else { return nil }
            return RankedTeam(
                team: team,
                current: current,
                previous: rank.previous,
                points: rank.points,
                firstPlaceVotes: rank.firstPlaceVotes,
                record: rank.record?.summary
            )
        }
        let name = dto.name ?? dto.shortName ?? "Poll"
        return Poll(
            id: dto.id ?? name,
            name: name,
            shortName: dto.shortName,
            type: dto.type,
            headline: dto.shortHeadline ?? dto.headline,
            ranks: ranks
        )
    }

    /// The `/teams` payload flattened to an id → team lookup.
    static func teamsById(from dto: TeamsResponseDTO?,
                          league: League = .collegeFootball) -> [String: Team] {
        let entries = dto?.sports?.first?.leagues?.first?.teams ?? []
        return entries.reduce(into: [:]) { table, entry in
            guard let team = team(from: entry.team, league: league) else { return }
            table[team.id] = team
        }
    }

    static func polls(from dto: RankingsResponseDTO) -> [Poll] {
        (dto.rankings?.elements ?? []).compactMap { ranking in
            guard let name = ranking.name else { return nil }
            let ranks = (ranking.ranks?.elements ?? []).compactMap { rank -> RankedTeam? in
                guard let team = team(from: rank.team), let current = rank.current else { return nil }
                return RankedTeam(
                    team: team,
                    current: current,
                    previous: rank.previous,
                    points: rank.points,
                    firstPlaceVotes: rank.firstPlaceVotes,
                    record: rank.recordSummary
                )
            }
            return Poll(
                id: ranking.id ?? name,
                name: name,
                shortName: ranking.shortName,
                type: ranking.type,
                // "2025 AP Poll: Final Rankings" over the long headline,
                // which says "Rankings" twice under a Rankings title.
                headline: ranking.shortHeadline ?? ranking.headline,
                ranks: ranks
            )
        }
    }
}

// MARK: - Date parsing

nonisolated enum ESPNDate {
    // ESPN sends "2026-08-29T16:00Z" (no seconds).
    private static let noSeconds = makeFormatter("yyyy-MM-dd'T'HH:mm'Z'")
    private static let withSeconds = makeFormatter("yyyy-MM-dd'T'HH:mm:ss'Z'")

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = format
        return formatter
    }

    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        return noSeconds.date(from: string)
            ?? withSeconds.date(from: string)
            ?? ISO8601DateFormatter().date(from: string)
    }
}
