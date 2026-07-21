import Foundation

/// The domain-facing contract. If ESPN's API dies, a CFBD-backed client
/// conforms to this same protocol and the rest of the app never notices.
nonisolated protocol ScoresProviding: Sendable {
    /// Fetch the scoreboard. Pass nil for both to get ESPN's current week.
    func scoreboard(weekValue: Int?, seasonType: Int?) async throws -> Scoreboard
    func rankings() async throws -> [Poll]
}

nonisolated enum ESPNError: Error {
    case invalidURL
    case badStatus(Int)
}

/// Talks to ESPN's unofficial API. An actor so fetching and decoding stay
/// off the main thread (the project defaults types to MainActor).
actor ESPNClient: ScoresProviding {
    private static let base = "https://site.api.espn.com/apis/site/v2/sports/football/college-football"

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func scoreboard(weekValue: Int?, seasonType: Int?) async throws -> Scoreboard {
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
        let dto: ScoreboardDTO = try await fetch(path: "/scoreboard", query: items)
        return ESPNMapper.scoreboard(from: dto)
    }

    func rankings() async throws -> [Poll] {
        let dto: RankingsResponseDTO = try await fetch(path: "/rankings", query: [])
        return ESPNMapper.polls(from: dto)
    }

    private func fetch<T: Decodable>(path: String, query: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(string: Self.base + path) else {
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
                headline: ranking.headline,
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
