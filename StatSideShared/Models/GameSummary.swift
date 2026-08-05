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
    let venue: String?
    let attendance: Int?
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
    }

    let id: String
    let label: String
    let away: Leader?
    let home: Leader?
}
