import Foundation

/// A story's time, two ways (N7): relative in a list, where the question is
/// "is this new", and exact in the reader, where it's "when was this
/// written". FotMob's split — `8 hours ago` in the feed, `Nov 5, 2025 at
/// 5:06 AM` on the article.
nonisolated enum NewsTimestamp {
    /// "Just now", "12m ago", "3h ago", "Yesterday", "Sep 24", and the year
    /// once it isn't this one. `now`, `calendar` and `locale` are injected so
    /// the thresholds are testable, `DayFormat.relativeDay`'s pattern.
    static func relative(_ date: Date, now: Date = .now,
                         calendar: Calendar = .current, locale: Locale = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        if days == 0 { return "\(Int(seconds / 3600))h ago" }
        if days == 1 { return "Yesterday" }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        style.timeZone = calendar.timeZone
        style.locale = locale
        return date.formatted(sameYear ? style : style.year())
    }

    /// "Sep 27, 2026 at 3:44 PM" in the reader's own locale.
    static func exact(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
