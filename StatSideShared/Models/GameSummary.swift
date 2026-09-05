import Foundation

/// Everything the game-detail screen renders, mapped from ESPN's summary.
nonisolated struct GameSummary: Sendable {
    struct Side: Hashable, Sendable {
        let team: Team
        let score: Int?
        let record: String?
        let rank: Int?
        let winner: Bool?
        let linescores: [String]   // per-quarter, incl. OT columns
    }

    let home: Side?
    let away: Side?
    let status: GameStatus
    let scoringPlays: [ScoringPlay]
    let drives: [Drive]
    let teamStats: [StatComparison]
    let leaders: [LeaderCategory]
    /// Defaulted so CFBD (no player feed) and every fixture construct
    /// unchanged — empty is what hides the Box score tab.
    var boxScore: [BoxScore] = []
    let venue: String?
    let attendance: Int?
    /// The pre-game info card's extras — every field optional, defaulted
    /// so fixtures and older call sites construct unchanged.
    var venueCity: String? = nil
    var venueCapacity: Int? = nil
    var grassSurface: Bool? = nil
    var weatherCondition: String? = nil
    var weatherTemperature: Int? = nil
}

extension GameSummary {
    /// The side whose team carries this id. Both the drive log and the
    /// scoring list resolve a play's team this way.
    func team(withId id: String?) -> Team? {
        guard let id else { return nil }
        return [away, home].compactMap(\.self).first { $0.team.id == id }?.team
    }
}

/// One offensive possession, chronological. `summary` is ESPN's pre-built
/// "5 plays, 20 yards, 2:39" line — no reassembly needed.
nonisolated struct Drive: Identifiable, Hashable, Sendable {
    let id: String
    let teamId: String?
    let result: String?      // "Punt", "Field Goal", "Touchdown"
    let isScore: Bool
    let summary: String?
    let period: Int?         // quarter the drive started in
}

nonisolated struct ScoringPlay: Identifiable, Hashable, Sendable {
    let id: String
    let period: Int?
    let clock: String?
    let text: String?
    let typeAbbreviation: String?   // "TD", "FG"
    let teamId: String?
    let awayScore: Int?
    let homeScore: Int?
}

/// One stat compared across both teams, with parsed magnitudes for the
/// opposing bars (nil when the value isn't bar-able).
nonisolated struct StatComparison: Identifiable, Hashable, Sendable {
    let id: String       // ESPN stat name
    let label: String
    let away: String
    let home: String
    let awayValue: Double?
    let homeValue: Double?
}

/// One leader category (Passing / Rushing / Receiving) with each side's leader.
nonisolated struct LeaderCategory: Identifiable, Hashable, Sendable {
    struct Leader: Hashable, Sendable {
        let name: String
        let statLine: String
        /// Defaulted so CFBD's photo-less leaders construct unchanged.
        var headshotURL: URL? = nil
    }

    let id: String
    let label: String
    let away: Leader?
    let home: Leader?
}

/// One team's player box score. ESPN ships a category per stat group with
/// its own column headers; we carry those headers through rather than
/// naming columns ourselves, because **the column set changes during the
/// game** — a live `passing` group has five columns and the same group has
/// six once the game is final (QBR only lands at the end). Anything
/// hardcoded here would misalign every row mid-game.
nonisolated struct BoxScore: Identifiable, Hashable, Sendable {
    struct Player: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let jersey: String?
        let headshotURL: URL?
        /// Positionally paired with the owning category's `columns`.
        let stats: [String]
    }

    struct Category: Identifiable, Hashable, Sendable {
        let id: String          // ESPN's group name: "passing", "kickReturns"
        let label: String       // "Passing", "Kick Returns"
        let columns: [String]   // "C/ATT", "YDS", "AVG", ...
        let players: [Player]
        /// ESPN's team totals row. Empty when it doesn't match `columns`.
        let totals: [String]
    }

    let teamId: String
    let categories: [Category]

    var id: String { teamId }
}
