import Foundation
import Testing
@testable import StatSide

private final class LeaguePlayerStatsFixtureToken {}

/// Trimmed `byathlete` pools captured live on 2026-10-26: the NFL's sack
/// leaders, college football's rushers (asked with `category=`, without
/// which every college value is null), the NBA's qualified field-goal
/// shooters, and every NHL goalie.
private func lines(_ name: String, _ league: League) throws -> [PlayerStatLine] {
    let url = try #require(
        Bundle(for: LeaguePlayerStatsFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    let dto = try JSONDecoder().decode(ByAthleteResponseDTO.self, from: Data(contentsOf: url))
    return LeaguePlayerStatsMapper.lines(from: dto, league: league)
}

private func definition(_ id: String, _ league: League) throws -> PlayerStatDefinition {
    try #require(league.playerStatDefinitions.first { $0.id == id }, "no \(id) in \(league)")
}

/// The fixture as the one pool a definition reads.
private func stats(_ name: String, _ league: League, for id: String) throws -> LeaguePlayerStats {
    let pool = try definition(id, league).query
    return LeaguePlayerStats(league: league, pools: [pool: try lines(name, league)])
}

@Suite struct LeaguePlayerStatsTests {

    // MARK: - Mapping

    @Test func aPlayerComesBackWithTeamHeadshotAndPosition() throws {
        let anderson = try #require(try lines("nfl-byathlete-sacks", .nfl).first)
        #expect(anderson.player.name == "Will Anderson Jr.")
        #expect(anderson.player.position == "DE")
        #expect(anderson.player.team.abbreviation == "HOU")
        #expect(anderson.player.team.logoURL != nil)
        #expect(anderson.player.headshotURL != nil)
        #expect(anderson.values[PlayerStatKey("defensive", "sacks")] == 7.5)
    }

    @Test func aProPlayersTeamKnowsItsDivision() throws {
        let anderson = try #require(try lines("nfl-byathlete-sacks", .nfl).first)
        #expect(anderson.player.team.conferenceId == Conference.division(forTeamId: anderson.player.team.id,
                                                                        in: .nfl))
    }

    @Test func collegeValuesArriveWhenTheCategoryIsAsked() throws {
        let riley = try #require(try lines("cfb-byathlete-rushing", .collegeFootball).first)
        #expect(riley.player.team.abbreviation == "BOIS")
        #expect(riley.values[PlayerStatKey("rushing", "rushingYards")] == 963)
    }

    @Test func everyCollegeQueryAsksForItsCategory() {
        // Without `category=` college football answers the right order and
        // null values (2026-10-26).
        #expect(League.collegeFootball.playerStatDefinitions.allSatisfy { $0.query.category != nil })
    }

    @Test func theIdentityOpensThePlayerPage() throws {
        let anderson = try #require(try lines("nfl-byathlete-sacks", .nfl).first).player
        #expect(anderson.identity.athleteId == anderson.athleteId)
        #expect(anderson.identity.team?.id == anderson.team.id)
        #expect(anderson.identity.id == "nfl-\(anderson.athleteId)")
    }

    // MARK: - Ranking

    @Test func aHalfSackReadsAsAHalf() throws {
        let ranking = try stats("nfl-byathlete-sacks", .nfl, for: "sacks")
            .ranking(for: try definition("sacks", .nfl))
        #expect(ranking.rows.prefix(2).map(\.display) == ["7.5", "7"])
    }

    @Test func aMinimumKeepsBackupsOffTheGoalieTables() throws {
        let nhl = try stats("nhl-byathlete-goalies", .nhl, for: "savePct")
        let save = nhl.ranking(for: try definition("savePct", .nhl))
        // DiPietro's .941 came on 85 shots.
        #expect(save.rows.first?.player.name == "Linus Ullmark")
        #expect(save.rows.first?.display == ".945")
        #expect(!save.rows.contains { $0.player.name == "Michael DiPietro" })
    }

    @Test func goalsAgainstRanksLowestFirstInsideTheGoaliePool() throws {
        let nhl = try stats("nhl-byathlete-goalies", .nhl, for: "goalsAgainst")
        let gaa = nhl.ranking(for: try definition("goalsAgainst", .nhl))
        #expect(gaa.rows.first?.player.name == "Linus Ullmark")
        #expect(gaa.rows.first?.display == "1.33")
        let values = gaa.rows.map(\.value)
        #expect(values == values.sorted())
    }

    @Test func aScopeRanksAmongItsTeams() throws {
        let nfl = try stats("nfl-byathlete-sacks", .nfl, for: "sacks")
        let saints = Set(nfl.lines.filter { $0.player.team.abbreviation == "NO" }.map(\.player.team.id))
        let ranking = nfl.ranking(for: try definition("sacks", .nfl), among: saints)
        #expect(ranking.rows.map(\.player.team.abbreviation) == ["NO", "NO"])
        #expect(ranking.rows.first?.rank == 1)
    }

    @Test func percentagesComeFromTheirOwnQualifiedPool() throws {
        let nba = try stats("nba-byathlete-fieldgoals", .nba, for: "fieldGoalPct")
        let fg = nba.ranking(for: try definition("fieldGoalPct", .nba))
        #expect(fg.rows.first?.player.name == "Walker Kessler")
        #expect(fg.rows.first?.display == "82.1%")
        // The points cards read a different pool, absent here, so they hide.
        #expect(!nba.rankings().contains { $0.definition.id == "points" })
    }

    @Test func theTeamsAPageKnowsReplaceTheAbbreviations() throws {
        let riley = try #require(try lines("cfb-byathlete-rushing", .collegeFootball).first)
        let boise = Team(id: riley.player.team.id, location: "Boise State", name: "Broncos", abbreviation: "BOIS",
                         displayName: "Boise State Broncos", shortDisplayName: "Boise State", logoURL: nil,
                         conferenceId: 17)
        let pool = try definition("rushingYards", .collegeFootball).query
        let resolved = LeaguePlayerStats(league: .collegeFootball, pools: [pool: [riley]]).resolvingTeams([boise])
        #expect(resolved.lines.first?.player.team.location == "Boise State")
        #expect(resolved.lines.first?.player.team.conferenceId == 17)
    }

    @Test func noGamesIsNotALeaderboard() throws {
        let player = LeaguePlayer(athleteId: "1", name: "Rookie", headshotURL: nil, position: nil,
                                  team: try #require(try lines("nfl-byathlete-sacks", .nfl).first).player.team,
                                  league: .nfl)
        let line = PlayerStatLine(player: player, values: [PlayerStatKey("general", "gamesPlayed"): 0])
        let pool = try definition("sacks", .nfl).query
        #expect(!LeaguePlayerStats(league: .nfl, pools: [pool: [line]]).hasPlayed)
    }

    // MARK: - Live

    /// Every card in every league's registry has players behind it, against
    /// ESPN as it is today. Off by default — the network isn't the suite's —
    /// and run with `TEST_RUNNER_STATSIDE_LIVE=1` when the registry changes.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STATSIDE_LIVE"] == "1"),
          arguments: [League.collegeFootball, .nfl, .nba, .nhl])
    func everyCardHasPlayersLive(_ league: League) async throws {
        let season = league.espnSeason(for: SeasonYear.year(for: league))
        let stats = try await LeaguePlayerStatsClient().stats(league: league, season: season)
        let ranked = Set(stats.rankings().map(\.definition.id))
        let missing = league.playerStatDefinitions.map(\.id).filter { !ranked.contains($0) }
        #expect(missing.isEmpty, "\(league): \(missing)")
    }
}
