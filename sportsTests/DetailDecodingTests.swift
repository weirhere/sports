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
        #expect(schedule.games.count == 13)

        // The fixture requested 2025 while ESPN's current season is 2026 —
        // the year comes from requestedSeason, and the current-season
        // summaries ("0-0", "1st in SEC") are nil'd by the trust rule.
        // The honest record for the 2025 games derives from their results.
        #expect(schedule.year == 2025)
        #expect(schedule.record == nil)
        #expect(schedule.standing == nil)
        #expect(schedule.derivedRecord == "12-1")
        // groups is season-scoped, so unlike the summaries it survives the
        // trust rule on this past-season fixture (and its id is a string —
        // the FlexibleInt path).
        #expect(schedule.team?.conferenceId == 8)

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

    @Test func unannouncedKickoffMapsToTimeTBD() throws {
        // ESPN marks unannounced kickoffs `timeValid: false` and parks the
        // date at a placeholder midnight ET; the flag must survive mapping
        // so rows render "TBD" instead of the placeholder's "12:00 AM".
        // Event-level timeValid is absent here to exercise the
        // competition-level fallback.
        let tbdJSON = Data("""
        {
            "id": "888", "date": "2026-10-10T04:00Z",
            "competitions": [{
                "timeValid": false,
                "status": {"type": {"state": "pre"}},
                "competitors": [
                    {"homeAway": "home", "team": {"id": "25"}},
                    {"homeAway": "away", "team": {"id": "259"}}
                ]
            }]
        }
        """.utf8)
        let event = try JSONDecoder().decode(ScheduleEventDTO.self, from: tbdJSON)
        let game = try #require(ESPNMapper.game(from: event))
        #expect(game.timeTBD)
        #expect(game.date != nil)

        // The fixture's kickoffs were all announced (`timeValid: true`).
        let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: fixture("team-schedule-live"))
        #expect(ESPNMapper.teamSchedule(from: dto).games.allSatisfy { !$0.timeTBD })
    }

    @Test func mergesPostseasonEventsIntoSchedule() throws {
        let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: fixture("team-schedule-live"))
        // ESPN serves postseason as a separate seasontype=3 request; the
        // client hands its events to the mapper as extras.
        let bowlJSON = Data("""
        {
            "id": "999999", "date": "2026-01-01T17:00Z", "name": "Peach Bowl",
            "shortName": "UGA vs OSU",
            "competitions": [{
                "competitors": [
                    {"homeAway": "home", "team": {"id": "61"}},
                    {"homeAway": "away", "team": {"id": "194"}}
                ]
            }]
        }
        """.utf8)
        let bowl = try JSONDecoder().decode(ScheduleEventDTO.self, from: bowlJSON)
        let schedule = ESPNMapper.teamSchedule(from: dto, extraEvents: [bowl])

        #expect(schedule.games.count == 14)
        // The January bowl sorts after the regular-season finale.
        #expect(schedule.games.last?.id == "999999")
        // The regular response still owns team identity and the season.
        #expect(schedule.team?.id == "61")
        #expect(schedule.year == 2025)
    }

    @Test func trustsSummariesOnlyWhenSeasonsMatch() throws {
        // In-season shape: ESPN's current season IS the requested one, so
        // recordSummary/standingSummary describe these games and survive.
        let json = Data("""
        {
            "season": {"year": 2025, "type": 2},
            "requestedSeason": {"year": 2025, "type": 2},
            "team": {"id": "61", "location": "Georgia",
                     "recordSummary": "4-0", "standingSummary": "1st in SEC"},
            "events": []
        }
        """.utf8)
        let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: json)
        let schedule = ESPNMapper.teamSchedule(from: dto)
        #expect(schedule.year == 2025)
        #expect(schedule.record == "4-0")
        #expect(schedule.standing == "1st in SEC")
    }

    @Test func resolvesConferenceFromGroups() throws {
        func selfTeam(groups: String) throws -> Team? {
            let json = Data("""
            {
                "team": {"id": "61", "location": "Georgia"\(groups)},
                "events": []
            }
            """.utf8)
            let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: json)
            return ESPNMapper.teamSchedule(from: dto).team
        }

        // Conference-shaped groups: take the group itself, never its
        // parent (80 is FBS, not a conference).
        let conference = try selfTeam(groups: """
        , "groups": {"id": "8", "parent": {"id": "80"}, "isConference": true}
        """)
        #expect(conference?.conferenceId == 8)

        // Division-shaped groups: the parent is the conference.
        let division = try selfTeam(groups: """
        , "groups": {"id": "123", "parent": {"id": "8"}, "isConference": false}
        """)
        #expect(division?.conferenceId == 8)

        // No groups at all degrades to nil, never a guess.
        let absent = try selfTeam(groups: "")
        #expect(absent?.conferenceId == nil)
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

    /// The field the row's team mark hangs off. It has been mapped since
    /// E2 and was never asserted; the Scoring card only started reading it
    /// in E9.
    @Test func scoringPlaysCarryTheScoringTeam() throws {
        let summary = try loadSummary()
        let sides = Set([summary.away, summary.home].compactMap { $0?.team.id })
        #expect(sides.count == 2)
        for play in summary.scoringPlays {
            let teamId = try #require(play.teamId, "every scoring play names a team")
            #expect(sides.contains(teamId), "the scorer is one of the two sides")
            #expect(summary.team(withId: teamId) != nil)
        }
    }

    @Test func decodesBoxScore() throws {
        let summary = try loadSummary()
        #expect(summary.boxScore.count == 2)
        let box = try #require(summary.boxScore.first { $0.teamId == summary.away?.team.id })

        let passing = try #require(box.categories.first { $0.id == "passing" })
        // Columns come from the payload — a final game's passing group
        // carries QBR, a live one doesn't.
        #expect(passing.columns == ["C/ATT", "YDS", "AVG", "TD", "INT", "QBR"])
        #expect(passing.players.count == 1)
        // The team-name prefix comes off ESPN's "Miami Passing".
        #expect(passing.label == "Passing")
        #expect(passing.totals.count == passing.columns.count)

        let defensive = try #require(box.categories.first { $0.id == "defensive" })
        #expect(defensive.players.count == 16)

        // ESPN ships all ten groups for every game whether or not anyone
        // recorded one; the empty ones aren't sections.
        #expect(!box.categories.contains { $0.id == "fumbles" })
        #expect(!box.categories.contains { $0.id == "interceptions" })

        // Every row aligns with its header, always.
        for category in box.categories {
            for player in category.players {
                #expect(player.stats.count == category.columns.count)
            }
        }
    }

    /// A row whose stat count doesn't match the header would put every
    /// number under the wrong column, so it's dropped rather than shown.
    @Test func boxScoreDropsMisalignedRows() throws {
        let json = Data("""
        {"players": [{
          "team": {"id": "1", "displayName": "Test Team"},
          "statistics": [{
            "name": "passing", "text": "Test Team Passing",
            "labels": ["C/ATT", "YDS"],
            "totals": ["10/14", "118"],
            "athletes": [
              {"athlete": {"id": "a", "displayName": "Good Row"}, "stats": ["10/14", "118"]},
              {"athlete": {"id": "b", "displayName": "Short Row"}, "stats": ["3/4"]}
            ]
          }]
        }]}
        """.utf8)
        let dto = try JSONDecoder().decode(BoxscoreDTO.self, from: json)
        let box = try #require(ESPNMapper.boxScore(from: dto).first)
        let passing = try #require(box.categories.first)
        #expect(passing.players.map(\.name) == ["Good Row"])
    }

    /// A totals row that doesn't match the header is dropped the same way,
    /// leaving the table without one rather than misaligned.
    @Test func boxScoreDropsMisalignedTotals() throws {
        let json = Data("""
        {"players": [{
          "team": {"id": "1", "displayName": "Test Team"},
          "statistics": [{
            "name": "kickReturns", "labels": ["NO", "YDS"], "totals": ["2"],
            "athletes": [{"athlete": {"id": "a", "displayName": "Returner"}, "stats": ["2", "40"]}]
          }]
        }]}
        """.utf8)
        let dto = try JSONDecoder().decode(BoxscoreDTO.self, from: json)
        let category = try #require(ESPNMapper.boxScore(from: dto).first?.categories.first)
        #expect(category.totals.isEmpty)
        // No `text` to strip a prefix from, so the group name is humanized.
        #expect(category.label == "Kick Returns")
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
            #expect(category.away?.headshotURL != nil)
        }
    }

    @Test func statMagnitudeParsing() {
        #expect(ESPNMapper.statMagnitude("391") == 391.0)
        #expect(ESPNMapper.statMagnitude("5-14") == 5.0 / 14.0)
        #expect(ESPNMapper.statMagnitude("31:14") == 1874.0)
        #expect(ESPNMapper.statMagnitude("—") == nil)
    }
}
