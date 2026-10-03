import Foundation
import Testing
@testable import StatSide

private final class CoachFixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: CoachFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
    try JSONDecoder().decode(type, from: fixture(name))
}

private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

private func record(_ w: Int, _ l: Int, t: Int = 0, otl: Int = 0,
                    kind: CoachRecord.Kind = .regular) -> CoachRecord {
    CoachRecord(kind: kind, wins: w, losses: l, ties: t, overtimeLosses: otl)
}

/// Captured live 2026-09-27 from the core API: Todd Bowles's person record
/// (`nfl/coaches/7157`), two of his career records, and his 2016 season.
@Suite struct CoachMapping {
    @Test func thePersonCarriesTheBio() throws {
        let profile = CoachMapper.profile(from: try decode(CoachPersonDTO.self, "nfl-coach"))
        #expect(profile.name == "Todd Bowles")
        #expect(profile.birthPlace == "Elizabeth, New Jersey")
        #expect(profile.experience == 9)
        #expect(profile.headshotURL?.absoluteString
                == "https://a.espncdn.com/i/headshots/nfl/coaches/65/7157.jpg")
        let born = try #require(profile.dateOfBirth)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        #expect(utc.dateComponents([.year, .month, .day], from: born)
                == DateComponents(year: 1963, month: 11, day: 18))
        #expect(profile.age(on: utc.date(from: DateComponents(year: 2026, month: 9, day: 27))!,
                            calendar: utc) == 62)
    }

    @Test func everySeasonRefNamesItsYear() throws {
        let person = try decode(CoachPersonDTO.self, "nfl-coach")
        let years = (person.coachSeasons?.elements ?? []).compactMap {
            CoachMapper.seasonYear(inRef: $0.ref)
        }
        #expect(years.contains(2015) && years.contains(2026))
        #expect(!years.contains(2019), "Bowles wasn't a head coach 2019-21")
    }

    @Test func careerRecordsReadTheirKindAndCounts() throws {
        let total = try #require(CoachMapper.record(
            from: try decode(CoachRecordDTO.self, "nfl-coach-record-total"), league: .nfl))
        #expect(total.kind == .total)
        #expect(total.summary == "60-77")
        let post = try #require(CoachMapper.record(
            from: try decode(CoachRecordDTO.self, "nfl-coach-record-post"), league: .nfl))
        #expect(post.kind == .postseason)
        #expect(post.summary == "1-3")
        #expect(post.winPercentText == ".250")
    }

    @Test func aSeasonNamesItsTeamOnOurYearAxis() throws {
        let dto = try decode(CoachSeasonDTO.self, "nfl-coach-season")
        let rows = CoachMapper.seasons(from: dto, espnYear: 2016, record: record(5, 11), league: .nfl)
        #expect(rows.map(\.teamId) == ["20"])
        #expect(rows.first?.year == 2016)
        #expect(rows.first?.record?.summary == "5-11")

        // The NBA and NHL name a season by the year it ends.
        let nba = CoachMapper.seasons(from: dto, espnYear: 2026, record: nil, league: .nba)
        #expect(nba.first?.year == 2025)
    }

    /// Hockey's overtime losses are their own column; football's are
    /// already inside its losses and must not be counted twice.
    @Test func overtimeLossesCountOnlyInHockey() throws {
        let json = """
        {"id":"0","name":"Total","type":"Total","stats":[
          {"name":"wins","value":1072},{"name":"losses","value":671},
          {"name":"ties","value":77},{"name":"OTLosses","value":159}]}
        """
        let dto = try decode(CoachRecordDTO.self, json: json)
        #expect(CoachMapper.record(from: dto, league: .nhl)?.summary == "1072-671-77-159")
        #expect(CoachMapper.record(from: dto, league: .nfl)?.summary == "1072-671-77")
    }

    /// The NHL's own spelling, from Rick Tocchet's live 2019-20 line.
    @Test func hockeySpellsOvertimeLossesItsOwnWay() throws {
        let json = """
        {"id":"2","name":"Regular Season","type":"Regular Season","stats":[
          {"name":"otLosses","value":8},{"name":"losses","value":29},{"name":"ties","value":0},
          {"name":"wins","value":33},{"name":"overtimeLosses","value":8}]}
        """
        let line = try #require(CoachMapper.record(from: try decode(CoachRecordDTO.self, json: json),
                                                   league: .nhl))
        #expect(line.summary == "33-29-8")
        #expect(line.games == 70)
    }

    @Test func aRecordWithoutWinsOrLossesIsNoRecord() throws {
        let dto = try decode(CoachRecordDTO.self,
                             json: #"{"name":"Total","stats":[{"name":"ties","value":0}]}"#)
        #expect(CoachMapper.record(from: dto, league: .nfl) == nil)
    }
}

@Suite struct CoachCareerShape {
    /// College football ships Total and Regular Season identical and no
    /// postseason; showing both says one thing twice.
    @Test func aRegularLineEqualToTheTotalIsDropped() {
        let lines = CoachMapper.careerRecords([record(60, 16, kind: .regular), record(60, 16, kind: .total)])
        #expect(lines.map(\.kind) == [.total])
    }

    @Test func proCareersKeepAllThreeInOrder() {
        let lines = CoachMapper.careerRecords([record(1, 3, kind: .postseason), record(59, 74, kind: .regular),
                                               record(60, 77, kind: .total)])
        #expect(lines.map(\.kind) == [.total, .regular, .postseason])
    }

    /// Marco Sturm, hired 2025, has no games: no line beats a ".000".
    @Test func zeroGameLinesAreDropped() {
        #expect(CoachMapper.careerRecords([record(0, 0, kind: .total)]).isEmpty)
        #expect(record(0, 0, kind: .total).winPercentText == nil)
    }

    /// DeBoer's live payload: "2024 Washington 0-0-0", twice, for the year
    /// DeBoer was at Alabama.
    @Test func theSeasonACoachLeftIsNotASeasonCoached() {
        let rows = CoachMapper.cleaned([
            CoachSeason(year: 2023, teamId: "264", record: record(14, 1)),
            CoachSeason(year: 2024, teamId: "264", record: record(0, 0)),
            CoachSeason(year: 2025, teamId: "333", record: record(11, 3)),
            CoachSeason(year: 2024, teamId: "264", record: record(0, 0)),
            CoachSeason(year: 2026, teamId: "333", record: nil),
            CoachSeason(year: 2025, teamId: "333", record: record(11, 3)),
        ])
        #expect(rows.map(\.id) == ["2026-333", "2025-333", "2023-264"])
    }

    @Test func seasonsGroupIntoStintsAndAGapSplitsOne() {
        let profile = CoachProfile(name: "Todd Bowles", records: [], seasons: [
            CoachSeason(year: 2026, teamId: "27", record: nil),
            CoachSeason(year: 2025, teamId: "27", record: record(8, 9)),
            CoachSeason(year: 2022, teamId: "27", record: record(8, 9)),
            CoachSeason(year: 2016, teamId: "20", record: record(5, 11)),
            CoachSeason(year: 2015, teamId: "20", record: record(10, 6)),
        ])
        let stints = profile.stints
        #expect(stints.map(\.teamId) == ["27", "27", "20"])
        #expect(stints[0].span(league: .nfl) == "2025–2026")
        #expect(stints[2].span(league: .nfl) == "2015–2016")
        #expect(stints[2].record?.summary == "15-17")
        #expect(stints[1].span(league: .nfl) == "2022")
    }

    @Test func winPercentCountsATieAsHalf() {
        #expect(record(8, 8, t: 1).winPercentText == ".500")
        #expect(record(8, 8, t: 1).summary == "8-8-1")
    }

    @Test func theNavigationIdentityIsNamespacedByLeague() {
        #expect(CoachIdentity(coachId: "27", name: "Jim Harbaugh", league: .nfl).id
                != CoachIdentity(coachId: "27", name: "Someone", league: .collegeFootball).id)
    }
}

@Suite struct RosterCoachId {
    @Test func theRosterCarriesTheCoachsId() throws {
        let cfb = ESPNMapper.roster(from: try decode(RosterResponseDTO.self, "cfb-roster"))
        #expect(cfb.coach?.id == "2331669")
        let nba = ESPNMapper.roster(from: try decode(RosterResponseDTO.self, "nba-roster"))
        #expect(nba.coach?.id == "3024")
    }
}
