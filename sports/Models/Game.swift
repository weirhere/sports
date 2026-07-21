import Foundation

nonisolated struct Game: Identifiable, Hashable, Sendable {
    let id: String
    let date: Date?
    let name: String?
    let shortName: String?
    let weekNumber: Int?
    let status: GameStatus
    let home: Competitor
    let away: Competitor
    let broadcast: String?

    var isLive: Bool {
        if case .live = status { return true }
        return false
    }

    /// True when either side is ranked in the Top 25.
    var involvesRankedTeam: Bool {
        home.rank != nil || away.rank != nil
    }
}

nonisolated enum GameStatus: Hashable, Sendable {
    case pre(detail: String?)
    case live(displayClock: String?, period: Int?, detail: String?, possessionTeamId: String?)
    case final(detail: String?)
    /// Postponed, canceled, or anything ESPN invents later. Renders its detail.
    case other(detail: String?)
}

nonisolated struct Competitor: Hashable, Sendable {
    let team: Team
    let score: Int?
    let record: String?   // overall record summary, e.g. "4-1"
    let rank: Int?        // curated rank when ≤ 25, else nil
    let isHome: Bool
    let winner: Bool?
}
