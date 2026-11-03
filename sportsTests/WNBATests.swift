import Foundation
import Testing
@testable import StatSide

private final class WNBAFixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: WNBAFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

/// The WNBA (2026-11-03): basketball through and through, on a season that
/// runs inside one calendar year. Fixtures are the 2026 Finals' Game 7
/// (Valkyries over the Dream) and the final standings.
@MainActor
@Suite struct WNBATests {
    @Test func identity() {
        #expect(League.wnba.rawValue == "wnba")
        #expect(League(rawValue: "wnba") == .wnba)
        #expect(League.wnba.sportSegment == "basketball")
        #expect(League.wnba.isBasketball)
        #expect(!League.wnba.isCollege)
        #expect(!League.wnba.hasPoll)
        #expect(League.wnba.hasGameClock)
        #expect(League.wnba.periodFormat.regulationCount == 4)
        #expect(League.wnba.collegeFeeder == .womensCollegeBasketball)
        #expect(League.womensCollegeBasketball.proAlumniLeagues == [.wnba])
        #expect(ShotMap.surface(for: .wnba) == .court)
    }

    @Test func theSeasonIsTheCalendarYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        #expect(!League.wnba.seasonSpansNewYear)
        let span = SeasonSpan.days(of: .wnba, year: 2026, calendar: calendar)
        #expect(calendar.dateComponents([.year, .month, .day], from: span.lowerBound)
            == DateComponents(year: 2026, month: 4, day: 1))
        #expect(calendar.dateComponents([.year, .month, .day], from: span.upperBound)
            == DateComponents(year: 2026, month: 10, day: 31))
        let march = calendar.date(from: DateComponents(year: 2027, month: 3, day: 15))!
        #expect(SeasonYear.year(for: .wnba, now: march, calendar: calendar) == 2026)
    }

    @Test func twoConferencesAndNoDivisions() {
        #expect(Conference.name(for: 1, in: .wnba) == "Eastern")
        #expect(Conference.slateName(for: .wnba(2)) == "Western Conference")
        #expect(!Conference.hasDivisions(in: .wnba))
        #expect(SlateGrouping.options(for: .wnba) == [.league, .conference])
        #expect(SlateGrouping.options(for: .nba) == SlateGrouping.allCases)
        // The 2026 expansion teams are placed.
        #expect(Conference.division(forTeamId: "131935", in: .wnba) == 1)  // Toronto Tempo
        #expect(Conference.division(forTeamId: "132052", in: .wnba) == 2)  // Portland Fire
    }

    @Test func standingsMapOntoTheRegistry() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture("wnba-standings"))
        let inSeason = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 15)) ?? .now
        let tables = ESPNMapper.conferenceStandings(from: dto, league: .wnba, now: inSeason)
        #expect(Set(tables.compactMap(\.id)) == [1, 2])
        #expect(tables.reduce(0) { $0 + $1.entries.count } == 15)
        #expect(League.wnba.standingsColumns.map(\.caption) == ["W-L", "PCT", "GB"])
    }

    @Test func theFinalsDecodeAsBasketball() throws {
        let board = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("wnba-scoreboard"))
        let game = try #require(ESPNMapper.scoreboard(from: board, league: .wnba).games.first)
        #expect(game.headline == "WNBA Finals - Game 7")
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("wnba-summary"))
        let summary = ESPNMapper.gameSummary(from: dto, league: .wnba)
        #expect(summary.status.isFinal)
        #expect(!summary.plays.isEmpty)
        #expect(!summary.boxScore.isEmpty)
        #expect(!summary.leaders.isEmpty)
        #expect(summary.plays.allSatisfy { $0.baseball == nil && $0.half == nil })
    }

    @Test func trophies() {
        #expect(TrophyKind.from(headline: "WNBA Finals - Game 7", league: .wnba)?.singular == "WNBA Finals")
        #expect(TrophyKind.from(headline: "WNBA Commissioner's Cup Championship", league: .wnba)?.singular
            == "Commissioner's Cup")
        #expect(TrophyKind.from(headline: "WNBA Commissioner's Cup", league: .wnba) == nil)
        #expect(TrophyKind.from(headline: "WNBA Semifinals - Game 3", league: .wnba) == nil)
    }
}
