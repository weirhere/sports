import Foundation

/// How far into a game a copy of it is, so two copies from different
/// requests can be put in order.
///
/// The Scores list and the game page read the same game off two ESPN
/// endpoints, `/scoreboard` and `/summary`, on two 30s timers, and the two
/// don't agree: on 2026-09-26 the list held Northwestern–Indiana at 1:56 in
/// the 4th for over a minute while the game page counted down past 1:00.
/// Every clock in the four leagues counts down, so "further along" is a
/// question with an answer, and it is how the list takes the game page's
/// number without ever stepping backwards (Andy: "any way we can use that
/// number for both?").
nonisolated struct GameProgress: Sendable {
    /// 0 before kickoff, 1 live, 2 final.
    let stage: Int
    let period: Int
    /// Seconds left on the clock; nil when ESPN sent none we can read.
    let remaining: Double?

    /// Strictly further along. Two copies that can't be told apart (same
    /// period and either clock unreadable) are not ahead of each other, so
    /// the caller's tiebreak decides.
    func isAhead(of other: GameProgress) -> Bool {
        if stage != other.stage { return stage > other.stage }
        if period != other.period { return period > other.period }
        guard let remaining, let theirs = other.remaining else { return false }
        return remaining < theirs
    }

    /// "1:56" and "0:58" as minutes and seconds, "45.3" (the last minute
    /// in basketball) as seconds alone.
    static func seconds(in clock: String?) -> Double? {
        guard let clock = clock?.trimmingCharacters(in: .whitespaces), !clock.isEmpty else { return nil }
        let parts = clock.split(separator: ":", omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            return Double(parts[0])
        case 2:
            guard let minutes = Double(parts[0]), let seconds = Double(parts[1]) else { return nil }
            return minutes * 60 + seconds
        default:
            return nil
        }
    }
}

nonisolated extension GameStatus {
    /// Nil for postponed, canceled and anything else that isn't on the
    /// pre → live → final line: those copies aren't ordered, and the
    /// incoming one wins.
    var progress: GameProgress? {
        switch self {
        case .pre:
            return GameProgress(stage: 0, period: 0, remaining: nil)
        case .live(let clock, let period, _, let phase, _):
            // Halftime and the break between periods park the clock at
            // 0:00 whatever ESPN's string says, which puts them after the
            // last play of the period they end.
            let remaining = phase == .playing ? GameProgress.seconds(in: clock) : 0
            return GameProgress(stage: 1, period: period ?? 0, remaining: remaining)
        case .final:
            return GameProgress(stage: 2, period: 0, remaining: nil)
        case .other:
            return nil
        }
    }

    /// Strictly further along than `other`; false whenever either can't be
    /// placed.
    func isAhead(of other: GameStatus) -> Bool {
        guard let mine = progress, let theirs = other.progress else { return false }
        return mine.isAhead(of: theirs)
    }
}

nonisolated extension Game {
    /// This game with another copy's live state: the status and both
    /// sides' score and winner flag. Everything else (teams, ranks,
    /// records, kickoff, network, line) stays this copy's.
    func withLiveState(status: GameStatus,
                       homeScore: Int?, homeWinner: Bool?,
                       awayScore: Int?, awayWinner: Bool?) -> Game {
        func side(_ competitor: Competitor, score: Int?, winner: Bool?) -> Competitor {
            Competitor(team: competitor.team, score: score ?? competitor.score,
                       record: competitor.record, rank: competitor.rank,
                       isHome: competitor.isHome, winner: winner ?? competitor.winner)
        }
        var copy = Game(id: id, date: date, timeTBD: timeTBD, name: name, shortName: shortName,
                        weekNumber: weekNumber, seasonType: seasonType, seasonYear: seasonYear,
                        headline: headline, status: status,
                        home: side(home, score: homeScore, winner: homeWinner),
                        away: side(away, score: awayScore, winner: awayWinner),
                        broadcast: broadcast)
        copy.line = line
        return copy
    }

    /// A fresh scoreboard, minus anything it would move backwards.
    ///
    /// A game whose held copy is strictly further along (because the game
    /// page's summary landed it there, or an earlier board was fresher than
    /// this one) keeps that copy's live state. Ties and anything that
    /// can't be ordered take the fresh copy, so a score correction at the
    /// same clock still comes through.
    static func keepingProgress(_ fresh: [Game], from previous: [Game]) -> [Game] {
        guard !previous.isEmpty else { return fresh }
        let held = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return fresh.map { game in
            guard let old = held[game.id], old.status.isAhead(of: game.status) else { return game }
            return game.withLiveState(status: old.status,
                                      homeScore: old.home.score, homeWinner: old.home.winner,
                                      awayScore: old.away.score, awayWinner: old.away.winner)
        }
    }
}
