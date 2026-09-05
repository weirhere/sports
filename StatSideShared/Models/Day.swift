import Foundation

/// One chip in the day strip — the Scores screen's unit of time since the
/// leagues stopped sharing a calendar (2026-09-05).
///
/// A day is the only unit every league agrees on. College football's
/// "Week 2" and the NFL's are different date ranges, and college
/// football's single "Bowls" slot swallows four NFL playoff rounds whole,
/// so a week strip can only ever be honest about one league at a time.
///
/// `date` is always a **local** start-of-day: the strip, the section
/// buckets and the persisted expansion ids all speak the user's calendar,
/// because "Saturday" means the user's Saturday.
nonisolated struct DaySlot: Identifiable, Hashable, Sendable {
    let date: Date

    init(_ date: Date, calendar: Calendar = .current) {
        self.date = calendar.startOfDay(for: date)
    }

    /// Stable across time zones and locales — it is a persisted expansion
    /// key and a `scrollTo` id, so it comes from date components rather
    /// than a formatter.
    var id: String { DayFormat.id(for: date) }
}

nonisolated enum DayFormat {
    /// `"2026-09-05"`, from local components.
    static func id(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// `"20260905"` — ESPN's `dates=` token.
    ///
    /// Rendered in **Eastern** time, because that is how ESPN reads the
    /// parameter: a game at 11:30pm ET Saturday files under Saturday even
    /// though it is Sunday in UTC. The store asks for a window wider than
    /// the day it is showing, so the ET/local offset can never clip a
    /// slate off either end.
    static func espnToken(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eastern
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d",
                      parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// ESPN publishes every scoreboard on the US Eastern clock.
    static let eastern = TimeZone(identifier: "America/New_York") ?? .gmt
}
