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

/// The calendar a season occupies, for the Scores screen's day strip.
///
/// Derived rather than fetched. ESPN publishes a season calendar on the
/// plain scoreboard request, but a `dates=` request — the only one the day
/// axis makes — returns none at all, and no calendar exists for a past
/// season anyway (verified live 2026-09-05). A season's span is a rule, not
/// a lookup: it opens when the league's first game can — August for college
/// football, July for the NFL's Hall of Fame Game — and closes when the
/// league's rollover month does, January for college football and February
/// for the NFL.
nonisolated enum SeasonSpan {
    /// One league's season, as local days.
    static func days(of league: League, year: Int,
                     calendar: Calendar = .current) -> ClosedRange<Date> {
        let start = calendar.date(from: DateComponents(year: year,
                                                       month: league.seasonOpensIn, day: 1))
            ?? Date(timeIntervalSince1970: 0)
        // The first of the month after the rollover month, minus a day —
        // February's length is never spelled out, so leap years are free.
        let afterEnd = calendar.date(from: DateComponents(
            year: year + 1, month: league.seasonRollsOverAfter + 1, day: 1)) ?? start
        let end = calendar.date(byAdding: .day, value: -1, to: afterEnd) ?? start
        return start...max(start, end)
    }

    /// The seasons that did not end when the rule says they do — the month
    /// each one's last game was played in, of the calendar year after the
    /// season's own. Both are the pandemic: the 2019-20 bubbles finished in
    /// the autumn (NBA Finals October 11, Stanley Cup September 28), and the
    /// late-starting 2020-21 seasons ran into July (the 20th and the 7th).
    /// Swept live 2026-09-25 across 2014 on; every other season fits the
    /// rule. The web's `SEASON_OVERRUNS` is the same table.
    static let overruns: [League: [Int: Int]] = [
        .nba: [2019: 10, 2020: 7],
        .nhl: [2019: 9, 2020: 7],
    ]

    /// The days a season's **games** occupy: `days(of:year:)` widened where
    /// the season ran past its league's rollover month, for a fetch that
    /// tables the season whole. A second span rather than a change to the
    /// first, because the day strip's bounds are a rule about which season a
    /// *day* belongs to, and a day in August 2020 has two answers — so a
    /// fetch over this one also filters by ESPN's season stamp.
    static func gameDays(of league: League, year: Int,
                         calendar: Calendar = .current) -> ClosedRange<Date> {
        let span = days(of: league, year: year, calendar: calendar)
        guard let closesIn = overruns[league]?[year],
              let afterEnd = calendar.date(from: DateComponents(
                year: year + 1, month: closesIn + 1, day: 1)),
              let end = calendar.date(byAdding: .day, value: -1, to: afterEnd)
        else { return span }
        return span.lowerBound...max(span.upperBound, end)
    }

    /// Every covered league's season at once — the day strip's bounds. The
    /// NFL's February closes the app's season; college football's August
    /// opens it.
    static func days(year: Int, calendar: Calendar = .current) -> ClosedRange<Date> {
        let spans = League.allCases.map { days(of: $0, year: year, calendar: calendar) }
        let start = spans.map(\.lowerBound).min() ?? Date(timeIntervalSince1970: 0)
        let end = spans.map(\.upperBound).max() ?? start
        return start...max(start, end)
    }

    /// The season a given day belongs to, by the same rollover rule.
    static func year(containing day: Date, calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: day)
        let month = calendar.component(.month, from: day)
        // A day in the rollover months belongs to the season that opened
        // the previous August. `League.allCases.map` keeps the boundary in
        // one place: the app's season runs until the last league's does.
        let latest = League.allCases.map(\.seasonRollsOverAfter).max() ?? 1
        return month <= latest ? year - 1 : year
    }
}
