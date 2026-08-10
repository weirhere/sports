import Foundation

/// The college football season a date belongs to.
nonisolated enum CFBSeason {
    /// January belongs to the previous season (bowls/CFP); from February
    /// the upcoming season is the one that matters.
    static func year(for now: Date = .now, calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: now)
        return calendar.component(.month, from: now) == 1 ? year - 1 : year
    }
}
