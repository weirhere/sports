import Foundation
import Testing
@testable import StatSide

private final class WinterFixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: WinterFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

/// The premise the league axis was built on, tested one sport further out:
/// ESPN serves basketball and hockey through the same shapes as football,
/// so the DTO layer needs no second decoder. Fixtures captured live
/// 2026-09-08.
@Suite struct WinterScoreboardDecoding {

    @Test func bothScoreboardsDecodeThroughTheSameDTOs() throws {
        for (name, league) in [("nba-scoreboard", League.nba), ("nhl-scoreboard", .nhl)] {
            let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture(name))
            let board = ESPNMapper.scoreboard(from: dto, league: league)

            #expect(!board.games.isEmpty, "\(league) fixture should carry games")
            let game = try #require(board.games.first)
            #expect(!game.home.team.location.isEmpty)
            #expect(game.away.team.abbreviation != nil)
            #expect(game.home.team.league == league)
        }
    }

    /// ESPN ships two different things under `leagues[].calendar`, and
    /// which one you get depends on the league *and* the request:
    /// football's labelled week periods, or — for these two, whose
    /// `calendarType` is "day" — a flat list of ~229 ISO date strings.
    ///
    /// That form used to throw, and because `leagues` was a plain array
    /// the throw took the whole scoreboard with it: every event of a
    /// single-day NBA or NHL request, lost to a field nothing reads for
    /// those leagues. A date *range* returns an empty calendar, which is
    /// why it stayed hidden until a one-day fixture was captured.
    @Test func aDayListCalendarCostsTheWeeksAndNothingElse() throws {
        for name in ["nba-scoreboard", "nhl-scoreboard"] {
            let raw = try #require(try JSONSerialization.jsonObject(
                with: fixture(name)) as? [String: Any])
            let leagues = try #require(raw["leagues"] as? [[String: Any]])
            let calendar = try #require(leagues.first?["calendar"] as? [Any])
            // The premise: it really is a list of bare strings.
            #expect(calendar.count > 100)
            #expect(calendar.first is String)

            let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture(name))
            #expect(ESPNMapper.weekSlots(from: dto).isEmpty)
            let events = dto.events?.elements ?? []
            #expect(events.count > 0, "the slate survived the calendar")
        }
    }

    /// These scoreboards ship no week, which is why the day strip is the
    /// only axis they could ever have had.
    @Test func aWinterScoreboardCarriesNoWeeks() throws {
        for name in ["nba-scoreboard", "nhl-scoreboard"] {
            let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture(name))
            #expect(ESPNMapper.weekSlots(from: dto).isEmpty)
            #expect(ESPNMapper.scoreboard(from: dto, league: .nba).games
                .allSatisfy { $0.weekNumber == nil })
        }
    }

    /// The scoreboard payload carries no group id, so a team's conference
    /// comes entirely from the hardcoded registry — this is the assertion
    /// that would fail if a map were mistyped.
    @Test func everyTeamOnTheSlateResolvesToARealConference() throws {
        for (name, league) in [("nba-scoreboard", League.nba), ("nhl-scoreboard", .nhl)] {
            let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture(name))
            let board = ESPNMapper.scoreboard(from: dto, league: league)
            for game in board.games {
                for side in [game.home, game.away] {
                    let conference = try #require(side.team.conference,
                                                  "\(side.team.id) has no conference")
                    #expect(Conference.tier(for: conference.id, in: league) == .division)
                    #expect(Conference.chain(for: conference).count == 3)
                }
            }
        }
    }
}

@Suite struct WinterStandingsDecoding {

    @Test func bothStandingsMapOntoTheRegistrysConferences() throws {
        let expected: [(String, League, [Int])] = [
            ("nba-standings", .nba, [5, 6]),
            ("nhl-standings", .nhl, [7, 8]),
        ]
        for (name, league, ids) in expected {
            let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
            let tables = ESPNMapper.conferenceStandings(from: dto, league: league)
            #expect(tables.map(\.id) == ids)
            #expect(tables.allSatisfy { !$0.entries.isEmpty })
            #expect(tables.map(\.name) == ["Eastern", "Western"])
        }
    }

    @Test func theDivisionalResponseNestsUnderTheRightConferences() throws {
        let expected: [(String, League, Int)] = [
            ("nba-standings-level3", .nba, 6),
            ("nhl-standings-level3", .nhl, 4),
        ]
        for (name, league, count) in expected {
            let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
            let divisions = ESPNMapper.divisionStandings(from: dto, league: league)
            #expect(divisions.count == count)
            for division in divisions {
                let parent = try #require(division.parentId)
                #expect(Conference.topLevelIds(in: league).contains(parent))
                #expect(!division.entries.isEmpty)
            }
        }
    }

    /// The NHL keeps no conference record and ranks on points; the NBA
    /// keeps win percentage and games back. Each table's columns have to
    /// find numbers in the payload the league actually ships.
    @Test func everyLeaguesColumnsFindTheirNumbers() throws {
        for (name, league) in [("nba-standings", League.nba), ("nhl-standings", .nhl)] {
            let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
            let table = try #require(ESPNMapper.conferenceStandings(from: dto, league: league).first)
            let leader = try #require(table.entries.first)
            for column in league.standingsColumns {
                #expect(leader.value(for: column) != nil,
                        "\(league) \(column.caption) found nothing")
            }
        }
    }

    @Test func theNHLRecordIsComposedNotTakenFromTheSummary() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture("nhl-standings"))
        let table = try #require(ESPNMapper.conferenceStandings(from: dto, league: .nhl).first)
        let leader = try #require(table.entries.first)
        // ESPN's own `total` summary here is "53-22-7, 113 PTS".
        #expect(leader.winLossOTL?.split(separator: "-").count == 3)
        #expect(leader.overallRecord?.contains("PTS") == false)
        #expect(leader.conferenceRecord == nil)
        #expect((leader.points ?? 0) > 0)
        #expect(leader.hasPlayed)
    }

    /// A points ranking, because the NHL ships no win percentage — without
    /// it the 32-team table came back East's seeds then West's.
    @Test func theNHLLeagueTableRanksOnPoints() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture("nhl-standings"))
        let tables = ESPNMapper.conferenceStandings(from: dto, league: .nhl)
        let league = try #require(tables.leagueTable(in: .nhl))

        #expect(league.entries.count == 32)
        let points = league.entries.compactMap(\.points)
        #expect(points.count == 32)
        #expect(points == points.sorted(by: >))
    }

    @Test func theNBALeagueTableStillRanksOnWinPercentage() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture("nba-standings"))
        let tables = ESPNMapper.conferenceStandings(from: dto, league: .nba)
        let league = try #require(tables.leagueTable(in: .nba))

        #expect(league.entries.count == 30)
        let percents = league.entries.compactMap(\.winPercent)
        #expect(percents == percents.sorted(by: >))
    }
}

@Suite struct WinterScheduleDecoding {

    /// A whole 82-game season in one request, which is what makes a team
    /// page's Games tab affordable where a conference page's is not.
    @Test func aWholeSeasonArrivesInOneRequest() throws {
        for (name, league, teamId) in [("nba-team-schedule", League.nba, "13"),
                                       ("nhl-team-schedule", .nhl, "21")] {
            let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: fixture(name))
            let schedule = ESPNMapper.teamSchedule(from: dto, league: league)
            #expect(schedule.games.count == 82, "\(league) should carry a full season")
            #expect(schedule.team?.id == teamId)
        }
    }

    /// The schedule payload *does* carry the team's group, unlike the
    /// scoreboard — and it's the division, with the conference as parent.
    @Test func theSchedulePayloadNamesTheTeamsDivision() throws {
        let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: fixture("nhl-team-schedule"))
        let schedule = ESPNMapper.teamSchedule(from: dto, league: .nhl)
        // Toronto plays in the Atlantic (32).
        #expect(schedule.team?.conferenceId == 32)
        #expect(Conference.parent(of: 32, in: .nhl) == 7)
    }

    /// ESPN answered a `season=2027` request, and the page that asked knows
    /// that season as 2026. The translation happens at the boundary and
    /// nowhere else.
    @Test func theSeasonComesBackOnOurOwnAxis() throws {
        let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: fixture("nba-team-schedule"))
        #expect(dto.requestedSeason?.year == 2026)
        #expect(ESPNMapper.teamSchedule(from: dto, league: .nba).year == 2025)
        // Football's axis is ESPN's, so nothing moves there.
        #expect(ESPNMapper.teamSchedule(from: dto, league: .nfl).year == 2026)
    }
}
