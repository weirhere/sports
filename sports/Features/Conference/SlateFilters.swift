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

    /// Which card a game files under by week: its regular-season week, the
    /// postseason (whose week numbers restart and must never land a title
    /// game in "Week 1"), or the dateless bucket.
    static func weekId(for game: Game) -> String {
        if game.seasonType == 3 { return "week-postseason" }
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
    static func dayTitle(for date: Date, calendar: Calendar) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day()
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}
