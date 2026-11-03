import Foundation
import Testing
@testable import StatSide

/// The season rules after calendar-year leagues arrived (2026-11-03). MLB and
/// the WNBA run inside one calendar year, so `SeasonYear` and `SeasonSpan`
/// branch on `League.seasonSpansNewYear`; these pin that the leagues whose
/// seasons cross New Year read exactly as they did before.
@Suite struct SeasonShapeTests {
    private static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func day(_ date: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day], from: date)
    }

    @Test func everyCrossYearLeagueSaysSo() {
        for league in [League.collegeFootball, .nfl, .nba, .nhl,
                       .mensCollegeBasketball, .womensCollegeBasketball] {
            #expect(league.seasonSpansNewYear, "\(league)")
        }
    }

    /// The spans each league had before the branch, to the day.
    @Test func crossYearSpansAreUnchanged() {
        let expected: [(League, (Int, Int, Int), (Int, Int, Int))] = [
            (.collegeFootball, (2026, 8, 1), (2027, 1, 31)),
            (.nfl, (2026, 7, 1), (2027, 2, 28)),
            (.nba, (2026, 9, 1), (2027, 6, 30)),
            (.nhl, (2026, 9, 1), (2027, 6, 30)),
            (.mensCollegeBasketball, (2026, 10, 1), (2027, 4, 30)),
        ]
        for (league, start, end) in expected {
            let span = SeasonSpan.days(of: league, year: 2026, calendar: Self.calendar)
            #expect(Self.day(span.lowerBound) == DateComponents(year: start.0, month: start.1, day: start.2), "\(league)")
            #expect(Self.day(span.upperBound) == DateComponents(year: end.0, month: end.1, day: end.2), "\(league)")
        }
    }

    @Test func crossYearSeasonYearsAreUnchanged() {
        let c = Self.calendar
        #expect(SeasonYear.year(for: .collegeFootball, now: Self.date(2027, 1), calendar: c) == 2026)
        #expect(SeasonYear.year(for: .collegeFootball, now: Self.date(2027, 2), calendar: c) == 2027)
        #expect(SeasonYear.year(for: .nfl, now: Self.date(2027, 2), calendar: c) == 2026)
        #expect(SeasonYear.year(for: .nba, now: Self.date(2027, 6), calendar: c) == 2026)
        #expect(SeasonYear.year(for: .nba, now: Self.date(2027, 7), calendar: c) == 2027)
    }

    /// The day strip's app season is July to June, and a September day is
    /// in the season that opened that summer.
    @Test func theAppSeasonIsJulyToJune() {
        let span = SeasonSpan.days(year: 2026, calendar: Self.calendar)
        #expect(Self.day(span.lowerBound) == DateComponents(year: 2026, month: 7, day: 1))
        #expect(Self.day(span.upperBound) == DateComponents(year: 2027, month: 6, day: 30))
        #expect(SeasonSpan.year(containing: Self.date(2026, 9), calendar: Self.calendar) == 2026)
        #expect(SeasonSpan.year(containing: Self.date(2027, 6), calendar: Self.calendar) == 2026)
        #expect(SeasonSpan.year(containing: Self.date(2027, 7), calendar: Self.calendar) == 2027)
    }

    @Test func weeksAndSurfacesAreFootballFacts() {
        #expect(League.collegeFootball.hasWeeks)
        #expect(League.nfl.hasWeeks)
        #expect(!League.nba.hasWeeks)
        #expect(League.nfl.playsOnASurface)
        #expect(!League.nhl.playsOnASurface)
    }
}
