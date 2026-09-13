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

/// The NFL's table is ESPN's own spread (Andy, 2026-09-13): W, L, T, PCT,
/// home, away, division and conference records, PF, PA, DIFF and STRK.
/// Everything there is in the payload already — the decoder was simply
/// only reading two of them.
@Suite struct NFLStandingsColumns {
    private func leader() throws -> ConferenceStanding {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self,
                                           from: fixture("nfl-standings"))
        let standings = ESPNMapper.conferenceStandings(from: dto, league: .nfl)
        return try #require(standings.first?.entries.first)
    }

    /// The columns the table promises all find numbers in the payload the
    /// league actually ships — the guard every league's set is held to.
    @Test func everyColumnFindsItsNumber() throws {
        let leader = try leader()
        for column in League.nfl.standingsColumns {
            #expect(leader.value(for: column) != nil,
                    "NFL \(column.caption) found nothing")
        }
    }

    @Test func theColumnsAreESPNsOwnOrder() {
        #expect(League.nfl.standingsColumns.map(\.caption) ==
                ["W", "L", "T", "PCT", "HOME", "AWAY", "DIV", "CONF",
                 "PF", "PA", "DIFF", "STRK"])
    }

    /// W, L and T replace the OVR summary rather than sitting beside it —
    /// three columns and one string are the same three numbers.
    @Test func theOverallSummaryLeavesTheTable() {
        #expect(!League.nfl.standingsColumns.contains { $0.field == .overallRecord })
        // It is still decoded: the leader teaser, the record card and the
        // hero line all read it.
        #expect(League.nfl.matchupStandingsColumns.contains { $0.field == .overallRecord })
    }

    @Test func theValuesReadAsESPNWritesThem() throws {
        let leader = try leader()
        #expect(leader.value(for: column(.wins)) == "3")
        #expect(leader.value(for: column(.losses)) == "0")
        #expect(leader.value(for: column(.ties)) == "0")
        #expect(leader.value(for: column(.winPercent)) == "1.000")
        #expect(leader.value(for: column(.homeRecord)) == "2-0")
        #expect(leader.value(for: column(.awayRecord)) == "1-0")
        #expect(leader.value(for: column(.divisionRecord)) == "0-0")
        #expect(leader.value(for: column(.inGroupRecord)) == "2-0")
        #expect(leader.value(for: column(.pointsFor)) == "88")
        #expect(leader.value(for: column(.pointsAgainst)) == "48")
        // Signed by ESPN, and the sign is the whole column.
        #expect(leader.value(for: column(.pointDifferential)) == "+40")
        #expect(leader.value(for: column(.streak)) == "W3")
    }

    private func column(_ field: StandingsColumn.Field) -> StandingsColumn {
        League.nfl.standingsColumns.first { $0.field == field }
            ?? League.nfl.matchupStandingsColumns.first { $0.field == field }!
    }

    /// Only the NFL's table outgrows a phone, so only the NFL's pins its
    /// identity column. A set that fits must never become a scroller — a
    /// scroller says "there is more here" and there wouldn't be.
    @Test func onlyTheWideTableScrolls() {
        #expect(League.nfl.standingsScrollsHorizontally)
        for league in [League.collegeFootball, .nba, .nhl] {
            #expect(!league.standingsScrollsHorizontally)
            #expect(league.matchupStandingsColumns == league.standingsColumns)
        }
    }

    /// The game page's matchup slice stays a two-row glance: it keeps the
    /// pair every football table kept before the spread landed.
    @Test func theMatchupSliceStaysCompact() {
        #expect(League.nfl.matchupStandingsColumns.map(\.caption) == ["CONF", "OVR"])
    }
}

@MainActor
@Suite struct NFLStandingsSentence {
    private let bills = Team(id: "2", location: "Buffalo", name: nil,
                             abbreviation: nil, displayName: nil,
                             shortDisplayName: nil, logoURL: nil,
                             conferenceId: 8, league: .nfl)

    /// A wide row still speaks one sentence, and each column is phrased
    /// the way its own value means: records read "and", a differential
    /// keeps its sign, and a streak is spelled out.
    @Test func theRowSpeaksEveryColumnInItsOwnShape() {
        let standing = ConferenceStanding(
            team: bills, conferenceRecord: "2-0", overallRecord: "3-0",
            streak: "W3", wins: 3, losses: 0, ties: 0,
            homeRecord: "2-0", awayRecord: "1-0", divisionRecord: "0-0",
            pointsFor: 88, pointsAgainst: 48, pointDifferential: "+40")
        let sentence = ConferenceStandingRow(standing: standing, position: 1)
            .accessibilitySummary

        #expect(sentence.hasPrefix("Number 1, Buffalo, 3 wins, 0 losses, 0 ties"))
        #expect(sentence.contains("2 and 0 at home"))
        #expect(sentence.contains("+40 point differential"))
        // Never "plus 40 and ..." — the dash rule is records only.
        #expect(!sentence.contains("and 40"))
        #expect(sentence.hasSuffix("won 3 streak"))
    }

    /// ESPN's "-" is its own "nothing here yet" — a 0-0 team's streak, the
    /// leader's games back. It never reaches the table or the sentence.
    @Test func aDashIsNeverSpokenAndNeverStored() {
        let standing = ConferenceStanding(
            team: bills, conferenceRecord: nil, overallRecord: "0-0",
            streak: nil, wins: 0, losses: 0, ties: 0)
        let sentence = ConferenceStandingRow(standing: standing, position: 4)
            .accessibilitySummary
        #expect(!sentence.contains("streak"))
        #expect(sentence == "Number 4, Buffalo, 0 wins, 0 losses, 0 ties")
    }
}
