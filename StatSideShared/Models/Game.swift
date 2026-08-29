import Foundation

nonisolated struct Game: Identifiable, Hashable, Sendable {
    let id: String
    let date: Date?
    /// ESPN publishes a placeholder kickoff (midnight ET, `timeValid: false`)
    /// until a game's time is announced. True means `date`'s day is real but
    /// its clock time is noise — render "TBD", never "12:00 AM".
    var timeTBD: Bool = false
    let name: String?
    let shortName: String?
    let weekNumber: Int?
    /// ESPN's season type (2 regular, 3 postseason) when the payload says.
    /// Week numbers restart in the postseason, so grouping a season's
    /// slate by week needs this to keep a title game out of "Week 1".
    var seasonType: Int? = nil
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

    /// This team's fortunes right now, nil unless the game is live and the
    /// team is in it. Missing scores count as 0 — a just-kicked game reads
    /// as tied, never as no answer.
    func liveResult(for teamId: String) -> LiveResult? {
        guard isLive else { return nil }
        let mine: Int?
        let theirs: Int?
        if home.team.id == teamId {
            (mine, theirs) = (home.score, away.score)
        } else if away.team.id == teamId {
            (mine, theirs) = (away.score, home.score)
        } else {
            return nil
        }
        if (mine ?? 0) > (theirs ?? 0) { return .winning }
        if (mine ?? 0) < (theirs ?? 0) { return .losing }
        return .tied
    }
}

/// A live game's answer to "how's my team doing" — the standings dot's
/// three states.
nonisolated enum LiveResult: Sendable {
    case winning, losing, tied
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
