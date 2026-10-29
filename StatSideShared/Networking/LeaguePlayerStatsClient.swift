import Foundation

/// A league's player pools for the Player stats tab (2026-10-26): one
/// `byathlete` request per pool the league's cards name, all at once.
///
/// `site.web.api` for `TeamStatsClient`'s reason (`site.api` 403s by
/// User-Agent on the stats paths). A request is ~55 KB on the wire per 100
/// players — the JSON is fourteen times that, every athlete carrying every
/// category and a page of links, which is why the pools are sized per
/// league rather than asking for everyone.
///
/// A pool that fails just hides its cards; only a tab with no pools at
/// all is an error.
nonisolated struct LeaguePlayerStatsClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    @concurrent
    func stats(league: League, season: Int) async throws -> LeaguePlayerStats {
        let queries = Array(Set(league.playerStatDefinitions.map(\.query)))
        let results = await withTaskGroup(of: (PlayerStatQuery, [PlayerStatLine]?).self) { group in
            for query in queries {
                group.addTask {
                    (query, try? await pool(query, league: league, season: season))
                }
            }
            var results: [(PlayerStatQuery, [PlayerStatLine]?)] = []
            for await result in group { results.append(result) }
            return results
        }
        var pools: [PlayerStatQuery: [PlayerStatLine]] = [:]
        for case let (query, lines?) in results { pools[query] = lines }
        guard !pools.isEmpty || queries.isEmpty else { throw URLError(.cannotLoadFromNetwork) }
        return LeaguePlayerStats(league: league, pools: pools)
    }

    private func pool(_ query: PlayerStatQuery, league: League, season: Int) async throws -> [PlayerStatLine] {
        var components = URLComponents(string: "https://site.web.api.espn.com/apis/common/v3/sports/"
            + "\(league.sportSegment)/\(league.pathSegment)/statistics/byathlete")
        var items = [
            URLQueryItem(name: "region", value: "us"),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "contentorigin", value: "espn"),
            URLQueryItem(name: "season", value: String(season)),
            URLQueryItem(name: "seasontype", value: "2"),
            URLQueryItem(name: "limit", value: String(query.limit)),
            // Always descending: the pool is "the league's most", and a
            // lower-is-better card ranks inside it the other way.
            URLQueryItem(name: "sort", value: "\(query.sort):desc"),
        ]
        if let category = query.category {
            items.append(URLQueryItem(name: "category", value: category))
        }
        components?.queryItems = items
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        let dto = try JSONDecoder().decode(ByAthleteResponseDTO.self, from: data)
        return LeaguePlayerStatsMapper.lines(from: dto, league: league)
    }
}

// MARK: - Mapping

/// `byteam`'s positional shape again: a player's blocks carry values only,
/// named by the top-level categories (`LeagueTeamStatsMapper`'s rule, first
/// name wins).
nonisolated enum LeaguePlayerStatsMapper {
    static func lines(from dto: ByAthleteResponseDTO, league: League) -> [PlayerStatLine] {
        var names: [String: [String]] = [:]
        for category in dto.categories ?? [] {
            guard let name = category.name, let list = category.names, !list.isEmpty,
                  names[name] == nil else { continue }
            names[name] = list
        }
        return (dto.athletes ?? []).compactMap { entry -> PlayerStatLine? in
            guard let player = player(from: entry.athlete, league: league) else { return nil }
            var values: [PlayerStatKey: Double] = [:]
            for block in entry.categories ?? [] {
                guard let category = block.name, let list = names[category] else { continue }
                for (name, value) in zip(list, block.values ?? []) {
                    guard let value else { continue }
                    let key = PlayerStatKey(category, name)
                    if values[key] == nil { values[key] = value }
                }
            }
            return PlayerStatLine(player: player, values: values)
        }
    }

    /// The athlete's team is a nickname ("Hurricanes"), an abbreviation and
    /// a logo — the abbreviation stands in for the location until a page
    /// swaps in its own identity (`LeaguePlayerStats.resolvingTeams`).
    static func player(from dto: ByAthleteAthleteDTO?, league: League) -> LeaguePlayer? {
        guard let dto, let id = dto.id, let name = dto.displayName ?? dto.shortName,
              let teamId = dto.teamId else { return nil }
        let team = Team(id: teamId, location: dto.teamShortName ?? dto.teamName ?? "—",
                        name: dto.teamName, abbreviation: dto.teamShortName,
                        displayName: nil, shortDisplayName: dto.teamName,
                        logoURL: dto.teamLogos?.first?.href.flatMap(URL.init(string:)),
                        conferenceId: Conference.division(forTeamId: teamId, in: league),
                        league: league)
        return LeaguePlayer(athleteId: id, name: name,
                            headshotURL: dto.headshot?.href.flatMap(URL.init(string:)),
                            position: dto.position?.abbreviation, team: team, league: league)
    }
}

// MARK: - DTOs

nonisolated struct ByAthleteResponseDTO: Decodable {
    let categories: [ByTeamCategoryDTO]?
    let athletes: [ByAthleteEntryDTO]?
}

nonisolated struct ByAthleteEntryDTO: Decodable {
    let athlete: ByAthleteAthleteDTO?
    let categories: [ByTeamCategoryDTO]?
}

nonisolated struct ByAthleteAthleteDTO: Decodable {
    let id: String?
    let displayName: String?
    let shortName: String?
    let headshot: CoreHeadshotDTO?
    let position: ByAthletePositionDTO?
    let teamId: String?
    let teamName: String?
    let teamShortName: String?
    let teamLogos: [LogoDTO]?
}

nonisolated struct ByAthletePositionDTO: Decodable {
    let abbreviation: String?
}
