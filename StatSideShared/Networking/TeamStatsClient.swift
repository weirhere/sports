import Foundation

/// A team's season stats and its statistical leaders.
///
/// **Two hosts, both chosen.** The stats come from `site.web.api.espn.com`,
/// because the same path on `site.api.espn.com` 403s by User-Agent behind
/// Akamai (found 2026-09-24, the same day and for the same reason as
/// `PlayerStatsClient`). The leaders come from the core API, the only place
/// ESPN publishes them per team; it links each athlete as a `$ref` rather
/// than naming them, so a leader arrives as an id and the page resolves it.
///
/// Same shape as the player clients: a plain struct, `@concurrent`, and
/// `.empty` on any failure — the Overview cards hide rather than apologise.
nonisolated struct TeamStatsClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    @concurrent
    func stats(teamId: String, league: League) async -> TeamSeasonStats {
        let string = "https://site.web.api.espn.com/apis/site/v2/sports/"
            + "\(league.sportSegment)/\(league.pathSegment)/teams/\(teamId)/statistics"
        guard let url = URL(string: string),
              let (data, _) = try? await session.data(from: url),
              let dto = try? JSONDecoder().decode(TeamStatsResponseDTO.self, from: data)
        else { return .empty }
        return TeamStatsMapper.stats(from: dto, league: league)
    }

    /// The regular season's leaders for ESPN season `season`, falling back
    /// one season when it has none yet — an NBA team in September has no
    /// 2026-27 leaders, and last season's are the ones worth showing. The
    /// season answered is returned so the card can say which it is.
    @concurrent
    func leaders(teamId: String, league: League, season: Int) async -> (leaders: [TeamLeader], season: Int?) {
        for year in [season, season - 1] {
            let leaders = await fetchLeaders(teamId: teamId, league: league, season: year)
            if !leaders.isEmpty { return (leaders, year) }
        }
        return ([], nil)
    }

    private func fetchLeaders(teamId: String, league: League, season: Int) async -> [TeamLeader] {
        let string = "https://sports.core.api.espn.com/v2/sports/\(league.sportSegment)/leagues/"
            + "\(league.pathSegment)/seasons/\(season)/types/2/teams/\(teamId)/leaders"
        guard let url = URL(string: string),
              let (data, _) = try? await session.data(from: url),
              let dto = try? JSONDecoder().decode(TeamLeadersDTO.self, from: data)
        else { return [] }
        return TeamStatsMapper.leaders(from: dto, league: league)
    }

    /// A name and a headshot for an athlete the roster couldn't place — a
    /// player traded away since the season the leaders describe. One small
    /// request each, only for the few rows the card shows.
    @concurrent
    func athlete(id: String, league: League, season: Int) async -> (name: String, headshot: URL?)? {
        let string = "https://sports.core.api.espn.com/v2/sports/\(league.sportSegment)/leagues/"
            + "\(league.pathSegment)/seasons/\(season)/athletes/\(id)"
        guard let url = URL(string: string),
              let (data, _) = try? await session.data(from: url),
              let dto = try? JSONDecoder().decode(CoreAthleteDTO.self, from: data),
              let name = dto.displayName ?? dto.fullName
        else { return nil }
        return (name, dto.headshot?.href.flatMap(URL.init(string:)))
    }
}

// MARK: - Mapping

nonisolated enum TeamStatsMapper {
    static func stats(from dto: TeamStatsResponseDTO, league: League) -> TeamSeasonStats {
        let own = categories(dto.results?.stats?.categories)
        let opponent = categories(dto.results?.opponent)
        let label = seasonLabel(season: dto.season, league: league,
                                gamesPlayed: gamesPlayed(in: own))
        // A preseason answer with no real season behind it — see below.
        guard let label else { return .empty }
        return TeamSeasonStats(seasonLabel: label, categories: own, opponent: opponent)
    }

    /// Which season these numbers are, or nil for numbers not worth showing.
    ///
    /// ESPN's own label can't be trusted across a rollover (verified
    /// 2026-09-24): in September the NBA and NHL answer with a season named
    /// "2026-27 Preseason" whose numbers are all of **last** season — 82
    /// games played. So a preseason answer with a full season's games is
    /// labelled as the season it actually is, and one without (a real
    /// preseason, a handful of exhibition games) is not shown at all.
    static func seasonLabel(season: TeamStatsSeasonDTO?, league: League, gamesPlayed: Int?) -> String? {
        guard let year = season?.year else { return nil }
        let appYear = league.seasonYear(fromESPN: year)
        guard season?.type == 1 else { return league.seasonLabel(appYear) }
        guard let gamesPlayed, gamesPlayed >= 20 else { return nil }
        return league.seasonLabel(appYear - 1)
    }

    private static func gamesPlayed(in categories: [TeamSeasonStats.Category]) -> Int? {
        for name in ["gamesPlayed", "games", "teamGamesPlayed"] {
            for category in categories {
                if let stat = category.stats.first(where: { $0.name == name }),
                   let value = Int(stat.value) { return value }
            }
        }
        return nil
    }

    private static func categories(_ dtos: [TeamStatsCategoryDTO]?) -> [TeamSeasonStats.Category] {
        (dtos ?? []).compactMap { dto -> TeamSeasonStats.Category? in
            guard let id = dto.name else { return nil }
            var seen: Set<String> = []
            let stats = (dto.stats ?? []).compactMap { stat -> TeamSeasonStats.Stat? in
                guard let name = stat.name, let value = stat.displayValue,
                      // ESPN repeats a stat inside one category
                      // (`receivingYards` twice) — once is the fact.
                      seen.insert(name).inserted else { return nil }
                let short = stat.shortDisplayName.flatMap { $0.count <= 6 ? $0 : nil }
                return TeamSeasonStats.Stat(
                    name: name,
                    label: short ?? stat.abbreviation ?? name,
                    fullName: stat.displayName ?? stat.abbreviation ?? name,
                    value: value,
                    rank: stat.rankDisplayValue.flatMap { $0.isEmpty ? nil : $0 })
            }
            guard !stats.isEmpty else { return nil }
            return TeamSeasonStats.Category(id: id, title: dto.displayName ?? id, stats: stats)
        }
    }

    static func leaders(from dto: TeamLeadersDTO, league: League) -> [TeamLeader] {
        let byName = Dictionary((dto.categories ?? []).compactMap { category in
            category.name.map { ($0, category) }
        }, uniquingKeysWith: { first, _ in first })
        return TeamLeader.categories(for: league).compactMap { name -> TeamLeader? in
            guard let category = byName[name],
                  let top = category.leaders?.first,
                  let ref = top.athlete?.ref,
                  let athleteId = athleteId(fromRef: ref),
                  let value = top.displayValue
            else { return nil }
            return TeamLeader(category: name,
                              title: TeamLeader.title(for: category.displayName ?? name),
                              athleteId: athleteId,
                              value: value)
        }
    }

    /// ".../seasons/2026/athletes/3139477?lang=en" → "3139477".
    static func athleteId(fromRef ref: String) -> String? {
        guard let range = ref.range(of: "/athletes/") else { return nil }
        let id = ref[range.upperBound...].prefix { $0.isNumber }
        return id.isEmpty ? nil : String(id)
    }
}

// MARK: - DTOs

nonisolated struct TeamStatsResponseDTO: Decodable {
    let season: TeamStatsSeasonDTO?
    let results: TeamStatsResultsDTO?
}

nonisolated struct TeamStatsSeasonDTO: Decodable {
    let year: Int?
    let type: Int?
}

nonisolated struct TeamStatsResultsDTO: Decodable {
    let stats: TeamStatsBlockDTO?
    let opponent: [TeamStatsCategoryDTO]?
}

nonisolated struct TeamStatsBlockDTO: Decodable {
    let categories: [TeamStatsCategoryDTO]?
}

nonisolated struct TeamStatsCategoryDTO: Decodable {
    let name: String?
    let displayName: String?
    let stats: [TeamStatDTO]?
}

nonisolated struct TeamStatDTO: Decodable {
    let name: String?
    let displayName: String?
    let shortDisplayName: String?
    let abbreviation: String?
    let displayValue: String?
    let rankDisplayValue: String?
}

nonisolated struct TeamLeadersDTO: Decodable {
    let categories: [TeamLeaderCategoryDTO]?
}

nonisolated struct TeamLeaderCategoryDTO: Decodable {
    let name: String?
    let displayName: String?
    let leaders: [TeamLeaderEntryDTO]?
}

nonisolated struct TeamLeaderEntryDTO: Decodable {
    let displayValue: String?
    let athlete: CoreRefDTO?
}

nonisolated struct CoreAthleteDTO: Decodable {
    let displayName: String?
    let fullName: String?
    let headshot: CoreHeadshotDTO?
}

nonisolated struct CoreHeadshotDTO: Decodable {
    let href: String?
}
