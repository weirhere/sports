import Foundation
import Testing
@testable import StatSide

private final class TeamStatsFixtureToken {}

private func data(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: TeamStatsFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

private func stats(_ name: String, _ league: League) throws -> TeamSeasonStats {
    TeamStatsMapper.stats(from: try JSONDecoder().decode(TeamStatsResponseDTO.self, from: data(name)),
                          league: league)
}

private func leaders(_ name: String, _ league: League) throws -> [TeamLeader] {
    TeamStatsMapper.leaders(from: try JSONDecoder().decode(TeamLeadersDTO.self, from: data(name)),
                            league: league)
}

/// Captured live on 2026-09-24: the Chiefs two games into the NFL season,
/// and the Lakers in September — when ESPN answers with a season it calls
/// "2026-27 Preseason" and fills it with all of 2025-26.
@Suite struct TeamStatsTests {

    @Test func aFootballTeamHasItsOwnNumbersAndItsOpponents() throws {
        let stats = try stats("nfl-team-stats", .nfl)
        #expect(stats.seasonLabel == "2026")
        #expect(stats.categories.first?.id == "passing")
        #expect(!stats.opponent.isEmpty)
    }

    @Test func footballHeadlinesAreScoringYardsThirdDownAndTurnovers() throws {
        let headlines = try stats("nfl-team-stats", .nfl).headlines(for: .nfl)
        #expect(headlines.map(\.name) == ["totalPointsPerGame", "yardsPerGame",
                                          "thirdDownConvPct", "turnOverDifferential"])
        #expect(headlines.first?.value == "32.0")
    }

    @Test func aStatRepeatedInsideOneCategoryIsListedOnce() throws {
        // ESPN's `receiving` block ships `receivingYards` twice.
        let receiving = try #require(try stats("nfl-team-stats", .nfl)
            .categories.first { $0.id == "receiving" })
        #expect(receiving.stats.filter { $0.name == "receivingYards" }.count == 1)
    }

    @Test func aLongShortNameFallsBackToTheAbbreviation() throws {
        // The NHL's short name for GAA is the whole phrase; a tile needs "GAA".
        let json = #"{"season":{"year":2027,"type":2},"results":{"stats":{"categories":[{"name":"defensive","stats":[{"name":"avgGoalsAgainst","displayName":"Goals Against Average","shortDisplayName":"Goals Against Average","abbreviation":"GAA","displayValue":"3.01"},{"name":"savePct","displayName":"Save Percentage","shortDisplayName":"SV%","abbreviation":"SV%","displayValue":".903"}]}]}}}"#
        let dto = try JSONDecoder().decode(TeamStatsResponseDTO.self, from: Data(json.utf8))
        let stats = TeamStatsMapper.stats(from: dto, league: .nhl)
        #expect(stats.stat("avgGoalsAgainst")?.label == "GAA")
        #expect(stats.stat("avgGoalsAgainst")?.fullName == "Goals Against Average")
        #expect(stats.stat("savePct")?.label == "SV%")
    }

    @Test func septembersPreseasonLabelIsLastSeasonsNumbers() throws {
        // ESPN says "2026-27 Preseason"; the numbers are 82 games of 2025-26.
        let stats = try stats("nba-team-stats-offseason", .nba)
        #expect(stats.seasonLabel == "2025-26")
        #expect(stats.headlines(for: .nba).map(\.label) == ["PPG", "RPG", "APG", "FG%"])
    }

    @Test func aRealPreseasonIsNotShown() {
        let label = TeamStatsMapper.seasonLabel(
            season: try? JSONDecoder().decode(TeamStatsSeasonDTO.self,
                                              from: Data(#"{"year":2027,"type":1}"#.utf8)),
            league: .nba, gamesPlayed: 3)
        #expect(label == nil)
    }

    @Test func aRegularSeasonIsLabelledOnTheAppsAxis() {
        let label = TeamStatsMapper.seasonLabel(
            season: try? JSONDecoder().decode(TeamStatsSeasonDTO.self,
                                              from: Data(#"{"year":2027,"type":2}"#.utf8)),
            league: .nhl, gamesPlayed: 40)
        #expect(label == "2026-27")
    }

    // MARK: - Leaders

    @Test func footballLeadersCarryAWholeLineAndAnAthleteId() throws {
        let leaders = try leaders("nfl-team-leaders", .nfl)
        let passing = try #require(leaders.first)
        #expect(passing.category == "passingLeader")
        #expect(passing.title == "Passing")
        #expect(passing.athleteId == "3139477")
        #expect(passing.value.contains("YDS"))
    }

    @Test func leadersFollowTheLeaguesOrder() throws {
        let categories = try leaders("nba-team-leaders", .nba).map(\.category)
        let order = TeamLeader.categories(for: .nba)
        #expect(categories == order.filter(categories.contains))
        #expect(categories.first == "pointsPerGame")
    }

    @Test func anAthleteIdIsReadOutOfItsRef() {
        #expect(TeamStatsMapper.athleteId(
            fromRef: "http://sports.core.api.espn.com/v2/sports/football/leagues/nfl/seasons/2026/athletes/3139477?lang=en&region=us")
            == "3139477")
        #expect(TeamStatsMapper.athleteId(fromRef: "http://example.com/teams/12") == nil)
    }
}
