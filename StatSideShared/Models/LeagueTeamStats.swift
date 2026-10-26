import Foundation

/// Every team in a league with its season numbers, from ESPN's `byteam`
/// endpoint — one request for the whole league, which is what lets a
/// league page rank its teams FotMob's way (2026-10-25).
///
/// Each team's numbers are flattened into one keyed table. The values are
/// ESPN's own; the ranks are not — `ranking(for:among:)` recomputes them,
/// because ESPN's are league-wide (a conference page ranks within the
/// conference) and in places junk (every FBS team "1st" on third downs).
nonisolated struct LeagueTeamStats: Sendable, Hashable {
    let league: League
    let lines: [TeamStatLine]

    static func empty(_ league: League) -> LeagueTeamStats {
        LeagueTeamStats(league: league, lines: [])
    }

    var isEmpty: Bool { lines.isEmpty }

    /// A preseason answer: teams, but not one game among them. The tab says
    /// "No games yet" rather than ranking thirty zeroes.
    var hasPlayed: Bool {
        lines.contains { ($0.gamesPlayed ?? 0) > 0 }
    }

    /// The same teams wearing the identities a page already holds — a
    /// standings entry knows its conference, a `byteam` team doesn't.
    func resolvingTeams(_ known: [Team]) -> LeagueTeamStats {
        guard !known.isEmpty else { return self }
        let byId = Dictionary(known.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return LeagueTeamStats(league: league, lines: lines.map { line in
            TeamStatLine(team: byId[line.team.id] ?? line.team, values: line.values)
        })
    }

    /// One stat's table: every team that has the number, best first.
    /// `among` narrows it to a page's teams; nil is the whole league.
    ///
    /// Ties share a rank and fall back to team name, so the order is stable
    /// across polls of the same numbers.
    func ranking(for definition: TeamStatDefinition, among teamIds: Set<String>? = nil) -> TeamStatRanking {
        let valued: [(team: Team, value: Double)] = lines.compactMap { line in
            if let teamIds, !teamIds.contains(line.team.id) { return nil }
            guard let value = line.value(for: definition) else { return nil }
            return (line.team, value)
        }
        let sorted = valued.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return definition.higherIsBetter ? lhs.value > rhs.value : lhs.value < rhs.value
            }
            return lhs.team.location < rhs.team.location
        }
        var rows: [TeamStatRanking.Row] = []
        for (index, entry) in sorted.enumerated() {
            let rank = index > 0 && sorted[index - 1].value == entry.value
                ? rows[index - 1].rank
                : index + 1
            rows.append(TeamStatRanking.Row(rank: rank, team: entry.team, value: entry.value,
                                            display: definition.format.string(entry.value)))
        }
        return TeamStatRanking(definition: definition, rows: rows)
    }

    /// Every card a page can draw, in registry order, empty ones dropped —
    /// a key ESPN doesn't send for a league just hides its card.
    func rankings(among teamIds: Set<String>? = nil) -> [TeamStatRanking] {
        league.teamStatDefinitions
            .map { ranking(for: $0, among: teamIds) }
            .filter { !$0.rows.isEmpty }
    }

    /// Which teams a conference page ranks, or nil for everyone.
    ///
    /// ESPN's `byteam` team carries no group (its `group` object is empty),
    /// so membership comes from the app's own knowledge: a pro league's
    /// hardcoded registry walked up from each team's division, or — college
    /// football's conferences realign too often for a registry — the
    /// standings tables the page already fetched.
    static func teamIds(on conference: ConferenceID,
                        standings: [ConferenceStandings],
                        candidates: [Team]) -> Set<String>? {
        let league = conference.league
        if conference.id == Conference.leagueWideId(in: league)
            || Conference.isDivisionRoot(conference.id, in: league) {
            return nil
        }
        if league == .collegeFootball {
            return Set(standings
                .filter { $0.belongs(to: conference) }
                .flatMap(\.entries)
                .map(\.team.id))
        }
        return Set(candidates.compactMap { team -> String? in
            guard let division = Conference.division(forTeamId: team.id, in: league) else { return nil }
            let chain = Conference.chain(for: ConferenceID(league, division))
            return chain.contains(conference) ? team.id : nil
        })
    }
}

/// One team's flattened numbers.
nonisolated struct TeamStatLine: Sendable, Hashable {
    let team: Team
    let values: [TeamStatKey: Double]

    var gamesPlayed: Double? {
        for name in ["gamesPlayed", "games"] {
            if let value = values[TeamStatKey(.team, "general", name)] { return value }
        }
        return nil
    }

    func value(for definition: TeamStatDefinition) -> Double? {
        switch definition.source {
        case .stat(let key):
            return values[key]
        case .perGame(let key):
            guard let total = values[key], let games = gamesPlayed, games > 0 else { return nil }
            return total / games
        }
    }
}

/// Where a number sits in ESPN's payload: whose it is, its category, its
/// name. "The opponents' passing.sacks" is the defence's sacks.
nonisolated struct TeamStatKey: Sendable, Hashable {
    enum Split: Sendable, Hashable {
        /// `splitId` "0" — the team's own numbers. Also the NBA's
        /// `differential` block, which ships no split at all.
        case team
        /// `splitId` "900" — everyone who played this team, which is where
        /// a defence's numbers live.
        case opponents
    }

    let split: Split
    let category: String
    let name: String

    init(_ split: Split, _ category: String, _ name: String) {
        self.split = split
        self.category = category
        self.name = name
    }
}

/// One card on the Team stats tab: what it ranks, which way is good, and
/// how its number reads.
nonisolated struct TeamStatDefinition: Sendable, Hashable, Identifiable {
    enum Section: Int, Sendable, Hashable, CaseIterable {
        case top, offense, defense, specialTeams, discipline

        var title: String {
            switch self {
            case .top: "Top stats"
            case .offense: "Offense"
            case .defense: "Defense"
            case .specialTeams: "Special teams"
            case .discipline: "Discipline"
            }
        }
    }

    enum Source: Sendable, Hashable {
        case stat(TeamStatKey)
        /// A season total divided by games played — ESPN ships the NHL's
        /// shots and every league's penalties as totals only.
        case perGame(TeamStatKey)
    }

    enum Format: Sendable, Hashable {
        /// "21.0", "3.25".
        case decimal(Int)
        /// ESPN's percentages arrive as 0–100: "66.8%".
        case percent
        /// "+2", "+15.0" — a differential's sign is the point.
        case signed(Int)
        case integer
        /// Hockey's save percentage, which ESPN sends as 0–1 and the sport
        /// writes without its zero: ".925".
        case fraction
        /// A count that can be a half — a shared sack: "10.5", but "8".
        case trimmed

        func string(_ value: Double) -> String {
            switch self {
            case .decimal(let places):
                return String(format: "%.\(places)f", value)
            case .percent:
                return String(format: "%.1f%%", value)
            case .signed(let places):
                let body = String(format: "%.\(places)f", abs(value))
                if value > 0 { return "+" + body }
                return value < 0 ? "-" + body : body
            case .integer:
                return String(format: "%.0f", value)
            case .fraction:
                let digits = String(format: "%.3f", value)
                return digits.hasPrefix("0") ? String(digits.dropFirst()) : digits
            case .trimmed:
                return value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
            }
        }
    }

    /// Unique within a league: "pointsAllowed".
    let id: String
    let title: String
    let section: Section
    let source: Source
    let higherIsBetter: Bool
    let format: Format
}

/// A stat's whole table, already ranked.
nonisolated struct TeamStatRanking: Sendable, Hashable, Identifiable {
    struct Row: Sendable, Hashable, Identifiable {
        /// Tied teams share it: 1, 2, 2, 4.
        let rank: Int
        let team: Team
        let value: Double
        let display: String
        var id: String { team.id }
    }

    let definition: TeamStatDefinition
    let rows: [Row]
    var id: String { definition.id }
}
