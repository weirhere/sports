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
    func rankings() async throws -> [Poll]
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
    func gameSummary(eventId: String) async throws -> GameSummary
}

nonisolated extension ScoresProviding {
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

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(league: League = .collegeFootball, session: URLSession = .shared) {
        self.league = league
        self.session = session
        self.base = "https://site.api.espn.com/apis/site/v2/sports/football/\(league.pathSegment)"
        self.standingsBase = "https://site.api.espn.com/apis/v2/sports/football/\(league.pathSegment)"
    }

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        // Deterministic order, and FBS first when it's in the set: it is
        // the canonical payload for anything both divisions carry. The NFL
        // has no divisions, so it asks once with no group filter.
        let ordered = league == .nfl ? [Conference.Division?.none]
                                     : divisions.sorted { $0.groupId < $1.groupId }.map { $0 }
        guard let primary = ordered.first else {
            throw ESPNError.invalidURL
        }

        func board(for division: Conference.Division?) async throws -> Scoreboard {
            var items = [URLQueryItem(name: "limit", value: "300")]
            if let division {
                items.insert(URLQueryItem(name: "groups", value: String(division.groupId)), at: 0)
            }
            if let weekValue {
                items.append(URLQueryItem(name: "week", value: String(weekValue)))
            }
            if let seasonType {
                items.append(URLQueryItem(name: "seasontype", value: String(seasonType)))
            }
            if let year {
                items.append(URLQueryItem(name: "dates", value: String(year)))
            }
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
        // `dates={year}` widens the scoreboard to the whole season
        // (verified live 2026-08-29: ACC 2026 returns 134 events, types 2
        // and 3, each stamped with its own week). A conference's season
        // runs ~100–200 events, so one 400-cap request covers it.
        let items = [
            URLQueryItem(name: "groups", value: String(conferenceId)),
            URLQueryItem(name: "limit", value: "400"),
            URLQueryItem(name: "dates", value: String(year ?? SeasonYear.year(for: league))),
        ]
        let dto: ScoreboardDTO = try await fetch(path: "/scoreboard", query: items)
        return ESPNMapper.scoreboard(from: dto, league: league).games
    }

    func rankings() async throws -> [Poll] {
        // `/nfl/rankings` is a 404 — the NFL has no poll and never will.
        // An empty list is the honest answer; callers hide the section.
        guard league == .collegeFootball else { return [] }
        let dto: RankingsResponseDTO = try await fetch(path: "/rankings", query: [])
        return ESPNMapper.polls(from: dto)
    }

    func conferences(in division: Conference.Division) async throws -> [ConferenceTeams] {
        // The NFL's standings response is already the whole league (AFC and
        // NFC, 16 entries each), so it takes no group filter.
        let query = league == .nfl ? []
            : [URLQueryItem(name: "group", value: String(division.groupId))]
        let dto: StandingsResponseDTO = try await fetch(
            base: standingsBase, path: "/standings", query: query
        )
        return ESPNMapper.conferences(from: dto, league: league)
    }

    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings] {
        var query = league == .nfl ? []
            : [URLQueryItem(name: "group", value: String(division.groupId))]
        // Verified live 2026-08-25: `season` scopes records AND membership,
        // so realignment years read correctly.
        if let year {
            query.append(URLQueryItem(name: "season", value: String(year)))
        }
        let dto: StandingsResponseDTO = try await fetch(
            base: standingsBase, path: "/standings", query: query
        )
        return ESPNMapper.conferenceStandings(from: dto, league: league)
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
        // season explicitly. Regular season and postseason are separate requests.
        let path = "/teams/\(teamId)/schedule"
        let regularQuery = [
            URLQueryItem(name: "season", value: String(year)),
            URLQueryItem(name: "seasontype", value: "2"),
        ]
        let postseasonQuery = [
            URLQueryItem(name: "season", value: String(year)),
            URLQueryItem(name: "seasontype", value: "3"),
        ]
        async let regularFetch: ScheduleResponseDTO = fetch(path: path, query: regularQuery)
        async let postseasonFetch: ScheduleResponseDTO? = try? fetch(path: path, query: postseasonQuery)
        let regular = try await regularFetch
        let postseason = await postseasonFetch
        return ESPNMapper.teamSchedule(
            from: regular, extraEvents: postseason?.events?.elements ?? [], league: league
        )
    }

    func gameSummary(eventId: String) async throws -> GameSummary {
        let dto: SummaryResponseDTO = try await fetch(
            path: "/summary", query: [URLQueryItem(name: "event", value: eventId)]
        )
        return ESPNMapper.gameSummary(from: dto, league: league)
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
        let periods = dto.leagues?.first?.calendar ?? []
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
            conferenceId: dto.conferenceId?.value,
            league: league
        )
    }

    static func conferences(from dto: StandingsResponseDTO,
                            league: League = .collegeFootball) -> [ConferenceTeams] {
        (dto.children ?? []).compactMap { group in
            let id = group.id?.value
            // Prefer our short names ("SEC") over ESPN's long ones
            // ("Southeastern Conference") when the id is known.
            let name = Conference.tier(for: id, in: league) == .other
                ? (group.shortName ?? group.name ?? "Conference")
                : Conference.name(for: id, in: league)
            let teams = (group.standings?.entries?.elements ?? []).compactMap { entry -> Team? in
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
        (dto.children ?? []).map { group in
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
                    // The NFL's in-group record is `divisionRecord`; college
                    // football's is `vsconf`. Same column, different name.
                    conferenceRecord: (stat("vsconf") ?? stat("divisionRecord"))?.summary,
                    overallRecord: stat("total")?.summary,
                    streak: stat("streak")?.displayValue,
                    playoffSeed: stat("playoffseed")?.value.map(Int.init)
                )
            }
            return ConferenceStandings(id: id, name: name,
                                       entries: ConferenceStandings.seedOrdered(entries),
                                       league: league)
        }
        .sorted { lhs, rhs in
            let (lt, rt) = (Conference.tier(for: lhs.id, in: league),
                            Conference.tier(for: rhs.id, in: league))
            return lt == rt ? lhs.name < rhs.name : lt < rt
        }
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
            year: dto.requestedSeason?.year,
            games: games.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        )
    }

    /// `groups` is the team's most specific group, and the two leagues nest
    /// it differently.
    ///
    /// College football: when the group IS the conference, its parent is FBS
    /// (80) — never walk up. When it's a division (isConference false or
    /// absent), the parent is the conference.
    ///
    /// The NFL always ships the division with the conference as its parent
    /// (verified live 2026-09-05: Seattle is `{id: "3", parent: {id: "7"}}`
    /// — NFC West under the NFC) and always marks `isConference` false, so
    /// walking up is always right. We keep the division id, which is the
    /// more specific and more useful group; `Conference.parent(of:in:)`
    /// recovers the conference.
    ///
    /// A wrong pick degrades safely: an unknown id is "Other" tier, which
    /// hides the affordance and lets callers fall back.
    static func conferenceId(from groups: TeamGroupsDTO?,
                             league: League = .collegeFootball) -> Int? {
        guard let groups else { return nil }
        if league == .nfl {
            let id = groups.id?.value
            return Conference.isKnown(id, in: .nfl) ? id : groups.parent?.id?.value
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

        return GameSummary(
            home: side("home"),
            away: side("away"),
            status: status(from: competition?.status, situation: nil),
            scoringPlays: (dto.scoringPlays ?? []).enumerated().map { index, play in
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
            },
            drives: (dto.drives?.previous?.elements ?? []).enumerated().map { index, drive in
                Drive(
                    id: drive.id ?? "drive-\(index)",
                    teamId: drive.team?.id,
                    result: drive.displayResult?.trimmingCharacters(in: .whitespaces),
                    isScore: drive.isScore ?? false,
                    summary: drive.description,
                    period: drive.start?.period?.number
                )
            },
            teamStats: teamStats(from: dto.boxscore),
            leaders: leaders(from: dto.leaders?.elements ?? [], competitors: competitors),
            boxScore: boxScore(from: dto.boxscore),
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
                guard let name = group.name else { return nil }
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

    /// The comparison stats worth a bar, in display order.
    private static let comparedStats: [(name: String, label: String)] = [
        ("totalYards", "Total Yards"),
        ("netPassingYards", "Passing"),
        ("rushingYards", "Rushing"),
        ("thirdDownEff", "3rd Down"),
        ("turnovers", "Turnovers"),
        ("possessionTime", "Possession"),
    ]

    static func teamStats(from boxscore: BoxscoreDTO?) -> [StatComparison] {
        let teams = boxscore?.teams ?? []
        guard teams.count == 2 else { return [] }
        // boxscore.teams has no homeAway on some responses; ESPN orders it
        // away-first, matching the scoreboard convention.
        let away = teams.first { $0.homeAway == "away" } ?? teams[0]
        let home = teams.first { $0.homeAway == "home" } ?? teams[1]

        func value(_ name: String, of team: BoxscoreTeamDTO) -> String? {
            team.statistics?.first { $0.name == name }?.displayValue
        }

        return comparedStats.compactMap { stat in
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
    private static let leaderCategories: [(name: String, label: String)] = [
        ("passingYards", "Passing"),
        ("rushingYards", "Rushing"),
        ("receivingYards", "Receiving"),
    ]

    static func leaders(from teamLeaders: [SummaryTeamLeadersDTO],
                        competitors: [HeaderCompetitorDTO]) -> [LeaderCategory] {
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

        return leaderCategories.compactMap { category in
            let away = leader(teamId: awayId, category: category.name)
            let home = leader(teamId: homeId, category: category.name)
            guard away != nil || home != nil else { return nil }
            return LeaderCategory(id: category.name, label: category.label, away: away, home: home)
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
