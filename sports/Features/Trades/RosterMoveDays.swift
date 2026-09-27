import Foundation

/// The Trades tab's cards: one per day, newest first, headed the way the
/// Games tab heads its Date cards — with "Today" and "Yesterday" where the
/// day has a name (the day strip's words). Pure, so the grouping is testable
/// without a view.
nonisolated enum RosterMoveDays {
    struct Day: Identifiable, Equatable {
        let id: String
        let title: String
        let moves: [RosterMove]
    }

    /// ESPN's order within a day is kept — it's the only order the wire has.
    /// A move whose date didn't parse gets a card of its own at the end
    /// rather than a day it isn't on.
    static func days(from moves: [RosterMove], now: Date = .now,
                     calendar: Calendar = .current) -> [Day] {
        var byDay: [String: [RosterMove]] = [:]
        var dates: [String: Date] = [:]
        var undated: [RosterMove] = []
        for move in moves {
            guard let day = move.day else {
                undated.append(move)
                continue
            }
            let id = DayFormat.id(for: day, calendar: calendar)
            dates[id] = day
            byDay[id, default: []].append(move)
        }
        var result = dates.sorted { $0.value > $1.value }.map { id, date in
            Day(id: "day-\(id)", title: title(for: date, now: now, calendar: calendar),
                moves: byDay[id] ?? [])
        }
        if !undated.isEmpty {
            result.append(Day(id: "day-tbd", title: "Date TBA", moves: undated))
        }
        return result
    }

    static func title(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                             to: calendar.startOfDay(for: date)).day
        switch offset {
        case 0: return "Today"
        case -1: return "Yesterday"
        default: return ConferenceSlate.dayTitle(for: date, calendar: calendar, now: now)
        }
    }
}
