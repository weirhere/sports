import Foundation
import Testing
@testable import StatSide

private final class StatsFixtureToken {}

private func data(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: StatsFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

private func stats(_ name: String) throws -> PlayerStats {
    PlayerStatsMapper.stats(from: try JSONDecoder().decode(PlayerStatsDTO.self, from: data(name)))
}

private func gameLog(_ name: String) throws -> PlayerGameLog {
    PlayerStatsMapper.gameLog(from: try JSONDecoder().decode(PlayerGameLogDTO.self, from: data(name)))
}

/// Captured live from `site.web.api.espn.com/apis/common/v3` on 2026-09-24:
/// Patrick Mahomes (NFL), LeBron James (NBA), Connor McDavid and a goalie
/// (NHL). Trimmed of links and glossary only.
@Suite struct PlayerStatsTests {

    // MARK: - Season stats

    @Test func aQuarterbackLeadsWithPassing() throws {
        let stats = try stats("nfl-athlete-stats")
        #expect(stats.categories.first?.id == "passing")
        #expect(stats.categories.first?.labels.first == "GP")
    }

    @Test func everyLineCarriesItsSeasonAndClub() throws {
        let passing = try #require(try stats("nfl-athlete-stats").categories.first)
        let latest = try #require(passing.seasons.last)
        #expect(latest.teamId == "12")
        #expect(latest.teamName == "Kansas City Chiefs")
        #expect(latest.values.count == passing.labels.count)
        // Oldest first, as ESPN sends them — Mahomes' rookie year leads.
        #expect((passing.seasons.first?.year ?? 0) < latest.year)
    }

    @Test func theCareerLineIsESPNsOwnAndMatchesTheHeader() throws {
        let passing = try #require(try stats("nfl-athlete-stats").categories.first)
        #expect(passing.career.count == passing.labels.count)
    }

    @Test func aTradedPlayerKeepsOneLinePerClub() throws {
        // LeBron's career spans three clubs; every line names its own.
        let averages = try #require(try stats("nba-athlete-stats").categories.first)
        #expect(averages.id == "averages")
        let clubs = Set(averages.seasons.compactMap(\.teamName))
        #expect(clubs.count >= 3)
    }

    @Test func aGoalieIsTabledAsAGoalie() throws {
        let stats = try stats("nhl-goalie-stats")
        #expect(stats.categories.first?.id == "goaltender")
    }

    // MARK: - Headlines

    @Test func quarterbackHeadlinesAreGamesThenYardsTouchdownsInterceptions() throws {
        let stats = try stats("nfl-athlete-stats")
        let year = try #require(stats.categories.first?.seasons.last?.year)
        #expect(stats.headlines(forSeason: year).map(\.label) == ["GP", "YDS", "TD", "INT"])
    }

    @Test func basketballHeadlinesArePointsReboundsAssists() throws {
        let stats = try stats("nba-athlete-stats")
        let year = try #require(stats.categories.first?.seasons.last?.year)
        #expect(stats.headlines(forSeason: year).map(\.label) == ["GP", "PTS", "REB", "AST"])
    }

    @Test func goalieHeadlinesAreWinsGAASavePct() throws {
        let stats = try stats("nhl-goalie-stats")
        let year = try #require(stats.categories.first?.seasons.last?.year)
        #expect(stats.headlines(forSeason: year).map(\.label) == ["GP", "WINS", "GAA", "SV%"])
    }

    @Test func skaterHeadlinesAreGoalsAssistsPoints() throws {
        let stats = try stats("nhl-skater-stats")
        let year = try #require(stats.categories.first?.seasons.last?.year)
        #expect(stats.headlines(forSeason: year).map(\.label) == ["GP", "G", "A", "PTS"])
    }

    @Test func aSeasonWithNoLineHasNoHeadlines() throws {
        // The offseason: no line for the year means no card, not zeroes.
        #expect(try stats("nfl-athlete-stats").headlines(forSeason: 1990).isEmpty)
    }

    @Test func anUnknownCategoryFallsBackToItsFirstColumns() {
        let category = PlayerStats.Category(
            id: "kicking", title: "Kicking",
            labels: ["GP", "FGM", "FGA", "FG%", "LNG"],
            names: ["gamesPlayed", "fieldGoalsMade", "fieldGoalAttempts", "fieldGoalPct", "longFieldGoalMade"],
            displayNames: [],
            seasons: [.init(year: 2026, label: "2026", teamId: nil, teamName: nil,
                            position: "K", values: ["2", "4", "5", "80.0", "51"])],
            career: [])
        let headlines = PlayerStats(categories: [category]).headlines(forSeason: 2026)
        #expect(headlines.map(\.label) == ["GP", "FGM", "FGA", "FG%"])
    }

    @Test func categoriesWithNoSeasonLinesAreLeftOut() {
        // A player ESPN names a category for but has no rows under: the
        // Stats and Career tabs say so instead of drawing a bare header.
        let bare = PlayerStats.Category(id: "receiving", title: "Receiving",
                                        labels: ["REC"], names: ["receptions"],
                                        displayNames: [], seasons: [], career: [])
        let lined = PlayerStats.Category(
            id: "rushing", title: "Rushing", labels: ["CAR"], names: ["rushingAttempts"],
            displayNames: [],
            seasons: [.init(year: 2026, label: "2026", teamId: nil, teamName: nil,
                            position: "RB", values: ["12"])],
            career: [])
        #expect(PlayerStats(categories: [bare, lined]).categoriesWithLines.map(\.id) == ["rushing"])
        #expect(PlayerStats(categories: [bare]).categoriesWithLines.isEmpty)
        #expect(PlayerStats.empty.categoriesWithLines.isEmpty)
    }

    @Test func aRowThatDoesNotMatchItsHeaderIsDropped() throws {
        let json = #"{"categories":[{"name":"passing","labels":["GP","YDS"],"statistics":[{"season":{"year":2026},"stats":["1"]},{"season":{"year":2025},"stats":["1","200"]}]}]}"#
        let dto = try JSONDecoder().decode(PlayerStatsDTO.self, from: Data(json.utf8))
        #expect(PlayerStatsMapper.stats(from: dto).categories.first?.seasons.map(\.year) == [2025])
    }

    @Test func aPayloadWithNoCategoriesIsEmptyNotAnError() throws {
        let dto = try JSONDecoder().decode(PlayerStatsDTO.self, from: Data(#"{"filters":[]}"#.utf8))
        #expect(PlayerStatsMapper.stats(from: dto).categories.isEmpty)
    }

    // MARK: - Game log

    @Test func aFootballLogGroupsItsColumns() throws {
        let log = try gameLog("nfl-athlete-gamelog")
        #expect(log.groups.map(\.title) == ["Passing", "Rushing"])
        #expect(log.groups.map(\.count).reduce(0, +) == log.labels.count)
    }

    @Test func aGameKnowsItsOpponentResultAndScoreFromThePlayersSide() throws {
        let log = try gameLog("nfl-athlete-gamelog")
        let games = log.sections.flatMap(\.entries)
        let game = try #require(games.first)
        #expect(game.opponentAbbreviation != nil)
        #expect(game.result != nil)
        #expect(game.date != nil)
        #expect(game.week != nil)
        // Home or away, the team's score is the player's side.
        let away = try #require(games.first { $0.isAway })
        #expect(away.teamScore != nil && away.opponentScore != nil)
    }

    @Test func theSeasonMenuComesFromESPNsOwnFilter() throws {
        let log = try gameLog("nfl-athlete-gamelog")
        #expect(log.season == 2025)
        #expect(log.availableSeasons.first == 2026)
        #expect(log.availableSeasons.contains(2025))
    }

    @Test func basketballLogsSplitRegularSeasonAndPostseason() throws {
        let log = try gameLog("nba-athlete-gamelog")
        #expect(log.sections.count == 2)
        #expect(log.sections.allSatisfy { !$0.entries.isEmpty })
        // No weeks outside football — principle 2.
        #expect(log.sections.flatMap(\.entries).allSatisfy { $0.week == nil })
    }

    @Test func aGameRowHeadlineReadsTheLogsOwnColumns() throws {
        let log = try gameLog("nba-athlete-gamelog")
        let game = try #require(log.sections.first?.entries.first)
        let line = log.headline(for: game, category: "averages")
        #expect(line.contains("PTS"))
        #expect(line.contains("REB"))
        #expect(line.contains("AST"))
    }
}
