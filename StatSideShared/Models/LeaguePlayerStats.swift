import Foundation

/// A league's players and their season numbers, from ESPN's `byathlete`
/// endpoint — the Player stats tab beside Team stats (2026-10-26).
///
/// **Pools, not one table.** `byathlete` answers one sorted, qualified slice
/// of the league per request: sort by passing yards and you get the passers
/// ESPN counts as qualified, which is what keeps a 1-for-1 shooter off the
/// top of field-goal percentage. So each card names the pool it ranks
/// within (`PlayerStatQuery`), and a pool is fetched once however many cards
/// read it. The values are ESPN's; the ranks are recomputed within a page's
/// teams, Team stats' rule.
nonisolated struct LeaguePlayerStats: Sendable, Hashable {
    let league: League
    /// Each query's players, in ESPN's order.
    let pools: [PlayerStatQuery: [PlayerStatLine]]

    static func empty(_ league: League) -> LeaguePlayerStats {
        LeaguePlayerStats(league: league, pools: [:])
    }

    /// Every player across the pools — for scoping, and for swapping in the
    /// page's richer team identities.
    var lines: [PlayerStatLine] { pools.values.flatMap { $0 } }

    /// A preseason answer: nobody has played a game yet.
    var hasPlayed: Bool {
        lines.contains { ($0.gamesPlayed ?? 0) > 0 }
    }

    /// The same players wearing the team identities a page already holds:
    /// `byathlete` names a team by nickname and abbreviation only.
    func resolvingTeams(_ known: [Team]) -> LeaguePlayerStats {
        guard !known.isEmpty else { return self }
        let byId = Dictionary(known.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return LeaguePlayerStats(league: league, pools: pools.mapValues { lines in
            lines.map { line in
                guard let team = byId[line.player.team.id] else { return line }
                return PlayerStatLine(player: line.player.with(team: team), values: line.values)
            }
        })
    }

    /// One card's table: its pool, narrowed to the page's teams, best
    /// first. A player under the card's minimum (a goalie who has faced 40
    /// shots) or without the number is left out. Ties share a rank.
    func ranking(for definition: PlayerStatDefinition, among teamIds: Set<String>? = nil) -> PlayerStatRanking {
        let valued: [(player: LeaguePlayer, value: Double)] = (pools[definition.query] ?? []).compactMap { line in
            if let teamIds, !teamIds.contains(line.player.team.id) { return nil }
            if let minimum = definition.minimum,
               (line.values[minimum.key] ?? 0) < minimum.value { return nil }
            guard let value = line.values[definition.key] else { return nil }
            return (line.player, value)
        }
        let sorted = valued.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return definition.higherIsBetter ? lhs.value > rhs.value : lhs.value < rhs.value
            }
            return lhs.player.name < rhs.player.name
        }
        var rows: [PlayerStatRanking.Row] = []
        for (index, entry) in sorted.enumerated() {
            let rank = index > 0 && sorted[index - 1].value == entry.value
                ? rows[index - 1].rank
                : index + 1
            rows.append(PlayerStatRanking.Row(rank: rank, player: entry.player, value: entry.value,
                                              display: definition.format.string(entry.value)))
        }
        return PlayerStatRanking(definition: definition, rows: rows)
    }

    /// Every card a page can draw, in registry order, empty ones dropped.
    func rankings(among teamIds: Set<String>? = nil) -> [PlayerStatRanking] {
        league.playerStatDefinitions
            .map { ranking(for: $0, among: teamIds) }
            .filter { !$0.rows.isEmpty }
    }
}

/// A player as the stat tables know them: enough to draw a row and open
/// their page.
nonisolated struct LeaguePlayer: Sendable, Hashable, Identifiable {
    let athleteId: String
    let name: String
    let headshotURL: URL?
    /// "QB", "C".
    let position: String?
    let team: Team
    let league: League

    var id: String { "\(league.rawValue)-\(athleteId)" }

    func with(team: Team) -> LeaguePlayer {
        LeaguePlayer(athleteId: athleteId, name: name, headshotURL: headshotURL,
                     position: position, team: team, league: league)
    }

    /// The player page's door.
    var identity: PlayerIdentity {
        PlayerIdentity(athleteId: athleteId, name: name, league: league,
                       teamName: team.displayName ?? team.location,
                       teamLogoURL: team.logoURL, team: team,
                       position: position, headshotURL: headshotURL)
    }
}

/// One player's flattened numbers.
nonisolated struct PlayerStatLine: Sendable, Hashable {
    let player: LeaguePlayer
    let values: [PlayerStatKey: Double]

    var gamesPlayed: Double? {
        values[PlayerStatKey("general", "gamesPlayed")] ?? values[PlayerStatKey("general", "games")]
    }
}

/// A number in a `byathlete` payload: its category and name.
nonisolated struct PlayerStatKey: Sendable, Hashable {
    let category: String
    let name: String

    init(_ category: String, _ name: String) {
        self.category = category
        self.name = name
    }
}

/// One `byathlete` request: the slice of the league it answers.
///
/// College football needs `category` — without it every value but games
/// played comes back null, though the order is right (verified 2026-10-26);
/// the NFL fills everything either way and the NBA and NHL take none.
nonisolated struct PlayerStatQuery: Sendable, Hashable {
    /// "offense:rushing", "defense", "specialTeams:kicking".
    let category: String?
    /// ESPN's sort key, as its own stats pages spell it:
    /// "rushing.rushingYards", "defensiveInterceptions.interceptions".
    let sort: String
    /// How many to ask for. Enough that a conference's or a Top 25's
    /// leaders are inside the league-wide slice.
    let limit: Int
}

/// One card on the Player stats tab.
nonisolated struct PlayerStatDefinition: Sendable, Hashable, Identifiable {
    enum Section: Int, Sendable, Hashable, CaseIterable {
        case top, passing, rushing, receiving, shooting, allAround, scoring, defense, goaltending, specialTeams, discipline

        var title: String {
            switch self {
            case .top: "Top stats"
            case .passing: "Passing"
            case .rushing: "Rushing"
            case .receiving: "Receiving"
            case .shooting: "Shooting"
            case .allAround: "All-around"
            case .scoring: "Scoring"
            case .defense: "Defense"
            case .goaltending: "Goaltending"
            case .specialTeams: "Special teams"
            case .discipline: "Discipline"
            }
        }
    }

    struct Minimum: Sendable, Hashable {
        let key: PlayerStatKey
        let value: Double
    }

    let id: String
    let title: String
    let section: Section
    /// The pool this card ranks within.
    let query: PlayerStatQuery
    /// The number it ranks on — not always the pool's sort: a goalie's
    /// goals-against average ranks within the save-percentage pool, since
    /// ESPN's own GAA sort leads with skaters at 0.00.
    let key: PlayerStatKey
    let higherIsBetter: Bool
    let format: TeamStatDefinition.Format
    var minimum: Minimum? = nil
}

/// A stat's whole player table, already ranked.
nonisolated struct PlayerStatRanking: Sendable, Hashable, Identifiable {
    struct Row: Sendable, Hashable, Identifiable {
        let rank: Int
        let player: LeaguePlayer
        let value: Double
        let display: String
        var id: String { player.id }
    }

    let definition: PlayerStatDefinition
    let rows: [Row]
    var id: String { definition.id }
}
