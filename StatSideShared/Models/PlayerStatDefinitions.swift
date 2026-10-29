import Foundation

/// Which cards each league's Player stats tab draws, in order (2026-10-26).
///
/// FotMob's player sections, in each sport's own numbers: there's no
/// expected-goals or sprint data in an American box score, so football
/// splits by phase (passing, rushing, receiving, defense, special teams),
/// basketball by shooting and all-around play, hockey by scoring and
/// goaltending. Keys verified live against all four leagues' `byathlete`
/// payloads; one ESPN stops sending just hides its card.
///
/// Discipline lists the most, not the fewest — a leaderboard of fouls is
/// who commits them, FotMob's reading.
nonisolated extension League {
    var playerStatDefinitions: [PlayerStatDefinition] {
        switch self {
        case .collegeFootball: Self.footballPlayerDefinitions(limit: 200)
        case .nfl: Self.footballPlayerDefinitions(limit: 100)
        case .nba: Self.basketballPlayerDefinitions
        case .nhl: Self.hockeyPlayerDefinitions
        }
    }

    private typealias PlayerDefinition = PlayerStatDefinition

    private static func key(_ category: String, _ name: String) -> PlayerStatKey {
        PlayerStatKey(category, name)
    }

    /// The NFL and college football ask the same questions. College
    /// football's pools are wider — 138 FBS teams to the NFL's 32 — so a
    /// conference's or the Top 25's leaders are inside the national slice.
    private static func footballPlayerDefinitions(limit: Int) -> [PlayerStatDefinition] {
        let passing = PlayerStatQuery(category: "offense:passing", sort: "passing.passingYards", limit: limit)
        let rushing = PlayerStatQuery(category: "offense:rushing", sort: "rushing.rushingYards", limit: limit)
        let receiving = PlayerStatQuery(category: "offense:receiving", sort: "receiving.receivingYards", limit: limit)
        let scoring = PlayerStatQuery(category: "scoring", sort: "scoring.totalTouchdowns", limit: limit)
        let tackles = PlayerStatQuery(category: "defense", sort: "defensive.totalTackles", limit: limit)
        let sacks = PlayerStatQuery(category: "defense", sort: "defensive.sacks", limit: limit)
        // ESPN spells this sort camel-cased, though the payload's category
        // is `defensiveinterceptions`.
        let interceptions = PlayerStatQuery(category: "defense", sort: "defensiveInterceptions.interceptions",
                                            limit: limit)
        let kicking = PlayerStatQuery(category: "specialTeams:kicking", sort: "kicking.fieldGoalsMade", limit: limit)
        let punting = PlayerStatQuery(category: "specialTeams:punting", sort: "punting.grossAvgPuntYards", limit: limit)
        let returning = PlayerStatQuery(category: "specialTeams:returning", sort: "returning.kickReturnYards",
                                        limit: limit)
        return [
            PlayerDefinition(id: "passingYards", title: "Passing yards", section: .top, query: passing,
                             key: key("passing", "passingYards"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "rushingYards", title: "Rushing yards", section: .top, query: rushing,
                             key: key("rushing", "rushingYards"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "receivingYards", title: "Receiving yards", section: .top, query: receiving,
                             key: key("receiving", "receivingYards"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "touchdowns", title: "Touchdowns", section: .top, query: scoring,
                             key: key("scoring", "totalTouchdowns"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "sacks", title: "Sacks", section: .top, query: sacks,
                             key: key("defensive", "sacks"), higherIsBetter: true, format: .trimmed),
            PlayerDefinition(id: "tackles", title: "Tackles", section: .top, query: tackles,
                             key: key("defensive", "totalTackles"), higherIsBetter: true, format: .integer),

            PlayerDefinition(id: "passingTouchdowns", title: "Passing touchdowns", section: .passing, query: passing,
                             key: key("passing", "passingTouchdowns"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "passerRating", title: "Passer rating", section: .passing, query: passing,
                             key: key("passing", "QBRating"), higherIsBetter: true, format: .decimal(1)),
            PlayerDefinition(id: "qbr", title: "Total QBR", section: .passing, query: passing,
                             key: key("passing", "QBR"), higherIsBetter: true, format: .decimal(1)),
            PlayerDefinition(id: "completionPct", title: "Completion percentage", section: .passing, query: passing,
                             key: key("passing", "completionPct"), higherIsBetter: true, format: .percent),
            PlayerDefinition(id: "yardsPerPass", title: "Yards per pass", section: .passing, query: passing,
                             key: key("passing", "yardsPerPassAttempt"), higherIsBetter: true, format: .decimal(1)),

            PlayerDefinition(id: "rushingTouchdowns", title: "Rushing touchdowns", section: .rushing, query: rushing,
                             key: key("rushing", "rushingTouchdowns"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "yardsPerRush", title: "Yards per rush", section: .rushing, query: rushing,
                             key: key("rushing", "yardsPerRushAttempt"), higherIsBetter: true, format: .decimal(1)),
            PlayerDefinition(id: "rushingYardsPerGame", title: "Rushing yards per game", section: .rushing,
                             query: rushing, key: key("rushing", "rushingYardsPerGame"), higherIsBetter: true,
                             format: .decimal(1)),

            PlayerDefinition(id: "receptions", title: "Receptions", section: .receiving, query: receiving,
                             key: key("receiving", "receptions"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "receivingTouchdowns", title: "Receiving touchdowns", section: .receiving,
                             query: receiving, key: key("receiving", "receivingTouchdowns"), higherIsBetter: true,
                             format: .integer),
            PlayerDefinition(id: "yardsPerReception", title: "Yards per reception", section: .receiving,
                             query: receiving, key: key("receiving", "yardsPerReception"), higherIsBetter: true,
                             format: .decimal(1)),
            PlayerDefinition(id: "yardsAfterCatch", title: "Yards after catch", section: .receiving,
                             query: receiving, key: key("receiving", "receivingYardsAfterCatch"),
                             higherIsBetter: true, format: .integer),

            PlayerDefinition(id: "tacklesForLoss", title: "Tackles for loss", section: .defense, query: sacks,
                             key: key("defensive", "tacklesForLoss"), higherIsBetter: true, format: .trimmed),
            PlayerDefinition(id: "interceptions", title: "Interceptions", section: .defense, query: interceptions,
                             key: key("defensiveinterceptions", "interceptions"), higherIsBetter: true,
                             format: .integer),
            PlayerDefinition(id: "passesDefended", title: "Passes defended", section: .defense,
                             query: interceptions, key: key("defensive", "passesDefended"), higherIsBetter: true,
                             format: .integer),
            PlayerDefinition(id: "forcedFumbles", title: "Forced fumbles", section: .defense, query: sacks,
                             key: key("general", "fumblesForced"), higherIsBetter: true, format: .integer),

            PlayerDefinition(id: "fieldGoalsMade", title: "Field goals made", section: .specialTeams, query: kicking,
                             key: key("kicking", "fieldGoalsMade"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "fieldGoalPct", title: "Field goal percentage", section: .specialTeams,
                             query: kicking, key: key("kicking", "fieldGoalPct"), higherIsBetter: true,
                             format: .percent,
                             minimum: .init(key: key("kicking", "fieldGoalAttempts"), value: 5)),
            PlayerDefinition(id: "puntingAverage", title: "Punting average", section: .specialTeams, query: punting,
                             key: key("punting", "grossAvgPuntYards"), higherIsBetter: true, format: .decimal(1),
                             minimum: .init(key: key("punting", "punts"), value: 10)),
            PlayerDefinition(id: "kickReturnAverage", title: "Kick return average", section: .specialTeams,
                             query: returning, key: key("returning", "yardsPerKickReturn"), higherIsBetter: true,
                             format: .decimal(1),
                             minimum: .init(key: key("returning", "kickReturns"), value: 5)),
        ]
    }

    /// One wide pool for the counting numbers — every qualified player
    /// fits in one 500 — and a pool each for the percentages, whose
    /// qualification is ESPN's own (a minimum of makes).
    private static let basketballPlayerDefinitions: [PlayerStatDefinition] = {
        let points = PlayerStatQuery(category: nil, sort: "offensive.avgPoints", limit: 500)
        let fieldGoals = PlayerStatQuery(category: nil, sort: "offensive.fieldGoalPct", limit: 50)
        let threes = PlayerStatQuery(category: nil, sort: "offensive.threePointFieldGoalPct", limit: 50)
        let freeThrows = PlayerStatQuery(category: nil, sort: "offensive.freeThrowPct", limit: 50)
        return [
            PlayerDefinition(id: "points", title: "Points per game", section: .top, query: points,
                             key: key("offensive", "avgPoints"), higherIsBetter: true, format: .decimal(1)),
            PlayerDefinition(id: "rebounds", title: "Rebounds per game", section: .top, query: points,
                             key: key("general", "avgRebounds"), higherIsBetter: true, format: .decimal(1)),
            PlayerDefinition(id: "assists", title: "Assists per game", section: .top, query: points,
                             key: key("offensive", "avgAssists"), higherIsBetter: true, format: .decimal(1)),
            PlayerDefinition(id: "steals", title: "Steals per game", section: .top, query: points,
                             key: key("defensive", "avgSteals"), higherIsBetter: true, format: .decimal(1)),
            PlayerDefinition(id: "blocks", title: "Blocks per game", section: .top, query: points,
                             key: key("defensive", "avgBlocks"), higherIsBetter: true, format: .decimal(1)),

            PlayerDefinition(id: "fieldGoalPct", title: "Field goal percentage", section: .shooting,
                             query: fieldGoals, key: key("offensive", "fieldGoalPct"), higherIsBetter: true,
                             format: .percent),
            PlayerDefinition(id: "threePointPct", title: "Three-point percentage", section: .shooting, query: threes,
                             key: key("offensive", "threePointFieldGoalPct"), higherIsBetter: true,
                             format: .percent),
            PlayerDefinition(id: "freeThrowPct", title: "Free throw percentage", section: .shooting,
                             query: freeThrows, key: key("offensive", "freeThrowPct"), higherIsBetter: true,
                             format: .percent),
            PlayerDefinition(id: "threesMade", title: "Threes made per game", section: .shooting, query: points,
                             key: key("offensive", "avgThreePointFieldGoalsMade"), higherIsBetter: true,
                             format: .decimal(1)),
            PlayerDefinition(id: "totalPoints", title: "Total points", section: .shooting, query: points,
                             key: key("offensive", "points"), higherIsBetter: true, format: .integer),

            PlayerDefinition(id: "doubleDoubles", title: "Double-doubles", section: .allAround, query: points,
                             key: key("general", "doubleDouble"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "tripleDoubles", title: "Triple-doubles", section: .allAround, query: points,
                             key: key("general", "tripleDouble"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "minutes", title: "Minutes per game", section: .allAround, query: points,
                             key: key("general", "avgMinutes"), higherIsBetter: true, format: .decimal(1)),

            PlayerDefinition(id: "fouls", title: "Fouls per game", section: .discipline, query: points,
                             key: key("general", "avgFouls"), higherIsBetter: true, format: .decimal(1)),
            PlayerDefinition(id: "technicalFouls", title: "Technical fouls", section: .discipline, query: points,
                             key: key("general", "technicalFouls"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "turnovers", title: "Turnovers per game", section: .discipline, query: points,
                             key: key("offensive", "avgTurnovers"), higherIsBetter: true, format: .decimal(1)),
        ]
    }()

    /// Skaters by points; goalies by save percentage — the one sort that
    /// leads with goalies. ESPN's goals-against and shooting-percentage
    /// sorts don't qualify anyone (skaters at 0.00, 1-for-1 shooters at
    /// 100%), so goals-against ranks inside the goalie pool with a shot
    /// minimum and shooting percentage isn't offered.
    private static let hockeyPlayerDefinitions: [PlayerStatDefinition] = {
        let points = PlayerStatQuery(category: nil, sort: "offensive.points", limit: 200)
        let goalies = PlayerStatQuery(category: nil, sort: "defensive.savePct", limit: 60)
        let penalties = PlayerStatQuery(category: nil, sort: "penalties.penaltyMinutes", limit: 50)
        let shotsFaced = PlayerStatDefinition.Minimum(key: key("defensive", "shotsAgainst"), value: 100)
        return [
            PlayerDefinition(id: "points", title: "Points", section: .top, query: points,
                             key: key("offensive", "points"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "goals", title: "Goals", section: .top, query: points,
                             key: key("offensive", "goals"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "assists", title: "Assists", section: .top, query: points,
                             key: key("offensive", "assists"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "plusMinus", title: "Plus/minus", section: .top, query: points,
                             key: key("general", "plusMinus"), higherIsBetter: true, format: .signed(0)),

            PlayerDefinition(id: "powerPlayGoals", title: "Power-play goals", section: .scoring, query: points,
                             key: key("offensive", "powerPlayGoals"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "gameWinningGoals", title: "Game-winning goals", section: .scoring, query: points,
                             key: key("offensive", "gameWinningGoals"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "shots", title: "Shots", section: .scoring, query: points,
                             key: key("offensive", "shotsTotal"), higherIsBetter: true, format: .integer),
            PlayerDefinition(id: "faceoffsWon", title: "Faceoffs won", section: .scoring, query: points,
                             key: key("offensive", "faceoffsWon"), higherIsBetter: true, format: .integer),

            PlayerDefinition(id: "savePct", title: "Save percentage", section: .goaltending, query: goalies,
                             key: key("defensive", "savePct"), higherIsBetter: true, format: .fraction,
                             minimum: shotsFaced),
            PlayerDefinition(id: "goalsAgainst", title: "Goals against average", section: .goaltending,
                             query: goalies, key: key("defensive", "avgGoalsAgainst"), higherIsBetter: false,
                             format: .decimal(2), minimum: shotsFaced),
            PlayerDefinition(id: "wins", title: "Wins", section: .goaltending, query: goalies,
                             key: key("general", "wins"), higherIsBetter: true, format: .integer,
                             minimum: .init(key: key("defensive", "shotsAgainst"), value: 1)),
            PlayerDefinition(id: "shutouts", title: "Shutouts", section: .goaltending, query: goalies,
                             key: key("defensive", "shutouts"), higherIsBetter: true, format: .integer,
                             minimum: .init(key: key("defensive", "shotsAgainst"), value: 1)),

            PlayerDefinition(id: "penaltyMinutes", title: "Penalty minutes", section: .discipline,
                             query: penalties, key: key("penalties", "penaltyMinutes"), higherIsBetter: true,
                             format: .integer),
        ]
    }()
}
