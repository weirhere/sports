import Foundation

/// The domain-facing contract. If ESPN's API dies, a CFBD-backed client
/// conforms to this same protocol and the rest of the app never notices.
nonisolated protocol ScoresProviding: Sendable {
    /// Fetch the scoreboard. Pass nil for everything to get ESPN's current
    /// week. `year` selects a season (ESPN's `dates=` param, verified live
    /// 2026-07-21); always pair it with an explicit week — a bare year
    /// request dumps the entire season's events.
    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?) async throws -> Scoreboard
    func rankings() async throws -> [Poll]
    func fbsConferences() async throws -> [ConferenceTeams]
    /// All FBS conferences' standings in one call, each in the provider's
    /// standings order (ESPN's encodes tiebreakers). Empty conferences are
    /// kept — offseason responses can have zero entries and the page needs
    /// to say "Standings TBA", not error.
    func conferenceStandings() async throws -> [ConferenceStandings]
    /// One team's schedule. `year` selects a season; nil means the current
    /// one, with the provider free to fall back to last season while the
    /// next is unpublished. An explicit year returns exactly that season —
    /// a user who picked 2019 must never silently get 2018.
    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule
    func gameSummary(eventId: String) async throws -> GameSummary
}

nonisolated extension ScoresProviding {
    /// The current season (with the unpublished-season fallback).
    func teamSchedule(teamId: String) async throws -> TeamSchedule {
        try await teamSchedule(teamId: teamId, year: nil)
    }
}

nonisolated enum ESPNError: Error {
    case invalidURL
    case badStatus(Int)
}

/// Talks to ESPN's unofficial API. An actor so fetching and decoding stay
/// off the main thread (the project defaults types to MainActor).
actor ESPNClient: ScoresProviding {
    private static let base = "https://site.api.espn.com/apis/site/v2/sports/football/college-football"
    // Conference membership lives on the standings API (apis/v2, not
    // site/v2); the /teams endpoint carries no conference data.
    private static let standingsBase = "https://site.api.espn.com/apis/v2/sports/football/college-football"

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?) async throws -> Scoreboard {
        var items = [
            URLQueryItem(name: "groups", value: String(Conference.fbsGroupId)),
            URLQueryItem(name: "limit", value: "300"),
        ]
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
        return ESPNMapper.scoreboard(from: dto)
    }

    func rankings() async throws -> [Poll] {
        let dto: RankingsResponseDTO = try await fetch(path: "/rankings", query: [])
        return ESPNMapper.polls(from: dto)
    }

    func fbsConferences() async throws -> [ConferenceTeams] {
        let dto: StandingsResponseDTO = try await fetch(
            base: Self.standingsBase, path: "/standings",
            query: [URLQueryItem(name: "group", value: String(Conference.fbsGroupId))]
        )
        return ESPNMapper.conferences(from: dto)
    }

    func conferenceStandings() async throws -> [ConferenceStandings] {
        let dto: StandingsResponseDTO = try await fetch(
            base: Self.standingsBase, path: "/standings",
            query: [URLQueryItem(name: "group", value: String(Conference.fbsGroupId))]
        )
        return ESPNMapper.conferenceStandings(from: dto)
    }

    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        if let year {
            return try await fetchSchedule(teamId: teamId, year: year)
        }
        let current = CFBSeason.year()
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
            from: regular, extraEvents: postseason?.events?.elements ?? []
        )
    }

    func gameSummary(eventId: String) async throws -> GameSummary {
        let dto: SummaryResponseDTO = try await fetch(
            path: "/summary", query: [URLQueryItem(name: "event", value: eventId)]
        )
        return ESPNMapper.gameSummary(from: dto)
    }

    private func fetch<T: Decodable>(path: String, query: [URLQueryItem]) async throws -> T {
        try await fetch(base: Self.base, path: path, query: query)
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
    static func scoreboard(from dto: ScoreboardDTO) -> Scoreboard {
        Scoreboard(
            seasonYear: dto.season?.year,
            seasonType: dto.season?.type,
            currentWeekNumber: dto.week?.number,
            weeks: weekSlots(from: dto),
            games: (dto.events?.elements ?? []).compactMap(game(from:))
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

    static func game(from event: EventDTO) -> Game? {
        guard let id = event.id,
              let competition = event.competitions?.first,
              let competitors = competition.competitors,
              let homeDTO = competitors.first(where: { $0.homeAway == "home" }),
              let awayDTO = competitors.first(where: { $0.homeAway == "away" }),
              let home = competitor(from: homeDTO),
              let away = competitor(from: awayDTO)
        else { return nil }

        return Game(
            id: id,
            date: ESPNDate.parse(event.date),
            timeTBD: competition.timeValid == false,
            name: event.name,
            shortName: event.shortName,
            weekNumber: event.week?.number,
            status: status(from: event.status, situation: competition.situation),
            home: home,
            away: away,
            broadcast: competition.broadcast ?? competition.broadcasts?.first?.names?.first
        )
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
                possessionTeamId: situation?.possession
            )
        case "post" where dto?.type?.completed == true:
            return .final(detail: detail)
        default:
            return .other(detail: detail)
        }
    }

    static func competitor(from dto: CompetitorDTO) -> Competitor? {
        guard let team = team(from: dto.team) else { return nil }
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

    static func team(from dto: TeamDTO?) -> Team? {
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
            conferenceId: dto.conferenceId?.value
        )
    }

    static func conferences(from dto: StandingsResponseDTO) -> [ConferenceTeams] {
        (dto.children ?? []).compactMap { group in
            let id = group.id?.value
            // Prefer our short names ("SEC") over ESPN's long ones
            // ("Southeastern Conference") when the id is known.
            let name = Conference.tier(for: id) == .other
                ? (group.shortName ?? group.name ?? "Conference")
                : Conference.name(for: id)
            let teams = (group.standings?.entries?.elements ?? []).compactMap { entry -> Team? in
                guard let mapped = team(from: entry.team) else { return nil }
                return Team(
                    id: mapped.id, location: mapped.location, name: mapped.name,
                    abbreviation: mapped.abbreviation, displayName: mapped.displayName,
                    shortDisplayName: mapped.shortDisplayName, logoURL: mapped.logoURL,
                    conferenceId: id
                )
            }
            guard !teams.isEmpty else { return nil }
            return ConferenceTeams(id: id, name: name,
                                   teams: teams.sorted { $0.location < $1.location })
        }
        .sorted { lhs, rhs in
            let (lt, rt) = (Conference.tier(for: lhs.id), Conference.tier(for: rhs.id))
            return lt == rt ? lhs.name < rhs.name : lt < rt
        }
    }

    /// Standings sibling of `conferences(from:)` over the same response.
    /// Differences are the contract: entry order is preserved (ESPN's
    /// standings order, tiebreakers included — never re-sort), and empty
    /// conferences are kept so the page can render "Standings TBA".
    static func conferenceStandings(from dto: StandingsResponseDTO) -> [ConferenceStandings] {
        (dto.children ?? []).map { group in
            let id = group.id?.value
            let name = Conference.tier(for: id) == .other
                ? (group.shortName ?? group.name ?? "Conference")
                : Conference.name(for: id)
            let entries = (group.standings?.entries?.elements ?? []).compactMap { entry -> ConferenceStanding? in
                guard let mapped = team(from: entry.team) else { return nil }
                func stat(_ type: String) -> StandingsStatDTO? {
                    entry.stats?.first { $0.type == type }
                }
                return ConferenceStanding(
                    team: Team(
                        id: mapped.id, location: mapped.location, name: mapped.name,
                        abbreviation: mapped.abbreviation, displayName: mapped.displayName,
                        shortDisplayName: mapped.shortDisplayName, logoURL: mapped.logoURL,
                        conferenceId: id
                    ),
                    conferenceRecord: stat("vsconf")?.summary,
                    overallRecord: stat("total")?.summary,
                    streak: stat("streak")?.displayValue
                )
            }
            return ConferenceStandings(id: id, name: name, entries: entries)
        }
        .sorted { lhs, rhs in
            let (lt, rt) = (Conference.tier(for: lhs.id), Conference.tier(for: rhs.id))
            return lt == rt ? lhs.name < rhs.name : lt < rt
        }
    }

    static func teamSchedule(
        from dto: ScheduleResponseDTO, extraEvents: [ScheduleEventDTO] = []
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
                conferenceId: conferenceId(from: scheduleTeam.groups)
            )
        }
        let games = ((dto.events?.elements ?? []) + extraEvents).compactMap(game(from:))
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

    /// `groups` is the team's most specific group. When it IS the
    /// conference, its parent is FBS (80) — never walk up. When it's a
    /// division (isConference false/absent), the parent is the conference.
    /// A wrong pick degrades safely: an unknown id is "Other" tier, which
    /// hides the affordance and lets callers fall back.
    static func conferenceId(from groups: TeamGroupsDTO?) -> Int? {
        guard let groups else { return nil }
        return groups.isConference == true ? groups.id?.value : groups.parent?.id?.value
    }

    static func game(from event: ScheduleEventDTO) -> Game? {
        guard let id = event.id,
              let competition = event.competitions?.first,
              let competitors = competition.competitors,
              let home = competitors.first(where: { $0.homeAway == "home" }).flatMap(competitor(from:)),
              let away = competitors.first(where: { $0.homeAway == "away" }).flatMap(competitor(from:))
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

    static func competitor(from dto: ScheduleCompetitorDTO) -> Competitor? {
        guard let team = team(from: dto.team) else { return nil }
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

    static func gameSummary(from dto: SummaryResponseDTO) -> GameSummary {
        let competition = dto.header?.competitions?.first
        let competitors = competition?.competitors ?? []

        func side(_ homeAway: String) -> GameSummary.Side? {
            guard let comp = competitors.first(where: { $0.homeAway == homeAway }),
                  let team = team(from: comp.team) else { return nil }
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
            venue: dto.gameInfo?.venue?.fullName,
            attendance: dto.gameInfo?.attendance
        )
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
            return LeaderCategory.Leader(name: name, statLine: entry.displayValue ?? "")
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
