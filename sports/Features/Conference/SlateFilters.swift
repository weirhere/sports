import Foundation

/// How a Games tab groups its slate, and how it narrows it — pure, so the
/// cards' shape is testable without a view in sight.
///
/// Week and date are the two ways a season reads, and they're a *view*
/// choice, not a filter: every game is in the list either way, under one
/// heading or the other (Andy, 2026-09-05 — "Weeks" and "Date" are
/// toggles, "Team" is the dropdown). The team pick is the narrowing one,
/// and a nil selection there is the absence of a filter, never a value
/// callers have to special-case.
nonisolated extension ConferenceSlate {
    /// What the cards are headed by.
    enum Grouping: Equatable, Sendable {
        /// "Week 1", the postseason last — a college season's own clock.
        case week
        /// "Saturday, September 5" — the way a fan says which games.
        case day
        /// One card, chronological: both toggles off, nothing to head it.
        case none
    }

    /// Which card a game files under by week: its preseason week, its
    /// regular-season week, the postseason (whose week numbers restart and
    /// must never land a title game in "Week 1"), or the dateless bucket.
    /// The preseason's numbers restart the same way, so it gets its own
    /// namespace rather than sharing the regular season's.
    static func weekId(for game: Game) -> String {
        if game.seasonType == 3 { return "week-postseason" }
        if game.seasonType == 1 {
            guard let week = game.weekNumber else { return "preseason-other" }
            return "preseason-\(week)"
        }
        if let week = game.weekNumber { return "week-\(week)" }
        return "week-other"
    }

    static func groups(from games: [Game], by grouping: Grouping,
                       calendar: Calendar = .current) -> [WeekGroup] {
        switch grouping {
        case .week: groups(from: games)
        case .day: dayGroups(from: games, calendar: calendar)
        case .none: flatGroup(from: games)
        }
    }

    /// One card per day the slate touches, chronological. Undated games (a
    /// TBD bowl slot) get a bucket of their own at the end rather than a
    /// day they aren't on.
    static func dayGroups(from games: [Game], calendar: Calendar = .current) -> [WeekGroup] {
        let sorted = games.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        var byDay: [String: [Game]] = [:]
        var order: [String] = []
        var undated: [Game] = []
        for game in sorted {
            guard let date = game.date else {
                undated.append(game)
                continue
            }
            let id = DayFormat.id(for: date, calendar: calendar)
            if byDay[id] == nil { order.append(id) }
            byDay[id, default: []].append(game)
        }
        var result = order.compactMap { id -> WeekGroup? in
            guard let games = byDay[id], let date = games.first?.date else { return nil }
            return WeekGroup(id: "day-\(id)", title: dayTitle(for: date, calendar: calendar),
                             games: games)
        }
        if !undated.isEmpty {
            result.append(WeekGroup(id: "day-tbd", title: "Date TBA", games: undated))
        }
        return result
    }

    /// The whole slate as one chronological card. Its title is empty —
    /// there is no heading to write when nothing is being grouped, and the
    /// card renders without one.
    static func flatGroup(from games: [Game]) -> [WeekGroup] {
        let sorted = games.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        return sorted.isEmpty ? [] : [WeekGroup(id: "all", title: "", games: sorted)]
    }

    /// "Saturday, September 5" — Andy's example, and the way a fan says
    /// which day they mean.
    /// "Saturday, September 5" — and "Thursday, October 2, 2025" once the
    /// date is in a different year from the one we're standing in (Andy,
    /// 2026-09-09).
    ///
    /// A weekday and a date are enough while the year is obvious. On a
    /// past season it isn't: the whole point of the pane is that these
    /// games are not from now, and a card headed "Thursday, October 2"
    /// says nothing about which October.
    static func dayTitle(for date: Date, calendar: Calendar,
                         now: Date = .now) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day()
        if calendar.component(.year, from: date) != calendar.component(.year, from: now) {
            style = style.year()
        }
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}

/// Where a Games tab opens: the cards already played, folded away behind
/// one row, so the pane's first card is the one with the next game in it
/// (Andy, 2026-09-08).
///
/// This is deliberately *not* a scroll. Scrolling the pane to the current
/// week takes the hero and the page's identity off screen with it — which
/// is why the 2026-08-29 scroll-to-current-week cut was reverted the day
/// it landed. Folding leaves the page at its true top, full header and
/// all, and the season's history one tap up rather than one scroll up.
nonisolated extension ConferenceSlate {
    /// A slate split at the first card that still has football left in it.
    struct Fold: Equatable {
        /// The spent cards, oldest first — everything before the split.
        var earlier: [WeekGroup]
        /// The card the season is on, and everything after it.
        var upcoming: [WeekGroup]
    }

    /// Splits the cards at the first one that isn't spent.
    ///
    /// A **prefix**, never a scan: a card that somehow reads as spent in
    /// the middle of a live season (a postponed game rescheduled forward
    /// leaves its old week short) stays exactly where the calendar put it.
    /// The fold can only ever hide a run of cards off the front, which is
    /// the one thing it can do without rearranging a season.
    ///
    /// A season with nothing left — every past season, and this one from
    /// the last whistle to next July — folds nothing at all. There is no
    /// "next game" to open on, and a page whose whole slate hid behind a
    /// row would be answering a question nobody asked.
    static func fold(_ groups: [WeekGroup], now: Date = .now,
                     calendar: Calendar = .current) -> Fold {
        guard let split = groups.firstIndex(where: {
            !isSpent($0, now: now, calendar: calendar)
        }), split > 0 else {
            return Fold(earlier: [], upcoming: groups)
        }
        return Fold(earlier: Array(groups[..<split]), upcoming: Array(groups[split...]))
    }

    /// Whether a card has stopped being the one to look at: nothing in it
    /// is live, and nothing in it has yet to kick off.
    ///
    /// The per-game rule is the widget's own `GameSelection.isSpent` —
    /// a result holds its slot for the day it was played in, with six
    /// hours of grace so a game that ends after midnight doesn't vanish
    /// on the whistle. Which means a Saturday's card stays put all
    /// Saturday night and folds on Sunday morning, and a game ESPN never
    /// dated (a TBD bowl slot) is never spent, so its card can't fold
    /// away on a guess.
    static func isSpent(_ group: WeekGroup, now: Date = .now,
                        calendar: Calendar = .current) -> Bool {
        !group.games.contains {
            !GameSelection.isSpent($0, now: now, calendar: calendar)
        }
    }
}
