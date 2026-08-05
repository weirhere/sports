import Foundation

/// One week's worth of the sport: the parsed week strip plus that week's games.
nonisolated struct Scoreboard: Sendable {
    let seasonYear: Int?
    let seasonType: Int?
    let currentWeekNumber: Int?
    let weeks: [WeekSlot]
    let games: [Game]
}
