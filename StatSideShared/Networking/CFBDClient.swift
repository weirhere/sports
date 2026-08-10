import Foundation

nonisolated enum CFBDError: Error {
    case invalidURL
    case badStatus(Int)
    case unknownTeam(String)
    case gameNotFound(String)
}

/// Talks to CollegeFootballData.com's v2 API (bearer key required; free at
/// collegefootballdata.com/key, live scoreboard needs Patreon Tier 1+).
/// Conforms to the same ScoresProviding contract as ESPNClient, so the rest
/// of the app never notices which backend is active.
///
/// CFBD splits what ESPN inlines: game rows carry no records, ranks, logos,
/// or TV network. The client joins /teams/fbs, /records, /rankings, and
/// /games/media onto /games + the live /scoreboard, caching the slow-moving
/// joins per season so a 30s poll re-fetches only games + live state.
actor CFBDClient: ScoresProviding {
    private static let base = "https://api.collegefootballdata.com"

    private let session: URLSession
    private let apiKey: String
    private let decoder = JSONDecoder()

    // Season-scoped caches. Records and ranks move weekly, teams yearly —
    // cached for the process lifetime; a relaunch refreshes them.
    private var teamsByYear: [Int: [CFBDTeamDTO]] = [:]
    private var calendarByYear: [Int: [WeekSlot]] = [:]
    private var recordDTOsByYear: [Int: [CFBDTeamRecordsDTO]] = [:]
    private var recordsByYear: [Int: [Int: String]] = [:]
    private var ranksByKey: [String: [Int: Int]] = [:]

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - ScoresProviding

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?) async throws -> Scoreboard {
        let season = year ?? CFBSeason.year()
        let slots = try await weekSlots(year: season)
        let currentSlot = CFBDMapper.currentSlot(in: slots)

        let targetValue = weekValue ?? currentSlot?.value
        let targetType = seasonType ?? currentSlot?.seasonType ?? 2
        let typeName = CFBDMapper.seasonTypeName(targetType)

        let query = [
            URLQueryItem(name: "year", value: String(season)),
            URLQueryItem(name: "seasonType", value: typeName),
            URLQueryItem(name: "classification", value: "fbs"),
        ] + (targetValue.map { [URLQueryItem(name: "week", value: String($0))] } ?? [])

        async let gamesFetch: LossyArray<CFBDGameDTO> = fetch("/games", query: query)
        async let mediaFetch: LossyArray<CFBDGameMediaDTO> = fetch("/games/media", query: query)

        let joins = try await joins(year: season, week: targetValue, seasonType: targetType)
        let games = try await gamesFetch.elements
        let media = ((try? await mediaFetch.elements) ?? [])

        // Live enrichment only makes sense for the week that's actually on;
        // /scoreboard has no week parameter.
        var live: [Int: CFBDScoreboardGameDTO] = [:]
        if targetValue == currentSlot?.value, targetType == currentSlot?.seasonType {
            let board: LossyArray<CFBDScoreboardGameDTO>? = try? await fetch(
                "/scoreboard", query: [URLQueryItem(name: "classification", value: "fbs")]
            )
            for game in board?.elements ?? [] {
                if let id = game.id { live[id] = game }
            }
        }

        return Scoreboard(
            seasonYear: season,
            seasonType: currentSlot?.seasonType,
            currentWeekNumber: currentSlot?.value,
            weeks: slots,
            games: games.compactMap {
                CFBDMapper.game(from: $0, live: live[$0.id ?? -1], media: media, joins: joins)
            }
        )
    }

    func rankings() async throws -> [Poll] {
        let season = CFBSeason.year()
        let weeks: LossyArray<CFBDPollWeekDTO> = try await fetch(
            "/rankings", query: [URLQueryItem(name: "year", value: String(season))]
        )
        let joins = try await joins(year: season, week: nil, seasonType: nil)
        return CFBDMapper.polls(from: weeks.elements, season: season, joins: joins)
    }

    func fbsConferences() async throws -> [ConferenceTeams] {
        let teams = try await teams(year: CFBSeason.year())
        return CFBDMapper.conferences(from: teams)
    }

    func conferenceStandings() async throws -> [ConferenceStandings] {
        let season = CFBSeason.year()
        let teams = try await teams(year: season)
        let records = await recordDTOs(year: season)
        return CFBDMapper.conferenceStandings(from: teams, records: records)
    }

    func teamSchedule(teamId: String) async throws -> TeamSchedule {
        let season = CFBSeason.year()
        let teams = try await teams(year: season)
        guard let id = Int(teamId),
              let meta = teams.first(where: { $0.id == id }),
              let school = meta.school
        else { throw CFBDError.unknownTeam(teamId) }

        let games: LossyArray<CFBDGameDTO> = try await fetch("/games", query: [
            URLQueryItem(name: "year", value: String(season)),
            URLQueryItem(name: "team", value: school),
            URLQueryItem(name: "seasonType", value: "both"),
        ])
        let joins = try await joins(year: season, week: nil, seasonType: nil)
        return CFBDMapper.teamSchedule(team: meta, games: games.elements, joins: joins)
    }

    func gameSummary(eventId: String) async throws -> GameSummary {
        guard let id = Int(eventId) else { throw CFBDError.gameNotFound(eventId) }
        let games: LossyArray<CFBDGameDTO> = try await fetch(
            "/games", query: [URLQueryItem(name: "id", value: eventId)]
        )
        guard let game = games.elements.first else { throw CFBDError.gameNotFound(eventId) }
        let season = game.season ?? CFBSeason.year()

        let idQuery = [URLQueryItem(name: "id", value: eventId)]
        async let statsFetch: LossyArray<CFBDGameTeamStatsDTO> = fetch("/games/teams", query: idQuery)
        async let playersFetch: LossyArray<CFBDGamePlayerStatsDTO> = fetch("/games/players", query: idQuery)

        // /drives has no game filter; narrow by the home team's week and pick
        // out our game. Optional join — a miss drops the section, not the screen.
        var drives: [CFBDDriveDTO] = []
        if let school = game.homeTeam, let week = game.week {
            var driveQuery = [
                URLQueryItem(name: "year", value: String(season)),
                URLQueryItem(name: "week", value: String(week)),
                URLQueryItem(name: "team", value: school),
            ]
            if let type = game.seasonType {
                driveQuery.append(URLQueryItem(name: "seasonType", value: type))
            }
            let fetched: LossyArray<CFBDDriveDTO>? = try? await fetch("/drives", query: driveQuery)
            drives = (fetched?.elements ?? []).filter { $0.gameId == id }
        }

        var live: CFBDScoreboardGameDTO?
        if game.completed != true {
            let board: LossyArray<CFBDScoreboardGameDTO>? = try? await fetch(
                "/scoreboard", query: [URLQueryItem(name: "classification", value: "fbs")]
            )
            live = board?.elements.first { $0.id == id }
        }

        let joins = try await joins(year: season, week: game.week, seasonType: CFBDMapper.seasonTypeValue(game.seasonType))
        let stats = (try? await statsFetch.elements) ?? []
        let players = (try? await playersFetch.elements) ?? []

        return CFBDMapper.gameSummary(
            game: game, live: live,
            stats: stats.first { $0.id == id },
            players: players.first { $0.id == id },
            drives: drives, joins: joins
        )
    }

    // MARK: - Cached joins

    private func weekSlots(year: Int) async throws -> [WeekSlot] {
        if let cached = calendarByYear[year] { return cached }
        let weeks: LossyArray<CFBDCalendarWeekDTO> = try await fetch(
            "/calendar", query: [URLQueryItem(name: "year", value: String(year))]
        )
        let slots = CFBDMapper.weekSlots(from: weeks.elements)
        calendarByYear[year] = slots
        return slots
    }

    private func teams(year: Int) async throws -> [CFBDTeamDTO] {
        if let cached = teamsByYear[year] { return cached }
        let teams: LossyArray<CFBDTeamDTO> = try await fetch(
            "/teams/fbs", query: [URLQueryItem(name: "year", value: String(year))]
        )
        teamsByYear[year] = teams.elements
        return teams.elements
    }

    private func recordDTOs(year: Int) async -> [CFBDTeamRecordsDTO] {
        if let cached = recordDTOsByYear[year] { return cached }
        let fetched: LossyArray<CFBDTeamRecordsDTO>? = try? await fetch(
            "/records", query: [URLQueryItem(name: "year", value: String(year))]
        )
        let records = fetched?.elements ?? []
        recordDTOsByYear[year] = records
        return records
    }

    private func records(year: Int) async -> [Int: String] {
        if let cached = recordsByYear[year] { return cached }
        let records = CFBDMapper.recordsById(from: await recordDTOs(year: year))
        recordsByYear[year] = records
        return records
    }

    /// Rank badges for a specific week (historical weeks keep their
    /// contemporaneous poll). Nil week means the latest available.
    private func ranks(year: Int, week: Int?, seasonType: Int?) async -> [Int: Int] {
        let key = "\(year)-\(seasonType ?? 0)-\(week ?? -1)"
        if let cached = ranksByKey[key] { return cached }
        var query = [URLQueryItem(name: "year", value: String(year))]
        if let week {
            query.append(URLQueryItem(name: "week", value: String(week)))
            if let seasonType {
                query.append(URLQueryItem(name: "seasonType", value: CFBDMapper.seasonTypeName(seasonType)))
            }
        }
        let fetched: LossyArray<CFBDPollWeekDTO>? = try? await fetch("/rankings", query: query)
        let ranks = CFBDMapper.rankBadges(from: fetched?.elements ?? [], week: week)
        ranksByKey[key] = ranks
        return ranks
    }

    private func joins(year: Int, week: Int?, seasonType: Int?) async throws -> CFBDJoins {
        let teams = try await teams(year: year)
        async let records = records(year: year)
        async let ranks = ranks(year: year, week: week, seasonType: seasonType)
        return await CFBDJoins(teams: teams, records: records, ranks: ranks)
    }

    // MARK: - Transport

    private func fetch<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(string: Self.base + path) else {
            throw CFBDError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else { throw CFBDError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw CFBDError.badStatus(http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }
}

/// The season-scoped lookups a CFBD game row needs but doesn't carry.
nonisolated struct CFBDJoins {
    let byId: [Int: CFBDTeamDTO]
    let bySchool: [String: CFBDTeamDTO]
    let records: [Int: String]
    let ranks: [Int: Int]

    init(teams: [CFBDTeamDTO], records: [Int: String], ranks: [Int: Int]) {
        var byId: [Int: CFBDTeamDTO] = [:]
        var bySchool: [String: CFBDTeamDTO] = [:]
        for team in teams {
            if let id = team.id { byId[id] = team }
            if let school = team.school { bySchool[school] = team }
        }
        self.byId = byId
        self.bySchool = bySchool
        self.records = records
        self.ranks = ranks
    }
}
