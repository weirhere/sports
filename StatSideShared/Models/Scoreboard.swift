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
    let seasonCalendar: SeasonCalendarBounds? = nil
}
