import Foundation

/// Which live games are worth switching to (Coard Miller, 2026-09-24): "if
/// it's an upset or a closer game than the spread suggests." The Scores
/// page's **Tight** filter.
///
/// A game is tight when it's live and either:
/// 1. it's **late and within one score** (football's 4th quarter within 8,
///    basketball's 4th within 6, hockey's 3rd within a goal, overtime always
///    counting as late), or
/// 2. **the underdog is leading** in the second half, which needs the
///    pre-game line's favorite. A game with no line still qualifies by the
///    first rule; the second just can't speak for it.
///
/// The line is used and never printed, so this works with Betting lines
/// switched off. It is a scores question that happens to know the favorite.
nonisolated enum GameCloseness {
    static func isTight(_ game: Game) -> Bool {
        guard case .live(_, let period?, _, let phase, _) = game.status,
              let home = game.home.score, let away = game.away.score else { return false }
        let league = game.home.team.league
        let margin = abs(home - away)

        if period >= league.latePeriod, margin <= league.oneScore { return true }

        // Halftime is the second half's doorstep, and an underdog leading
        // into it is exactly the game the filter is for.
        let secondHalf = period >= league.secondHalfPeriod
            || (phase == .halftime && league.secondHalfPeriod == period + 1)
        guard secondHalf, home != away, let favoriteIsHome = game.line?.favoriteIsHome else {
            return false
        }
        let homeLeads = home > away
        return homeLeads != favoriteIsHome
    }
}

extension League {
    /// The period where a game is late: the last regulation one, and every
    /// overtime after it.
    nonisolated var latePeriod: Int {
        switch self {
        case .collegeFootball, .nfl, .nba: 4
        case .nhl: 3
        }
    }

    /// The period the second half starts in. Hockey has no half, so its
    /// middle period stands in: the underdog still up after two is news.
    nonisolated var secondHalfPeriod: Int {
        switch self {
        case .collegeFootball, .nfl, .nba: 3
        case .nhl: 2
        }
    }

    /// One score: a touchdown and two-point conversion, two basketball
    /// possessions (a three and a two, give or take), a single goal.
    nonisolated var oneScore: Int {
        switch self {
        case .collegeFootball, .nfl: 8
        case .nba: 6
        case .nhl: 1
        }
    }
}
