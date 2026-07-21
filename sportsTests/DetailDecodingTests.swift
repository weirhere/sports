import Foundation
import Testing
@testable import sports

private final class FixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: FixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

@Suite struct StandingsDecodingTests {
    @Test func decodesFBSConferences() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture("standings-live"))
        let conferences = ESPNMapper.conferences(from: dto)

        // 11 FBS conferences in the fixture; Sun Belt had zero entries when
        // captured (ESPN offseason quirk), so 10 non-empty survive.
        #expect(conferences.count == 10)

        let sec = try #require(conferences.first { $0.name == "SEC" })
        #expect(sec.teams.count == 16)
        #expect(sec.teams.allSatisfy { $0.conferenceId == 8 })
        #expect(sec.teams.map(\.location) == sec.teams.map(\.location).sorted())
        #expect(sec.teams.allSatisfy { $0.logoURL != nil })

        // Power 4 lead the ordering.
        #expect(Set(conferences.prefix(4).map(\.name)) == ["ACC", "Big 12", "Big Ten", "SEC"])
    }
}

@Suite struct ScheduleDecodingTests {
    @Test func decodesTeamSchedule() throws {
        let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: fixture("team-schedule-live"))
        let schedule = ESPNMapper.teamSchedule(from: dto)

        #expect(schedule.team?.id == "61")
        #expect(schedule.team?.location == "Georgia")
        #expect(schedule.standing == "1st in SEC")
        #expect(schedule.games.count == 13)

        // 2025-season fixture: every game is final with scores mapped from
        // ESPN's score-object shape.
        let finals = schedule.games.filter {
            if case .final = $0.status { return true }
            return false
        }
        #expect(finals.count == 13)
        #expect(schedule.games.allSatisfy { $0.home.score != nil && $0.away.score != nil })
        #expect(schedule.games.allSatisfy { $0.date != nil })

        // Chronological.
        let dates = schedule.games.compactMap(\.date)
        #expect(dates == dates.sorted())
    }
}

@Suite struct SummaryDecodingTests {
    private func loadSummary() throws -> GameSummary {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("summary-final-live"))
        return ESPNMapper.gameSummary(from: dto)
    }

    @Test func decodesHeaderAndLinescores() throws {
        let summary = try loadSummary()
        let home = try #require(summary.home)
        let away = try #require(summary.away)

        #expect(home.score == 27)
        #expect(home.winner == true)
        #expect(home.linescores.count == 4)
        #expect(away.linescores.count == 4)
        if case .final = summary.status {} else {
            Issue.record("expected final status")
        }
        #expect(summary.venue == "Hard Rock Stadium")
        #expect(summary.attendance == 67227)
    }

    @Test func decodesScoringPlays() throws {
        let summary = try loadSummary()
        #expect(summary.scoringPlays.count == 8)
        let first = try #require(summary.scoringPlays.first)
        #expect(first.period == 1)
        #expect(first.text?.isEmpty == false)
        #expect(first.awayScore != nil && first.homeScore != nil)
    }

    @Test func decodesDrives() throws {
        let summary = try loadSummary()
        #expect(summary.drives.count == 22)
        #expect(summary.drives.filter(\.isScore).count == 8)

        let first = try #require(summary.drives.first)
        #expect(first.teamId == "2390")
        #expect(first.result == "Punt")
        #expect(first.isScore == false)
        #expect(first.summary == "5 plays, 20 yards, 2:39")
        #expect(first.period == 1)

        // Chronological by start period, so the quarter markers make sense.
        let periods = summary.drives.compactMap(\.period)
        #expect(periods == periods.sorted())
    }

    @Test func decodesTeamStats() throws {
        let summary = try loadSummary()
        #expect(summary.teamStats.count == 6)
        let total = try #require(summary.teamStats.first { $0.id == "totalYards" })
        #expect(total.awayValue != nil && total.homeValue != nil)
        let thirdDown = try #require(summary.teamStats.first { $0.id == "thirdDownEff" })
        #expect(thirdDown.awayValue != nil)   // "5-14" style parses to a ratio
        let possession = try #require(summary.teamStats.first { $0.id == "possessionTime" })
        #expect(possession.awayValue != nil)  // "31:14" style parses to seconds
    }

    @Test func decodesLeaders() throws {
        let summary = try loadSummary()
        #expect(summary.leaders.map(\.id) == ["passingYards", "rushingYards", "receivingYards"])
        for category in summary.leaders {
            #expect(category.away != nil && category.home != nil)
            #expect(category.away?.name.isEmpty == false)
        }
    }

    @Test func statMagnitudeParsing() {
        #expect(ESPNMapper.statMagnitude("391") == 391.0)
        #expect(ESPNMapper.statMagnitude("5-14") == 5.0 / 14.0)
        #expect(ESPNMapper.statMagnitude("31:14") == 1874.0)
        #expect(ESPNMapper.statMagnitude("—") == nil)
    }
}
