import Foundation

/// The season a date belongs to, per league.
nonisolated enum SeasonYear {
    /// Months up to and including the league's rollover month belong to the
    /// *previous* season; from the month after, the upcoming season is the
    /// one that matters.
    ///
    /// College football ends in January (bowls and the CFP), so January is
    /// last season. The NFL runs through the February Super Bowl, so
    /// February is too.
    static func year(for league: League = .collegeFootball,
                     now: Date = .now, calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        return month <= league.seasonRollsOverAfter ? year - 1 : year
    }
}

/// The previous name, kept so college-football call sites read unchanged.
nonisolated enum CFBSeason {
    static func year(for now: Date = .now, calendar: Calendar = .current) -> Int {
        SeasonYear.year(for: .collegeFootball, now: now, calendar: calendar)
    }
}
