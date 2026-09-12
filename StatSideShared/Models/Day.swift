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

    /// The inverse of `id(for:)`: a local start-of-day from `"2026-09-05"`.
    ///
    /// What a deep link's `?day=` hint parses through (2026-09-07). The
    /// widget lists games a fortnight out and the Scores screen holds five
    /// days at a time, so a tap on next Sunday's kickoff has to say where
    /// its game lives before the screen can go and find it.
    ///
    /// Rejects a day that isn't one rather than rolling it over: Foundation
    /// reads month 13 as next January and February 31st as March 3rd, and a
    /// link that lands the strip on a day nobody meant is worse than one
    /// that carries no day at all.
    static func date(fromId id: String, calendar: Calendar = .current) -> Date? {
        let parts = id.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day
        else { return nil }
        return date
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

    /// A placeholder kickoff's real day, as a local start-of-day.
    ///
    /// ESPN parks an unannounced kickoff at midnight Eastern of the game's
    /// own day (`timeValid: false`) — a sentinel, not an instant. Read in
    /// any zone west of Eastern that lands on the *previous* calendar day,
    /// so every TBD game filed a day early for Central, Mountain, Pacific,
    /// Alaska and Hawaii — four of the six US zones. Verified live
    /// 2026-09-08: 41 of 71 games in one Saturday window, every one of them
    /// at the identical instant `2026-09-26T04:00Z`.
    ///
    /// The day is the only real thing in the value, so it is what survives:
    /// read the Eastern day, rebuild it as local midnight. Midnight rather
    /// than noon so a TBD game keeps sorting first within its day, which is
    /// what it already did for the Eastern readers who never saw the bug.
    ///
    /// Applied once, at the mapping boundary, so every surface downstream —
    /// the day strip's buckets, a row's day line, the widget, a share, a
    /// deep link's `?day=` — inherits the right day without knowing why.
    static func placeholderKickoff(_ date: Date, calendar: Calendar = .current) -> Date {
        var easternCalendar = Calendar(identifier: .gregorian)
        easternCalendar.timeZone = eastern
        let parts = easternCalendar.dateComponents([.year, .month, .day], from: date)
        // A day we can't rebuild is worse than one an hour off: keep the
        // instant rather than dropping the game off the strip entirely.
        return calendar.date(from: parts) ?? date
    }

    /// A kickoff's day, named the way anyone would say it out loud:
    /// "Today", "Tomorrow", or an absolute "Sat, Sep 12".
    ///
    /// Day-granularity, so a noon kick and an 11pm kick on the same date
    /// are equally far away — the question is which day it lands on, not
    /// how many hours until it starts.
    ///
    /// The absolute form always names its month. A row wearing one carries
    /// no strip or header saying which week is on screen, so a bare "Sat"
    /// would be a guess (2026-09-07).
    ///
    /// `now` and `calendar` are injected so the thresholds are testable
    /// without freezing the clock — and so a caller re-deriving the line
    /// later can say which moment it is relative to.
    static func relativeDay(_ date: Date, now: Date = .now,
                            calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default:
            return date.formatted(.dateTime.weekday(.abbreviated)
                .month(.abbreviated).day())
        }
    }

    /// ESPN publishes every scoreboard on the US Eastern clock.
    static let eastern = TimeZone(identifier: "America/New_York") ?? .gmt
}
