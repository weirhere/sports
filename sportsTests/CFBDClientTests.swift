import Foundation
import Testing
@testable import StatSide

// Fixture JSON is derived from CFBD's v2 OpenAPI spec (2026-07-21) — the
// shapes need re-verification against live responses once a key exists
// (see BACKLOG E6).

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

private let teamsJSON = """
[
  {"id": 61, "school": "Georgia", "mascot": "Bulldogs", "abbreviation": "UGA",
   "conference": "SEC", "classification": "fbs",
   "logos": ["http://a.espncdn.com/i/teamlogos/ncaa/500/61.png"]},
  {"id": 333, "school": "Alabama", "mascot": "Crimson Tide", "abbreviation": "ALA",
   "conference": "SEC", "classification": "fbs",
   "logos": ["http://a.espncdn.com/i/teamlogos/ncaa/500/333.png"]},
  {"id": 2005, "school": "Air Force", "mascot": "Falcons", "abbreviation": "AFA",
   "conference": "Mountain West", "classification": "fbs", "logos": []}
]
"""

private func makeJoins() throws -> CFBDJoins {
    let teams = try decode([CFBDTeamDTO].self, teamsJSON)
    return CFBDJoins(
        teams: teams,
        records: [61: "4-1", 333: "5-0"],
        ranks: [61: 3, 333: 1]
    )
}

@Suite struct CFBDGameMappingTests {
    private let finalGameJSON = """
    {"id": 401520, "season": 2026, "week": 5, "seasonType": "regular",
     "startDate": "2026-10-03T19:30:00.000Z", "startTimeTBD": false, "completed": true,
     "venue": "Sanford Stadium",
     "homeId": 61, "homeTeam": "Georgia", "homeConference": "SEC",
     "homePoints": 24, "homeLineScores": [7, 3, 7, 7],
     "awayId": 333, "awayTeam": "Alabama", "awayConference": "SEC",
     "awayPoints": 17, "awayLineScores": [0, 10, 0, 7]}
    """

    @Test func mapsFinalGameWithJoins() throws {
        let dto = try decode(CFBDGameDTO.self, finalGameJSON)
        let game = try #require(CFBDMapper.game(from: dto, live: nil, media: [], joins: makeJoins()))

        #expect(game.id == "401520")
        #expect(game.home.team.id == "61")
        #expect(game.home.team.location == "Georgia")
        #expect(game.home.team.conferenceId == 8)          // SEC name → ESPN group id
        #expect(game.home.team.logoURL?.scheme == "https") // http fixed up for ATS
        #expect(game.home.record == "4-1")
        #expect(game.home.rank == 3)
        #expect(game.home.score == 24)
        #expect(game.home.winner == true)
        #expect(game.away.winner == false)
        if case .final(let detail) = game.status {
            #expect(detail == "Final")
        } else {
            Issue.record("expected final status")
        }
    }

    @Test func fiveLinescoresMeansOvertime() throws {
        let json = finalGameJSON.replacingOccurrences(
            of: "\"homeLineScores\": [7, 3, 7, 7]",
            with: "\"homeLineScores\": [7, 3, 7, 7, 6]"
        )
        let dto = try decode(CFBDGameDTO.self, json)
        let game = try #require(CFBDMapper.game(from: dto, live: nil, media: [], joins: makeJoins()))
        if case .final(let detail) = game.status {
            #expect(detail == "Final OT")
        } else {
            Issue.record("expected final status")
        }
    }

    @Test func liveScoreboardMergeWinsOverGameRow() throws {
        let gameJSON = finalGameJSON.replacingOccurrences(
            of: "\"completed\": true", with: "\"completed\": false"
        )
        let liveJSON = """
        {"id": 401520, "status": "in_progress", "period": 3, "clock": "07:41",
         "possession": "home", "tv": "CBS",
         "homeTeam": {"id": 61, "name": "Georgia", "points": 21},
         "awayTeam": {"id": 333, "name": "Alabama", "points": 17}}
        """
        let dto = try decode(CFBDGameDTO.self, gameJSON)
        let live = try decode(CFBDScoreboardGameDTO.self, liveJSON)
        let game = try #require(CFBDMapper.game(from: dto, live: live, media: [], joins: makeJoins()))

        #expect(game.home.score == 21)      // live points beat the games row
        #expect(game.broadcast == "CBS")
        if case .live(let clock, let period, _, let possession) = game.status {
            #expect(clock == "07:41")
            #expect(period == 3)
            #expect(possession == "61")     // "home" resolved to the home id
        } else {
            Issue.record("expected live status")
        }
    }

    @Test func unknownTeamDegradesGracefully() throws {
        // An FCS visitor isn't in /teams/fbs: no logo, no record, no
        // conference — but the row still renders under its host.
        let json = """
        {"id": 1, "completed": false, "startDate": "2026-08-29T16:00:00.000Z",
         "homeId": 61, "homeTeam": "Georgia", "homeConference": "SEC",
         "awayId": 2916, "awayTeam": "Mercer", "awayConference": "SoCon"}
        """
        let dto = try decode(CFBDGameDTO.self, json)
        let game = try #require(CFBDMapper.game(from: dto, live: nil, media: [], joins: makeJoins()))
        #expect(game.away.team.location == "Mercer")
        #expect(game.away.team.logoURL == nil)
        #expect(game.away.team.conferenceId == nil)   // SoCon isn't an FBS conference
        #expect(game.away.record == nil)
    }

    @Test func malformedGameIsDroppedNotFatal() throws {
        let json = """
        [{"id": "not-an-int"}, \(finalGameJSON)]
        """
        let games = try decode(LossyArray<CFBDGameDTO>.self, json)
        #expect(games.elements.count == 1)
        #expect(games.elements.first?.id == 401520)
    }
}

@Suite struct CFBDWeekTests {
    @Test func calendarMapsToWeekSlotsWithESPNSeasonTypes() throws {
        let json = """
        [
          {"season": 2026, "week": 2, "seasonType": "regular",
           "startDate": "2026-09-06T04:00:00.000Z", "endDate": "2026-09-13T03:59:00.000Z"},
          {"season": 2026, "week": 1, "seasonType": "regular",
           "startDate": "2026-08-23T04:00:00.000Z", "endDate": "2026-09-06T03:59:00.000Z"},
          {"season": 2026, "week": 1, "seasonType": "postseason",
           "startDate": "2026-12-13T04:00:00.000Z", "endDate": "2027-01-26T03:59:00.000Z"},
          {"season": 2026, "week": 1, "seasonType": "spring_regular",
           "startDate": "2027-02-01T04:00:00.000Z", "endDate": "2027-03-01T03:59:00.000Z"}
        ]
        """
        let weeks = try decode([CFBDCalendarWeekDTO].self, json)
        let slots = CFBDMapper.weekSlots(from: weeks)

        #expect(slots.count == 3)                          // spring filtered out
        #expect(slots.map(\.value) == [1, 2, 1])           // regular sorted, postseason last
        #expect(slots.map(\.seasonType) == [2, 2, 3])      // ESPN numbering preserved
        #expect(slots.last?.label == "Postseason")
        #expect(slots.allSatisfy { $0.startDate != nil && $0.endDate != nil })
    }

    @Test func currentSlotPrefersContainingThenUpcoming() throws {
        let formatter = ISO8601DateFormatter()
        let slots = [
            WeekSlot(label: "Week 1", shortLabel: "1", seasonType: 2, value: 1,
                     startDate: formatter.date(from: "2026-08-23T04:00:00Z"),
                     endDate: formatter.date(from: "2026-09-06T03:59:00Z")),
            WeekSlot(label: "Week 2", shortLabel: "2", seasonType: 2, value: 2,
                     startDate: formatter.date(from: "2026-09-06T04:00:00Z"),
                     endDate: formatter.date(from: "2026-09-13T03:59:00Z")),
        ]
        let during = try #require(formatter.date(from: "2026-08-29T18:00:00Z"))
        #expect(CFBDMapper.currentSlot(in: slots, now: during)?.value == 1)

        let offseason = try #require(formatter.date(from: "2026-07-21T18:00:00Z"))
        #expect(CFBDMapper.currentSlot(in: slots, now: offseason)?.value == 1)

        let after = try #require(formatter.date(from: "2027-02-01T18:00:00Z"))
        #expect(CFBDMapper.currentSlot(in: slots, now: after)?.value == 2)
    }
}

@Suite struct CFBDRankingsTests {
    private let pollWeeksJSON = """
    [
      {"season": 2026, "seasonType": "regular", "week": 5, "polls": [
        {"poll": "AP Top 25", "ranks": [
          {"rank": 1, "teamId": 333, "school": "Alabama", "firstPlaceVotes": 55, "points": 1550},
          {"rank": 2, "teamId": 61, "school": "Georgia", "points": 1490}
        ]},
        {"poll": "Coaches Poll", "ranks": [
          {"rank": 1, "teamId": 61, "school": "Georgia", "points": 1400}
        ]},
        {"poll": "FCS Coaches Poll", "ranks": [
          {"rank": 1, "teamId": 2755, "school": "South Dakota State"}
        ]}
      ]},
      {"season": 2026, "seasonType": "regular", "week": 4, "polls": [
        {"poll": "AP Top 25", "ranks": [
          {"rank": 3, "teamId": 333, "school": "Alabama"},
          {"rank": 1, "teamId": 61, "school": "Georgia"}
        ]}
      ]}
    ]
    """

    @Test func mapsPollsWithMovementAndFiltersFCS() throws {
        let weeks = try decode([CFBDPollWeekDTO].self, pollWeeksJSON)
        let polls = try CFBDMapper.polls(from: weeks, season: 2026, joins: makeJoins())

        #expect(polls.map(\.type) == ["ap", "usa"])   // FCS poll filtered, no CFP yet
        let ap = try #require(polls.first)
        #expect(ap.ranks.first?.team.id == "333")
        #expect(ap.ranks.first?.current == 1)
        #expect(ap.ranks.first?.previous == 3)        // movement from week 4
        #expect(ap.ranks.first?.firstPlaceVotes == 55)
        #expect(ap.ranks.first?.record == "5-0")      // records join
        #expect(ap.ranks.last?.team.logoURL != nil)   // team meta join
    }

    @Test func rankBadgesPreferCFPOverAP() throws {
        let json = """
        [{"season": 2026, "seasonType": "regular", "week": 12, "polls": [
          {"poll": "AP Top 25", "ranks": [{"rank": 1, "teamId": 333, "school": "Alabama"}]},
          {"poll": "Playoff Committee Rankings", "ranks": [{"rank": 1, "teamId": 61, "school": "Georgia"}]}
        ]}]
        """
        let weeks = try decode([CFBDPollWeekDTO].self, json)
        let badges = CFBDMapper.rankBadges(from: weeks, week: 12)
        #expect(badges[61] == 1)
        #expect(badges[333] == nil)
    }
}

@Suite struct CFBDConferenceTests {
    @Test func groupsTeamsAndSortsByTier() throws {
        let teams = try decode([CFBDTeamDTO].self, teamsJSON)
        let conferences = CFBDMapper.conferences(from: teams)

        #expect(conferences.count == 2)
        #expect(conferences.first?.name == "SEC")           // power 4 before group of 5
        #expect(conferences.first?.id == 8)
        #expect(conferences.last?.name == "Mountain West")
        #expect(conferences.first?.teams.map(\.location) == ["Alabama", "Georgia"])
    }
}

@Suite struct CFBDSummaryTests {
    @Test func scoringDrivesOrientHomeAwayScores() throws {
        let json = """
        [{"id": "d1", "gameId": 401520, "offense": "Alabama", "scoring": true,
          "startPeriod": 2, "endPeriod": 2, "plays": 8, "yards": 75,
          "driveResult": "TD", "isHomeOffense": false,
          "endOffenseScore": 7, "endDefenseScore": 3}]
        """
        let drives = try decode([CFBDDriveDTO].self, json)
        let plays = try CFBDMapper.scoringPlays(from: drives, joins: makeJoins())

        let play = try #require(plays.first)
        #expect(play.awayScore == 7)                  // Alabama on offense, away side
        #expect(play.homeScore == 3)
        #expect(play.typeAbbreviation == "TD")
        #expect(play.teamId == "333")
        #expect(play.period == 2)
    }

    @Test func teamStatsUseSharedCategoryNames() throws {
        let json = """
        {"id": 401520, "teams": [
          {"teamId": 333, "team": "Alabama", "homeAway": "away", "stats": [
            {"category": "totalYards", "stat": "402"},
            {"category": "thirdDownEff", "stat": "5-14"},
            {"category": "possessionTime", "stat": "28:45"}]},
          {"teamId": 61, "team": "Georgia", "homeAway": "home", "stats": [
            {"category": "totalYards", "stat": "377"},
            {"category": "thirdDownEff", "stat": "7-13"},
            {"category": "possessionTime", "stat": "31:15"}]}
        ]}
        """
        let dto = try decode(CFBDGameTeamStatsDTO.self, json)
        let stats = CFBDMapper.teamStats(from: dto)

        #expect(stats.map(\.id) == ["totalYards", "thirdDownEff", "possessionTime"])
        let possession = try #require(stats.last)
        #expect(possession.awayValue == 1725.0)       // 28:45 — ESPNMapper.statMagnitude reused
        #expect(possession.homeValue == 1875.0)       // 31:15
    }
}

@Suite struct CFBDSeasonYearTests {
    @Test func januaryBelongsToPreviousSeason() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let formatter = ISO8601DateFormatter()

        let january = try #require(formatter.date(from: "2027-01-10T18:00:00Z"))
        #expect(CFBDClient.currentSeasonYear(now: january, calendar: calendar) == 2026)

        let july = try #require(formatter.date(from: "2026-07-21T18:00:00Z"))
        #expect(CFBDClient.currentSeasonYear(now: july, calendar: calendar) == 2026)

        let october = try #require(formatter.date(from: "2026-10-03T18:00:00Z"))
        #expect(CFBDClient.currentSeasonYear(now: october, calendar: calendar) == 2026)
    }
}
