import Foundation
import Testing
@testable import StatSide

/// `SeasonSpan.gameDays` — the season-long fetch's span, widened only for
/// the two pandemic seasons that ran past their league's rollover month.
/// An explicit Eastern calendar, so the dates don't depend on the Mac's zone.
@Suite struct SeasonSpanGameDaysTests {
    private let eastern: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        eastern.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func anOrdinarySeasonIsTheDayStripSpan() {
        for league in League.allCases {
            #expect(SeasonSpan.gameDays(of: league, year: 2025, calendar: eastern)
                    == SeasonSpan.days(of: league, year: 2025, calendar: eastern))
        }
    }

    @Test func theBubbleSeasonsRunIntoTheAutumn() {
        let nba = SeasonSpan.gameDays(of: .nba, year: 2019, calendar: eastern)
        #expect(nba.upperBound == day(2020, 10, 31))   // Finals, October 11
        let nhl = SeasonSpan.gameDays(of: .nhl, year: 2019, calendar: eastern)
        #expect(nhl.upperBound == day(2020, 9, 30))    // Cup final, September 28
    }

    @Test func theLateSeasonsRunIntoJuly() {
        #expect(SeasonSpan.gameDays(of: .nba, year: 2020, calendar: eastern).upperBound
                == day(2021, 7, 31))
        #expect(SeasonSpan.gameDays(of: .nhl, year: 2020, calendar: eastern).upperBound
                == day(2021, 7, 31))
    }

    @Test func wideningNeverMovesTheStart() {
        #expect(SeasonSpan.gameDays(of: .nba, year: 2019, calendar: eastern).lowerBound
                == SeasonSpan.days(of: .nba, year: 2019, calendar: eastern).lowerBound)
    }

    @Test func footballIsNeverWidened() {
        for year in [2019, 2020] {
            #expect(SeasonSpan.gameDays(of: .collegeFootball, year: year, calendar: eastern)
                    == SeasonSpan.days(of: .collegeFootball, year: year, calendar: eastern))
            #expect(SeasonSpan.gameDays(of: .nfl, year: year, calendar: eastern)
                    == SeasonSpan.days(of: .nfl, year: year, calendar: eastern))
        }
    }
}
