import Foundation

/// A team's season numbers, as ESPN tables them — its own, and in football
/// its opponents' against it.
///
/// ESPN's category and stat names are carried through, never named here
/// (the box score's rule, 2026-09-05). The per-league registry below only
/// picks which few lead the Overview card; the Stats tab prints them all.
nonisolated struct TeamSeasonStats: Sendable, Hashable {
    struct Stat: Sendable, Hashable, Identifiable {
        /// ESPN's stable key: "totalPointsPerGame", "avgPoints".
        let name: String
        /// Short enough for a tile: "TP/G", "PPG", "GAA".
        let label: String
        /// "Total Points Per Game".
        let fullName: String
        let value: String
        /// "17th" — football's opponent block ranks the defence; nothing
        /// else ships one.
        let rank: String?
        var id: String { name }
    }

    struct Category: Sendable, Hashable, Identifiable {
        /// "passing", "offensive".
        let id: String
        let title: String
        let stats: [Stat]
    }

    /// What season the numbers are — see `TeamStatsMapper.seasonLabel`.
    let seasonLabel: String?
    let categories: [Category]
    /// Football only: the same categories, for everyone who played this team.
    let opponent: [Category]

    static let empty = TeamSeasonStats(seasonLabel: nil, categories: [], opponent: [])

    var isEmpty: Bool { categories.isEmpty }

    /// A stat by ESPN's name, first match — `receiving` repeats
    /// `receivingYards`, and several categories repeat `totalPoints`.
    func stat(_ name: String) -> Stat? {
        for category in categories {
            if let stat = category.stats.first(where: { $0.name == name }) { return stat }
        }
        return nil
    }

    /// The Overview card's numbers, in the league's order, skipping any
    /// ESPN didn't send.
    func headlines(for league: League) -> [Stat] {
        Self.headlineNames(for: league).compactMap(stat)
    }

    /// Which of ESPN's stats lead a team's season. Scoring, then how, then
    /// the one number that most often decides games in that sport.
    static func headlineNames(for league: League) -> [String] {
        switch league {
        case .collegeFootball, .nfl:
            ["totalPointsPerGame", "yardsPerGame", "thirdDownConvPct", "turnOverDifferential"]
        case .nba:
            ["avgPoints", "avgRebounds", "avgAssists", "fieldGoalPct"]
        case .nhl:
            ["goals", "avgGoalsAgainst", "savePct", "faceoffPercent"]
        }
    }
}

/// One of a team's statistical leaders: who leads it in a category, and by
/// how much. The athlete arrives as an id only — the core API links a
/// `$ref` rather than embedding a name — so the page resolves it against
/// the roster it already knows how to fetch.
nonisolated struct TeamLeader: Sendable, Hashable, Identifiable {
    /// ESPN's category key: "passingLeader", "pointsPerGame".
    let category: String
    /// "Passing", "Points Per Game".
    let title: String
    let athleteId: String
    /// "47/74, 566 YDS, 5 TD, 1 INT" or "33.5".
    let value: String
    var id: String { category }

    /// Which categories a team's leaders card shows, per league, in order.
    /// Football's `*Leader` categories carry a whole stat line rather than
    /// one number, which is what a leader row wants.
    static func categories(for league: League) -> [String] {
        switch league {
        case .collegeFootball, .nfl:
            ["passingLeader", "rushingLeader", "receivingLeader", "totalTackles", "sacks", "interceptions"]
        case .nba:
            ["pointsPerGame", "reboundsPerGame", "assistsPerGame", "stealsPerGame", "blocksPerGame"]
        case .nhl:
            ["points", "goals", "assists", "wins", "savePct"]
        }
    }

    /// "Passing Leader" reads as a heading about a heading; the row needs
    /// the stat.
    static func title(for displayName: String) -> String {
        displayName.hasSuffix(" Leader") ? String(displayName.dropLast(" Leader".count)) : displayName
    }
}
