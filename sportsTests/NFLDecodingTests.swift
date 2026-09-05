import Foundation
import Testing
@testable import StatSide

private final class NFLFixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: NFLFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

/// The premise of the whole league axis: ESPN serves the NFL through the
/// same shapes as college football, so the DTO layer needs no second
/// decoder. Fixtures captured live 2026-09-05.
@Suite struct NFLScoreboardDecoding {
    @Test func theNFLScoreboardDecodesThroughTheSameDTOs() throws {
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("nfl-scoreboard"))
        let board = ESPNMapper.scoreboard(from: dto, league: .nfl)

        #expect(board.seasonYear == 2026)
        #expect(!board.games.isEmpty)
        let game = try #require(board.games.first)
        #expect(!game.home.team.location.isEmpty)
        #expect(game.away.team.abbreviation != nil)
    }

    /// Every team the NFL client maps is stamped NFL, so its id can never
    /// be looked up in the college table.
    @Test func mappedTeamsCarryTheNFLNamespace() throws {
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("nfl-scoreboard"))
        let board = ESPNMapper.scoreboard(from: dto, league: .nfl)
        for game in board.games {
            #expect(game.home.team.league == .nfl)
            #expect(game.away.team.league == .nfl)
            #expect(game.home.team.followKey.hasPrefix("nfl:"))
        }
    }

    /// ESPN's calendar is the same nested shape in both leagues, so the
    /// week strip needs no new model. The NFL adds a preseason (type 1),
    /// which `weekSlots` drops alongside college football's off-season.
    @Test func theWeekCalendarParsesIntoTheSameSlots() throws {
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("nfl-scoreboard"))
        let slots = ESPNMapper.weekSlots(from: dto)

        #expect(slots.contains { $0.seasonType == 2 && $0.value == 1 })
        // 18 regular-season weeks and 5 postseason slots (Wild Card,
        // Divisional, Conference Championship, Pro Bowl, Super Bowl).
        #expect(slots.filter { $0.seasonType == 2 }.count == 18)
        #expect(slots.filter { $0.seasonType == 3 }.count == 5)
        #expect(slots.allSatisfy { $0.seasonType == 2 || $0.seasonType == 3 })
        #expect(slots.contains { $0.label == "Super Bowl" })
    }

    /// The NFL's scoreboard ships `curatedRank.current == 99` for every
    /// team. The existing 1...25 clamp already drops it, so no NFL row can
    /// sprout a poll badge.
    @Test func unrankedNFLTeamsNeverGetARankBadge() throws {
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("nfl-scoreboard"))
        let board = ESPNMapper.scoreboard(from: dto, league: .nfl)
        #expect(board.games.allSatisfy { $0.home.rank == nil && $0.away.rank == nil })
        #expect(board.games.allSatisfy { !$0.involvesRankedTeam })
    }
}

@Suite struct NFLStandingsDecoding {
    /// The NFL's default standings response is flat — AFC (8) and NFC (7),
    /// 16 entries each — so it maps through the same path as a college
    /// conference table.
    @Test func standingsMapToTheAFCAndNFC() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self,
                                           from: fixture("nfl-standings"))
        let standings = ESPNMapper.conferenceStandings(from: dto, league: .nfl)

        #expect(Set(standings.map(\.id)) == [8, 7])
        #expect(Set(standings.map(\.name)) == ["AFC", "NFC"])
        #expect(standings.allSatisfy { $0.league == .nfl })
        #expect(standings.allSatisfy { $0.conference?.league == .nfl })
    }

    /// `divisionRecord` is the NFL's in-group record — the analogue of
    /// college football's `vsconf`, which the same column renders.
    @Test func theInGroupRecordComesFromDivisionRecord() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self,
                                           from: fixture("nfl-standings"))
        let standings = ESPNMapper.conferenceStandings(from: dto, league: .nfl)
        let entries = standings.first?.entries ?? []
        #expect(!entries.isEmpty)
        #expect(entries.contains { $0.conferenceRecord != nil })
        #expect(entries.contains { $0.overallRecord != nil })
    }

    @Test func browseRostersCarryTheNFLNamespace() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self,
                                           from: fixture("nfl-standings"))
        let conferences = ESPNMapper.conferences(from: dto, league: .nfl)
        #expect(!conferences.isEmpty)
        for conference in conferences {
            #expect(conference.league == .nfl)
            #expect(conference.teams.allSatisfy { $0.league == .nfl })
            // Every team's conference resolves in the NFL table, not the
            // college one — id 8 must read "AFC", never "SEC".
            #expect(conference.teams.allSatisfy {
                Conference.name(for: $0.conferenceId, in: .nfl) != "SEC"
            })
        }
    }
}

@Suite struct NFLScheduleDecoding {
    /// A team schedule decodes through the same DTOs, and its self-team's
    /// group walk resolves the *division* (Seattle ships `{id: "3", parent:
    /// {id: "7"}}` — NFC West under the NFC).
    @Test func theScheduleResolvesTheDivisionNotTheConference() throws {
        let dto = try JSONDecoder().decode(ScheduleResponseDTO.self,
                                           from: fixture("nfl-team-schedule"))
        let schedule = ESPNMapper.teamSchedule(from: dto, league: .nfl)

        let team = try #require(schedule.team)
        #expect(team.league == .nfl)
        #expect(team.conferenceId == 3)
        #expect(Conference.name(for: team.conferenceId, in: .nfl) == "NFC West")
        #expect(Conference.parent(of: team.conferenceId, in: .nfl) == 7)
        #expect(!schedule.games.isEmpty)
    }

    /// NFL schedules carry no `recordSummary`/`standingSummary`, so the
    /// trust rule yields nil rather than inventing a record — TeamPage
    /// takes those from the standings payload instead (M4).
    @Test func theRecordAndStandingLinesAreAbsent() throws {
        let dto = try JSONDecoder().decode(ScheduleResponseDTO.self,
                                           from: fixture("nfl-team-schedule"))
        let schedule = ESPNMapper.teamSchedule(from: dto, league: .nfl)
        #expect(schedule.record == nil)
        #expect(schedule.standing == nil)
    }
}

@Suite struct NFLWeekRolloverTests {
    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar().date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func slot(_ value: Int, _ start: Date, _ end: Date) -> WeekSlot {
        WeekSlot(label: "Week \(value)", shortLabel: "Wk \(value)",
                 seasonType: 2, value: value, startDate: start, endDate: end)
    }

    /// The NFL week runs Thursday → Monday, so Monday night football is
    /// still this week and Tuesday is the dead day. Both pin back to the
    /// finished week even after ESPN flips its current-week number forward.
    @Test func mondayAndTuesdayStayOnTheFinishedWeek() {
        let slots = [
            slot(1, date(2026, 9, 10), date(2026, 9, 15)),
            slot(2, date(2026, 9, 15), date(2026, 9, 22)),
        ]
        // Mon Sep 14 and Tue Sep 15, with ESPN already reporting week 2.
        for day in [14, 15] {
            let picked = WeekLogic.defaultSelection(
                in: slots, currentWeekNumber: 2, seasonType: 2, league: .nfl,
                today: date(2026, 9, day), calendar: calendar()
            )
            #expect(picked?.value == 1, "Sep \(day) should still show week 1")
        }
    }

    /// Wednesday rolls over — the new week is the answer.
    @Test func wednesdayRollsForward() {
        let slots = [
            slot(1, date(2026, 9, 10), date(2026, 9, 15)),
            slot(2, date(2026, 9, 15), date(2026, 9, 22)),
        ]
        let picked = WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: 2, seasonType: 2, league: .nfl,
            today: date(2026, 9, 16), calendar: calendar()
        )
        #expect(picked?.value == 2)
    }

    /// College football's Sunday rule is untouched.
    @Test func collegeFootballStillPinsOnSundayOnly() {
        let slots = [
            slot(1, date(2026, 8, 29), date(2026, 9, 6)),
            slot(2, date(2026, 9, 6), date(2026, 9, 13)),
        ]
        // Sunday Sep 6 pins back to the Saturday that just finished.
        #expect(WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: 2, seasonType: 2, league: .collegeFootball,
            today: date(2026, 9, 6), calendar: calendar())?.value == 1)
        // Monday rolls over.
        #expect(WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: 2, seasonType: 2, league: .collegeFootball,
            today: date(2026, 9, 7), calendar: calendar())?.value == 2)
    }
}
