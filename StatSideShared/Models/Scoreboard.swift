import Foundation

/// One week's worth of the sport: the parsed week strip plus that week's games.
nonisolated struct Scoreboard: Sendable {
    let seasonYear: Int?
    let seasonType: Int?
    let currentWeekNumber: Int?
    let weeks: [WeekSlot]
    let games: [Game]
    /// ESPN's own season window, when the response carried one. See
    /// `SeasonCalendarBounds`'s doc comment for why this sits alongside —
    /// not in place of — `League.seasonOpensIn`/`seasonRollsOverAfter`.
    let seasonCalendar: SeasonCalendarBounds?

    /// Written out rather than relying on the synthesized memberwise
    /// init: a `let` with a default value is left out of that synthesis
    /// entirely (only `var` gets a default parameter), so every existing
    /// call site needs `seasonCalendar` to stay optional here by hand.
    init(seasonYear: Int?, seasonType: Int?, currentWeekNumber: Int?,
        weeks: [WeekSlot], games: [Game], seasonCalendar: SeasonCalendarBounds? = nil) {
        self.seasonYear = seasonYear
        self.seasonType = seasonType
        self.currentWeekNumber = currentWeekNumber
        self.weeks = weeks
        self.games = games
        self.seasonCalendar = seasonCalendar
    }
}
