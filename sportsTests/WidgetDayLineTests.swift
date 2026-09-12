import Foundation
import Testing
@testable import StatSide

private func team(_ id: String) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: "T\(id)",
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 8)
}

private func game(_ id: String, home: String, away: String,
                  status: GameStatus, date: Date?) -> Game {
    Game(id: id, date: date, name: nil, shortName: nil, weekNumber: 1, status: status,
         home: Competitor(team: team(home), score: nil, record: nil, rank: nil, isHome: true, winner: nil),
         away: Competitor(team: team(away), score: nil, record: nil, rank: nil, isHome: false, winner: nil),
         broadcast: nil)
}

/// A widget row's kickoff says "Today" on game day and "Tomorrow" the day
/// before (Andy, 2026-09-12) — everything else keeps the absolute
/// "Sat, Sep 12" the rows have carried since the widget shipped.
///
/// This supersedes the "absolute dates, never Today" rule the widget was
/// built on. What that rule was right about is still true, and is the whole
/// reason the refresh half of this suite exists: a *relative* word baked
/// into a string outlives the day it was true, so anything holding one has
/// to expire it at midnight.
@Suite struct WidgetDayLineTests {

    /// A calendar in one fixed zone, so "the day before" means the same
    /// thing wherever the tests run.
    private func calendar(_ identifier: String = "America/New_York") throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: identifier))
        return calendar
    }

    private func date(_ calendar: Calendar, day: Int, hour: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: day,
                                                       hour: hour, minute: 30)))
    }

    // MARK: - The day line

    @Test func gameDayReadsToday() throws {
        let calendar = try calendar()
        let now = try date(calendar, day: 12, hour: 8)
        let kickoff = try date(calendar, day: 12, hour: 19)
        #expect(DayFormat.relativeDay(kickoff, now: now, calendar: calendar) == "Today")
    }

    @Test func theDayBeforeReadsTomorrow() throws {
        let calendar = try calendar()
        let now = try date(calendar, day: 11, hour: 8)
        let kickoff = try date(calendar, day: 12, hour: 19)
        #expect(DayFormat.relativeDay(kickoff, now: now, calendar: calendar) == "Tomorrow")
    }

    /// The threshold is the calendar day, not 24 hours: a game kicking in
    /// 90 minutes is today, and one kicking in 22 hours is tomorrow.
    @Test func theThresholdIsTheDayNotTheHours() throws {
        let calendar = try calendar()
        let lateEvening = try date(calendar, day: 12, hour: 22)
        let sameNight = try date(calendar, day: 12, hour: 23)
        let nextMorning = try date(calendar, day: 13, hour: 20)
        #expect(DayFormat.relativeDay(sameNight, now: lateEvening, calendar: calendar) == "Today")
        #expect(DayFormat.relativeDay(nextMorning, now: lateEvening, calendar: calendar) == "Tomorrow")
    }

    /// Two days out and beyond is where the absolute form starts, and it
    /// always names its month — a widget row carries no strip or header to
    /// say which week is on screen (2026-09-07).
    @Test func twoDaysOutFallsBackToTheDate() throws {
        let calendar = try calendar()
        let now = try date(calendar, day: 10, hour: 8)
        let kickoff = try date(calendar, day: 12, hour: 19)
        let line = DayFormat.relativeDay(kickoff, now: now, calendar: calendar)
        #expect(line != "Today")
        #expect(line != "Tomorrow")
        #expect(line.contains("12"))
        #expect(line.contains("Sep"))
    }

    /// Yesterday is never "Today". A spent result drops off the widget
    /// entirely (`isSpent`), but a live game that started last night does
    /// not, and neither does a stale blob being re-served.
    @Test func yesterdayIsNotToday() throws {
        let calendar = try calendar()
        let now = try date(calendar, day: 13, hour: 8)
        let kickoff = try date(calendar, day: 12, hour: 19)
        let line = DayFormat.relativeDay(kickoff, now: now, calendar: calendar)
        #expect(line != "Today")
        #expect(line.contains("Sep"))
    }

    // MARK: - Expiring the word at midnight

    /// A "Tomorrow" on a Friday night has to have become "Today" by the
    /// time anyone reads it on Saturday, so the timeline asks at midnight
    /// rather than on whichever hourly tick lands after it.
    @Test func aKickoffTomorrowRefreshesAtMidnight() throws {
        let calendar = try calendar()
        let lateEvening = try date(calendar, day: 11, hour: 23)
        let kickoff = try date(calendar, day: 12, hour: 19)
        let pre = [game("g", home: "1", away: "2", status: .pre(detail: nil), date: kickoff)]
        let midnight = try #require(calendar.date(byAdding: .day, value: 1,
                                                  to: calendar.startOfDay(for: lateEvening)))
        #expect(GameSelection.nextRefresh(after: lateEvening, games: pre,
                                          calendar: calendar) == midnight)
    }

    /// Same for a late kickoff still reading "Today" at 11:30pm — at
    /// 12:01am it is yesterday's word.
    @Test func aKickoffTodayRefreshesAtMidnight() throws {
        let calendar = try calendar()
        let lateEvening = try date(calendar, day: 12, hour: 23)
        // Already kicked, so the imminent-kickoff rule can't be what pulls
        // the refresh in.
        let kickoff = try date(calendar, day: 12, hour: 20)
        let pre = [game("g", home: "1", away: "2", status: .pre(detail: nil), date: kickoff)]
        let midnight = try #require(calendar.date(byAdding: .day, value: 1,
                                                  to: calendar.startOfDay(for: lateEvening)))
        #expect(GameSelection.nextRefresh(after: lateEvening, games: pre,
                                          calendar: calendar) == midnight)
    }

    /// Midnight is a ceiling, not a target: a row wearing an absolute date
    /// says the same thing tomorrow, so it keeps the hourly tick.
    @Test func anAbsoluteDateKeepsTheHourlyTick() throws {
        let calendar = try calendar()
        let lateEvening = try date(calendar, day: 12, hour: 23)
        let kickoff = try date(calendar, day: 19, hour: 19)
        let pre = [game("g", home: "1", away: "2", status: .pre(detail: nil), date: kickoff)]
        #expect(GameSelection.nextRefresh(after: lateEvening, games: pre, calendar: calendar)
                    == lateEvening.addingTimeInterval(3600))
    }
}
