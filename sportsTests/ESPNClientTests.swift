import Foundation
import Testing
@testable import StatSide

private final class FixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: FixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

@Suite struct ScoreboardDecodingTests {
    @Test func decodesLiveScoreboard() throws {
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("scoreboard-live"))
        let scoreboard = ESPNMapper.scoreboard(from: dto)

        #expect(scoreboard.games.count == 99)
        #expect(scoreboard.seasonYear == 2026)
        #expect(scoreboard.currentWeekNumber == 1)

        // 15 regular-season entries + Bowls + CFP; the Off Season period is excluded.
        #expect(scoreboard.weeks.count == 17)
        #expect(scoreboard.weeks.filter(\.isPostseason).map(\.label) == ["Bowls", "CFP"])
        #expect(scoreboard.weeks.allSatisfy { $0.startDate != nil && $0.endDate != nil })

        let game = try #require(scoreboard.games.first)
        #expect(game.home.team.id.isEmpty == false)
        #expect(game.away.team.id.isEmpty == false)
        if case .pre = game.status {} else {
            Issue.record("expected a pre-game status in the July fixture")
        }
        #expect(game.date != nil)
    }

    @Test func malformedEventIsDroppedNotFatal() throws {
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("scoreboard-malformed"))
        let scoreboard = ESPNMapper.scoreboard(from: dto)
        // One event was corrupted; it drops, the other 98 survive.
        #expect(scoreboard.games.count == 98)
    }

    @Test func emptyWeekDecodes() throws {
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("scoreboard-empty"))
        let scoreboard = ESPNMapper.scoreboard(from: dto)
        #expect(scoreboard.games.isEmpty)
        #expect(scoreboard.weeks.count == 17)
    }

    @Test func unknownConferenceFallsBackToOther() {
        #expect(Conference.name(for: 9999) == "Other")
        #expect(Conference.name(for: nil) == "Other")
        #expect(Conference.tier(for: 9999) == .other)
        #expect(Conference.name(for: 8) == "SEC")
        #expect(Conference.tier(for: 8) == .power4)
    }
}

@Suite struct ConferenceStandingsDecodingTests {
    private func standings() throws -> [ConferenceStandings] {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self,
                                           from: fixture("standings-with-stats"))
        return ESPNMapper.conferenceStandings(from: dto)
    }

    @Test func decodesRecordsAndKeepsStandingsOrder() throws {
        let all = try standings()
        // Tier then name: Big Ten and SEC (power4) before Sun Belt (group5).
        #expect(all.map(\.name) == ["Big Ten", "SEC", "Sun Belt"])

        let sec = try #require(all.first { $0.id == 8 })
        // ESPN's order survives the mapper — alphabetizing would put
        // Alabama first.
        #expect(sec.entries.map(\.team.location) == ["Ole Miss", "Georgia", "Alabama"])

        let oleMiss = try #require(sec.entries.first)
        #expect(oleMiss.conferenceRecord == "7-1")
        #expect(oleMiss.overallRecord == "13-2")
        #expect(oleMiss.streak == "L1")
        #expect(oleMiss.team.conferenceId == 8)
    }

    @Test func missingStatsDegradeTheRowNotTheTable() throws {
        let sec = try #require(try standings().first { $0.id == 8 })
        // Alabama's entry has no stats array at all; the row stays, its
        // records read as absent.
        let alabama = try #require(sec.entries.first { $0.team.location == "Alabama" })
        #expect(alabama.conferenceRecord == nil)
        #expect(alabama.overallRecord == nil)
        #expect(alabama.streak == nil)
    }

    @Test func malformedEntriesDropRowsNotTheResponse() throws {
        let sec = try #require(try standings().first { $0.id == 8 })
        // The fixture has 5 SEC entries: a nil team and a corrupt stats
        // shape each cost one row, the other 3 survive.
        #expect(sec.entries.count == 3)
    }

    @Test func emptyConferenceIsKeptForTheStandingsPage() throws {
        // Offseason quirk (Sun Belt, 2026-07-20): zero entries. The browse
        // mapper drops it; the standings mapper must keep it so the page
        // can say "Standings TBA".
        let sunBelt = try #require(try standings().first { $0.id == 37 })
        #expect(sunBelt.entries.isEmpty)
    }
}

@Suite struct RankingsDecodingTests {
    @Test func decodesRankings() throws {
        let dto = try JSONDecoder().decode(RankingsResponseDTO.self, from: fixture("rankings-live"))
        let polls = ESPNMapper.polls(from: dto)

        let ap = try #require(polls.first(where: { $0.type == "ap" }))
        #expect(ap.ranks.count == 25)

        let top = try #require(ap.ranks.first)
        #expect(top.current == 1)
        #expect(top.team.id.isEmpty == false)
        #expect(top.movement == 0)
    }
}

@Suite struct WeekLogicTests {
    private let utc = TimeZone(identifier: "UTC")!

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        DateComponents(calendar: calendar, timeZone: utc,
                       year: year, month: month, day: day, hour: hour).date!
    }

    // Mirrors the 2026 calendar: weeks run Tuesday 07:00Z → Monday 06:59Z.
    private var slots: [WeekSlot] {
        [
            WeekSlot(label: "Week 1", shortLabel: "Week 1", seasonType: 2, value: 1,
                     startDate: date(2026, 8, 22, 7), endDate: date(2026, 9, 8, 7)),
            WeekSlot(label: "Week 2", shortLabel: "Week 2", seasonType: 2, value: 2,
                     startDate: date(2026, 9, 8, 7), endDate: date(2026, 9, 14, 7)),
            WeekSlot(label: "Week 3", shortLabel: "Week 3", seasonType: 2, value: 3,
                     startDate: date(2026, 9, 14, 7), endDate: date(2026, 9, 21, 7)),
        ]
    }

    @Test func weekdayUsesESPNCurrentWeek() {
        // Wednesday Sep 9, 2026 — ESPN says week 2.
        let slot = WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: 2, seasonType: 2,
            today: date(2026, 9, 9), calendar: calendar)
        #expect(slot?.value == 2)
    }

    @Test func sundayPinsToCompletedWeek() {
        // Sunday Sep 13, 2026: Saturday's games were week 2. Even if ESPN
        // already claims week 3, Sunday shows week 2.
        let slot = WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: 3, seasonType: 2,
            today: date(2026, 9, 13), calendar: calendar)
        #expect(slot?.value == 2)
    }

    @Test func mondayFlipsForward() {
        // Monday Sep 14, 2026 midday: week 3 has begun.
        let slot = WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: 3, seasonType: 2,
            today: date(2026, 9, 14), calendar: calendar)
        #expect(slot?.value == 3)
    }

    @Test func preseasonFallsBackToFirstSlot() {
        let slot = WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: nil, seasonType: nil,
            today: date(2026, 7, 20), calendar: calendar)
        #expect(slot?.value == 1)
    }
}
