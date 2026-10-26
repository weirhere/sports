import Foundation

/// Which cards each league's Team stats tab draws, in order (2026-10-25).
///
/// FotMob's sections — Top stats, then attack, defence and discipline —
/// with each sport's own numbers in them. Football's defence is its
/// opponents' block read the other way up; the NHL ships no opponents'
/// block, so its defence is what its own payload already says about goals
/// and shots against. Keys verified live against all four leagues'
/// `byteam` payloads; one ESPN stops sending just hides its card.
extension League {
    var teamStatDefinitions: [TeamStatDefinition] {
        switch self {
        case .collegeFootball, .nfl: Self.footballDefinitions(isNFL: self == .nfl)
        case .nba: Self.basketballDefinitions
        case .nhl: Self.hockeyDefinitions
        }
    }

    private typealias Definition = TeamStatDefinition

    private static func team(_ category: String, _ name: String) -> TeamStatDefinition.Source {
        .stat(TeamStatKey(.team, category, name))
    }

    private static func opponents(_ category: String, _ name: String) -> TeamStatDefinition.Source {
        .stat(TeamStatKey(.opponents, category, name))
    }

    private static func perGame(_ category: String, _ name: String) -> TeamStatDefinition.Source {
        .perGame(TeamStatKey(.team, category, name))
    }

    /// The two football leagues share a shape and differ in three places.
    /// The NFL's total offence is `netYardsPerGame` (passing net of sacks,
    /// plus rushing), college football's is `yardsPerGame` — a college sack
    /// is a rushing loss, so its passing yards are already net, and its
    /// payload has no `net*` keys at all. College football also ships no
    /// turnover, takeaway or giveaway counts.
    private static func footballDefinitions(isNFL: Bool) -> [TeamStatDefinition] {
        let totalYards = isNFL ? "netYardsPerGame" : "yardsPerGame"
        let passingYards = isNFL ? "netPassingYardsPerGame" : "passingYardsPerGame"
        var definitions: [Definition] = [
            Definition(id: "points", title: "Points per game", section: .top,
                       source: team("passing", "totalPointsPerGame"), higherIsBetter: true, format: .decimal(1)),
            Definition(id: "pointsAllowed", title: "Points allowed per game", section: .top,
                       source: opponents("passing", "totalPointsPerGame"), higherIsBetter: false, format: .decimal(1)),
            Definition(id: "yards", title: "Total yards per game", section: .top,
                       source: team("passing", totalYards), higherIsBetter: true, format: .decimal(1)),
            Definition(id: "yardsAllowed", title: "Yards allowed per game", section: .top,
                       source: opponents("passing", totalYards), higherIsBetter: false, format: .decimal(1)),
        ]
        if isNFL {
            definitions.append(
                Definition(id: "turnoverDifferential", title: "Turnover differential", section: .top,
                           source: team("miscellaneous", "turnOverDifferential"), higherIsBetter: true,
                           format: .signed(0)))
        }
        definitions += [
            Definition(id: "passingYards", title: "Passing yards per game", section: .offense,
                       source: team("passing", passingYards), higherIsBetter: true, format: .decimal(1)),
            Definition(id: "rushingYards", title: "Rushing yards per game", section: .offense,
                       source: team("rushing", "rushingYardsPerGame"), higherIsBetter: true, format: .decimal(1)),
            Definition(id: "yardsPerRush", title: "Yards per rush", section: .offense,
                       source: team("rushing", "yardsPerRushAttempt"), higherIsBetter: true, format: .decimal(1)),
            Definition(id: "completionPct", title: "Completion percentage", section: .offense,
                       source: team("passing", "completionPct"), higherIsBetter: true, format: .percent),
            Definition(id: "passerRating", title: "Passer rating", section: .offense,
                       source: team("passing", "QBRating"), higherIsBetter: true, format: .decimal(1)),
            Definition(id: "thirdDown", title: "Third-down conversion", section: .offense,
                       source: team("miscellaneous", "thirdDownConvPct"), higherIsBetter: true, format: .percent),
            Definition(id: "fourthDown", title: "Fourth-down conversion", section: .offense,
                       source: team("miscellaneous", "fourthDownConvPct"), higherIsBetter: true, format: .percent),
            Definition(id: "sacksAllowed", title: "Sacks allowed", section: .offense,
                       source: team("passing", "sacks"), higherIsBetter: false, format: .integer),
        ]
        if isNFL {
            definitions.append(
                Definition(id: "giveaways", title: "Giveaways", section: .offense,
                           source: team("miscellaneous", "totalGiveaways"), higherIsBetter: false, format: .integer))
        }
        definitions += [
            Definition(id: "passingYardsAllowed", title: "Passing yards allowed per game", section: .defense,
                       source: opponents("passing", passingYards), higherIsBetter: false, format: .decimal(1)),
            Definition(id: "rushingYardsAllowed", title: "Rushing yards allowed per game", section: .defense,
                       source: opponents("rushing", "rushingYardsPerGame"), higherIsBetter: false, format: .decimal(1)),
            Definition(id: "sacks", title: "Sacks", section: .defense,
                       source: opponents("passing", "sacks"), higherIsBetter: true, format: .integer),
            // The interceptions the opponents threw are the ones this
            // defence made — the one way both leagues' payloads say it.
            Definition(id: "interceptions", title: "Interceptions", section: .defense,
                       source: opponents("passing", "interceptions"), higherIsBetter: true, format: .integer),
        ]
        if isNFL {
            definitions.append(
                Definition(id: "takeaways", title: "Takeaways", section: .defense,
                           source: team("miscellaneous", "totalTakeaways"), higherIsBetter: true, format: .integer))
        }
        definitions += [
            Definition(id: "opponentThirdDown", title: "Opponent third-down conversion", section: .defense,
                       source: opponents("miscellaneous", "thirdDownConvPct"), higherIsBetter: false, format: .percent),
            Definition(id: "fieldGoalPct", title: "Field goal percentage", section: .specialTeams,
                       source: team("kicking", "fieldGoalPct"), higherIsBetter: true, format: .percent),
            Definition(id: "netPunting", title: "Net punting average", section: .specialTeams,
                       source: team("punting", "netAvgPuntYards"), higherIsBetter: true, format: .decimal(1)),
            Definition(id: "kickReturn", title: "Kick return average", section: .specialTeams,
                       source: team("returning", "yardsPerKickReturn"), higherIsBetter: true, format: .decimal(1)),
            Definition(id: "puntReturn", title: "Punt return average", section: .specialTeams,
                       source: team("returning", "yardsPerPuntReturn"), higherIsBetter: true, format: .decimal(1)),
            Definition(id: "penalties", title: "Penalties per game", section: .discipline,
                       source: perGame("miscellaneous", "totalPenalties"), higherIsBetter: false, format: .decimal(1)),
            Definition(id: "penaltyYards", title: "Penalty yards per game", section: .discipline,
                       source: perGame("miscellaneous", "totalPenaltyYards"), higherIsBetter: false, format: .decimal(1)),
        ]
        return definitions
    }

    private static let basketballDefinitions: [TeamStatDefinition] = [
        Definition(id: "points", title: "Points per game", section: .top,
                   source: team("offensive", "avgPoints"), higherIsBetter: true, format: .decimal(1)),
        Definition(id: "pointsAllowed", title: "Points allowed per game", section: .top,
                   source: opponents("offensive", "avgPoints"), higherIsBetter: false, format: .decimal(1)),
        Definition(id: "pointDifferential", title: "Point differential per game", section: .top,
                   source: team("differential", "avgPointsDifferential"), higherIsBetter: true, format: .signed(1)),
        Definition(id: "fieldGoalPct", title: "Field goal percentage", section: .top,
                   source: team("offensive", "fieldGoalPct"), higherIsBetter: true, format: .percent),
        Definition(id: "threePointPct", title: "Three-point percentage", section: .top,
                   source: team("offensive", "threePointFieldGoalPct"), higherIsBetter: true, format: .percent),
        Definition(id: "assists", title: "Assists per game", section: .offense,
                   source: team("offensive", "avgAssists"), higherIsBetter: true, format: .decimal(1)),
        Definition(id: "threesMade", title: "Threes made per game", section: .offense,
                   source: team("offensive", "avgThreePointFieldGoalsMade"), higherIsBetter: true, format: .decimal(1)),
        Definition(id: "freeThrowPct", title: "Free throw percentage", section: .offense,
                   source: team("offensive", "freeThrowPct"), higherIsBetter: true, format: .percent),
        Definition(id: "offensiveRebounds", title: "Offensive rebounds per game", section: .offense,
                   source: team("offensive", "avgOffensiveRebounds"), higherIsBetter: true, format: .decimal(1)),
        Definition(id: "turnovers", title: "Turnovers per game", section: .offense,
                   source: team("offensive", "avgTurnovers"), higherIsBetter: false, format: .decimal(1)),
        // `assistTurnoverRatio`, not `teamAssistTurnoverRatio` — the
        // latter came back 0.0 for every team on 2026-10-25.
        Definition(id: "assistTurnover", title: "Assist-to-turnover ratio", section: .offense,
                   source: team("general", "assistTurnoverRatio"), higherIsBetter: true, format: .decimal(2)),
        Definition(id: "rebounds", title: "Rebounds per game", section: .defense,
                   source: team("general", "avgRebounds"), higherIsBetter: true, format: .decimal(1)),
        Definition(id: "defensiveRebounds", title: "Defensive rebounds per game", section: .defense,
                   source: team("defensive", "avgDefensiveRebounds"), higherIsBetter: true, format: .decimal(1)),
        Definition(id: "steals", title: "Steals per game", section: .defense,
                   source: team("defensive", "avgSteals"), higherIsBetter: true, format: .decimal(1)),
        Definition(id: "blocks", title: "Blocks per game", section: .defense,
                   source: team("defensive", "avgBlocks"), higherIsBetter: true, format: .decimal(1)),
        Definition(id: "opponentFieldGoalPct", title: "Opponent field goal percentage", section: .defense,
                   source: opponents("offensive", "fieldGoalPct"), higherIsBetter: false, format: .percent),
        Definition(id: "opponentThreePointPct", title: "Opponent three-point percentage", section: .defense,
                   source: opponents("offensive", "threePointFieldGoalPct"), higherIsBetter: false, format: .percent),
        Definition(id: "fouls", title: "Fouls per game", section: .discipline,
                   source: team("general", "avgFouls"), higherIsBetter: false, format: .decimal(1)),
        Definition(id: "technicalFouls", title: "Technical fouls", section: .discipline,
                   source: team("general", "technicalFouls"), higherIsBetter: false, format: .integer),
    ]

    private static let hockeyDefinitions: [TeamStatDefinition] = [
        Definition(id: "goals", title: "Goals per game", section: .top,
                   source: team("offensive", "avgGoals"), higherIsBetter: true, format: .decimal(2)),
        Definition(id: "goalsAgainst", title: "Goals against per game", section: .top,
                   source: team("defensive", "avgGoalsAgainst"), higherIsBetter: false, format: .decimal(2)),
        Definition(id: "powerPlayPct", title: "Power play percentage", section: .top,
                   source: team("offensive", "powerPlayPct"), higherIsBetter: true, format: .percent),
        Definition(id: "penaltyKillPct", title: "Penalty kill percentage", section: .top,
                   source: team("defensive", "penaltyKillPct"), higherIsBetter: true, format: .percent),
        Definition(id: "savePct", title: "Save percentage", section: .top,
                   source: team("defensive", "savePct"), higherIsBetter: true, format: .fraction),
        Definition(id: "shots", title: "Shots per game", section: .offense,
                   source: perGame("offensive", "shotsTotal"), higherIsBetter: true, format: .decimal(1)),
        Definition(id: "shootingPct", title: "Shooting percentage", section: .offense,
                   source: team("offensive", "shootingPct"), higherIsBetter: true, format: .percent),
        Definition(id: "powerPlayGoals", title: "Power-play goals", section: .offense,
                   source: team("offensive", "powerPlayGoals"), higherIsBetter: true, format: .integer),
        Definition(id: "shortHandedGoals", title: "Short-handed goals", section: .offense,
                   source: team("offensive", "shortHandedGoals"), higherIsBetter: true, format: .integer),
        Definition(id: "shotsAgainst", title: "Shots against per game", section: .defense,
                   source: perGame("defensive", "shotsAgainst"), higherIsBetter: false, format: .decimal(1)),
        Definition(id: "saves", title: "Saves per game", section: .defense,
                   source: perGame("defensive", "saves"), higherIsBetter: true, format: .decimal(1)),
        Definition(id: "shutouts", title: "Shutouts", section: .defense,
                   source: team("defensive", "shutouts"), higherIsBetter: true, format: .integer),
        Definition(id: "penaltyMinutes", title: "Penalty minutes per game", section: .discipline,
                   source: perGame("penalties", "penaltyMinutes"), higherIsBetter: false, format: .decimal(1)),
    ]
}
