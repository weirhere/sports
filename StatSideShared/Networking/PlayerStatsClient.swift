import Foundation

/// A player's numbers: season-by-season stats and a season's game log.
///
/// **The host is `site.web.api.espn.com`, deliberately.** E20's go/no-go sat
/// unanswered for a week because no session could reach ESPN, and when it
/// finally ran (2026-09-24) the answer was that `site.api.espn.com` — the
/// host the rest of the app uses — puts its athlete and stats paths behind
/// an Akamai rule that 403s by User-Agent, and has no `/athletes/{id}` at
/// all. The same data answers 200 from `site.web.api`'s `common/v3` tree in
/// all four leagues, the tree `AthleteProfileClient` already reads.
///
/// Same shape as `AthleteProfileClient`: a plain struct the player page
/// calls directly, `@concurrent` so the request and the decode stay off the
/// main thread. Any failure answers `.empty`, and the page hides what it
/// can't fill rather than apologising for it.
nonisolated struct PlayerStatsClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func base(_ league: League, _ athleteId: String) -> String {
        "https://site.web.api.espn.com/apis/common/v3/sports/"
            + "\(league.sportSegment)/\(league.pathSegment)/athletes/\(athleteId)"
    }

    /// Every season the player has a line for, plus ESPN's career totals.
    @concurrent
    func stats(athleteId: String, league: League) async -> PlayerStats {
        guard let url = URL(string: base(league, athleteId) + "/stats"),
              let (data, _) = try? await session.data(from: url),
              let dto = try? JSONDecoder().decode(PlayerStatsDTO.self, from: data)
        else { return .empty }
        return PlayerStatsMapper.stats(from: dto)
    }

    /// One season's games. `season` is ESPN's year — the ending year for
    /// basketball and hockey; nil asks for ESPN's current one.
    @concurrent
    func gameLog(athleteId: String, league: League, season: Int?) async -> PlayerGameLog {
        var string = base(league, athleteId) + "/gamelog"
        if let season { string += "?season=\(season)" }
        guard let url = URL(string: string),
              let (data, _) = try? await session.data(from: url),
              let dto = try? JSONDecoder().decode(PlayerGameLogDTO.self, from: data)
        else { return .empty }
        return PlayerStatsMapper.gameLog(from: dto)
    }
}

// MARK: - Mapping

nonisolated enum PlayerStatsMapper {
    static func stats(from dto: PlayerStatsDTO) -> PlayerStats {
        let teamNames = (dto.teams ?? [:]).reduce(into: [String: String]()) { names, entry in
            if let id = entry.value.id?.value, let name = entry.value.displayName {
                names[id] = name
            }
        }
        let categories = (dto.categories ?? []).compactMap { group -> PlayerStats.Category? in
            let labels = group.labels ?? []
            guard let id = group.name, !labels.isEmpty else { return nil }
            let seasons = (group.statistics ?? []).compactMap { row -> PlayerStats.SeasonLine? in
                // A row that doesn't match the header would put every number
                // under the wrong column — the box score's rule.
                guard let year = row.season?.year, let values = row.stats,
                      values.count == labels.count else { return nil }
                let teamId = row.teamId?.value
                return PlayerStats.SeasonLine(year: year,
                                              label: row.season?.displayName ?? String(year),
                                              teamId: teamId,
                                              teamName: teamId.flatMap { teamNames[$0] },
                                              position: row.position,
                                              values: values)
            }
            guard !seasons.isEmpty else { return nil }
            let career = group.totals ?? []
            return PlayerStats.Category(id: id,
                                        title: group.displayName ?? id,
                                        labels: labels,
                                        names: group.names ?? [],
                                        displayNames: group.displayNames ?? [],
                                        seasons: seasons,
                                        career: career.count == labels.count ? career : [])
        }
        return PlayerStats(categories: categories)
    }

    static func gameLog(from dto: PlayerGameLogDTO) -> PlayerGameLog {
        let labels = dto.labels ?? []
        let events = dto.events ?? [:]
        let sections = (dto.seasonTypes ?? []).compactMap { type -> PlayerGameLog.Section? in
            let entries = (type.categories ?? [])
                .filter { $0.type == nil || $0.type == "event" }
                .flatMap { $0.events ?? [] }
                .compactMap { row -> PlayerGameLog.Entry? in
                    guard let eventId = row.eventId, let values = row.stats,
                          values.count == labels.count else { return nil }
                    return entry(eventId: eventId, values: values, event: events[eventId])
                }
            guard !entries.isEmpty else { return nil }
            return PlayerGameLog.Section(title: type.displayName ?? "Games", entries: entries)
        }
        let seasonFilter = dto.filters?.first { $0.name == "season" }
        return PlayerGameLog(
            labels: labels,
            names: dto.names ?? [],
            groups: (dto.categories ?? []).compactMap { group in
                guard let count = group.count, count > 0 else { return nil }
                return PlayerGameLog.ColumnGroup(title: group.displayName ?? group.name ?? "", count: count)
            },
            sections: sections,
            availableSeasons: (seasonFilter?.options ?? []).compactMap { $0.value.flatMap(Int.init) },
            season: seasonFilter?.value.flatMap(Int.init))
    }

    private static func entry(eventId: String, values: [String],
                              event: GameLogEventDTO?) -> PlayerGameLog.Entry {
        let isAway = event?.atVs == "@"
        let home = event?.homeTeamScore
        let away = event?.awayTeamScore
        return PlayerGameLog.Entry(
            eventId: eventId,
            date: event?.gameDate.flatMap(parseDate),
            week: event?.week,
            isAway: isAway,
            opponentId: event?.opponent?.id?.value,
            opponentAbbreviation: event?.opponent?.abbreviation,
            opponentName: event?.opponent?.displayName,
            opponentLogoURL: event?.opponent?.logo.flatMap(URL.init(string:)),
            teamId: event?.team?.id?.value,
            teamAbbreviation: event?.team?.abbreviation,
            teamLogoURL: event?.team?.logo.flatMap(URL.init(string:)),
            result: event?.gameResult.flatMap { $0.isEmpty ? nil : $0 },
            teamScore: isAway ? away : home,
            opponentScore: isAway ? home : away,
            note: event?.eventNote.flatMap { $0.isEmpty ? nil : $0 },
            values: values)
    }

    /// "2026-09-21T00:20:00.000+00:00" — fractional seconds and an offset,
    /// neither of which `ESPNDate`'s scoreboard formats expect.
    private static func parseDate(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string) ?? ESPNDate.parse(string)
    }
}

// MARK: - DTOs

/// An id ESPN sends as a string in one payload and a number in the next.
nonisolated struct FlexibleID: Decodable, Sendable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = String(try container.decode(Int.self))
        }
    }
}

nonisolated struct PlayerStatsDTO: Decodable {
    let teams: [String: StatsTeamDTO]?
    let categories: [StatsCategoryDTO]?
}

nonisolated struct StatsTeamDTO: Decodable {
    let id: FlexibleID?
    let displayName: String?
}

nonisolated struct StatsCategoryDTO: Decodable {
    let name: String?
    let displayName: String?
    let labels: [String]?
    let names: [String]?
    let displayNames: [String]?
    let statistics: [StatsSeasonRowDTO]?
    let totals: [String]?
}

nonisolated struct StatsSeasonRowDTO: Decodable {
    let teamId: FlexibleID?
    let season: StatsSeasonDTO?
    let stats: [String]?
    let position: String?
}

nonisolated struct StatsSeasonDTO: Decodable {
    let year: Int?
    let displayName: String?
}

nonisolated struct PlayerGameLogDTO: Decodable {
    let labels: [String]?
    let names: [String]?
    let categories: [GameLogGroupDTO]?
    let filters: [GameLogFilterDTO]?
    let events: [String: GameLogEventDTO]?
    let seasonTypes: [GameLogSeasonTypeDTO]?
}

nonisolated struct GameLogGroupDTO: Decodable {
    let name: String?
    let displayName: String?
    let count: Int?
}

nonisolated struct GameLogFilterDTO: Decodable {
    let name: String?
    let value: String?
    let options: [GameLogFilterOptionDTO]?
}

nonisolated struct GameLogFilterOptionDTO: Decodable {
    let value: String?
}

nonisolated struct GameLogEventDTO: Decodable {
    let week: Int?
    let atVs: String?
    let gameDate: String?
    let homeTeamScore: String?
    let awayTeamScore: String?
    let gameResult: String?
    let eventNote: String?
    let opponent: GameLogOpponentDTO?
    /// The player's own side — id, abbreviation and mark.
    let team: GameLogOpponentDTO?
}

nonisolated struct GameLogOpponentDTO: Decodable {
    let id: FlexibleID?
    let abbreviation: String?
    let displayName: String?
    let logo: String?
}

nonisolated struct GameLogSeasonTypeDTO: Decodable {
    let displayName: String?
    let categories: [GameLogSeasonCategoryDTO]?
}

nonisolated struct GameLogSeasonCategoryDTO: Decodable {
    let displayName: String?
    let type: String?
    let events: [GameLogRowDTO]?
}

nonisolated struct GameLogRowDTO: Decodable {
    let eventId: String?
    let stats: [String]?
}
