import Foundation
import Testing
@testable import StatSide

private final class RosterFixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: RosterFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

private func team(_ id: String, _ abbreviation: String, league: League) -> Team {
    Team(id: id, location: abbreviation, name: nil, abbreviation: abbreviation,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil, league: league)
}

private func person(_ id: String, _ name: String, _ position: String?, jersey: String? = nil,
                    league: League = .nfl) -> GameRoster.Person {
    GameRoster.Person(id: id, name: name, shortName: GameRoster.Side.shortName(name),
                      jersey: jersey, position: position, positionName: nil, headshotURL: nil,
                      unit: Formation.unit(for: position, league: league))
}

private func rosterPlayer(_ id: String, _ name: String, _ position: String, jersey: String? = nil,
                          injury: String? = nil) -> RosterPlayer {
    RosterPlayer(id: id, name: name, jersey: jersey, position: position, positionName: nil,
                 height: nil, weight: nil, age: nil, classAbbreviation: nil,
                 headshotURL: nil, injuryStatus: injury)
}

private func entry(_ id: String, _ short: String, jersey: String? = nil,
                   position: ESPNPositions.Position? = nil, starter: Bool = false,
                   dnp: Bool = false, scratched: Bool = false, note: String? = nil,
                   stat: Bool = false) -> LineupEntry {
    LineupEntry(athleteId: id, shortName: short, jersey: jersey, position: position,
                isStarter: starter, didNotPlay: dnp, isScratched: scratched, note: note,
                recordedStat: stat)
}

// MARK: - Decoding, against payloads captured live 2026-10-18

@Suite struct GameLineupDecodingTests {
    @Test func nflGameDayRosterFlagsStartersAndInactives() throws {
        let dto = try JSONDecoder().decode(CompetitorRosterDTO.self, from: fixture("nfl-game-roster-final"))
        let lineup = ESPNMapper.lineup(from: dto, league: .nfl)
        #expect(lineup.count == 57)
        #expect(lineup.filter(\.isStarter).count == 22)
        #expect(lineup.filter(\.didNotPlay).count == 8)
        #expect(lineup.filter(\.recordedStat).count == 47)
        // Positions resolve through the table, never a request.
        let nix = try #require(lineup.first { $0.shortName == "Nix" })
        #expect(nix.position?.abbreviation == "QB")
        #expect(nix.isStarter)
        #expect(nix.jersey == "10")
        // ESPN's short form already tells two Joneses apart.
        #expect(lineup.contains { $0.shortName == "D.J. Jones" })
        #expect(lineup.contains { $0.shortName == "B. Jones" })
        // An NFL inactive carries no reason, and gets no invented one.
        let inactive = try #require(lineup.first { $0.didNotPlay })
        #expect(inactive.note == nil)
    }

    @Test func nflPregameRosterAlreadyNamesTheLineup() throws {
        let dto = try JSONDecoder().decode(CompetitorRosterDTO.self, from: fixture("nfl-game-roster-pregame"))
        let lineup = ESPNMapper.lineup(from: dto, league: .nfl)
        #expect(lineup.count == 56)
        #expect(lineup.filter(\.isStarter).count == 22)
        #expect(lineup.filter(\.didNotPlay).count == 7)
        #expect(lineup.allSatisfy { !$0.recordedStat })
    }

    @Test func collegeRosterIsWholeSquadWithNoInactives() throws {
        let dto = try JSONDecoder().decode(CompetitorRosterDTO.self, from: fixture("cfb-game-roster-final"))
        let lineup = ESPNMapper.lineup(from: dto, league: .collegeFootball)
        #expect(lineup.count == 128)
        #expect(lineup.filter(\.isStarter).count == 22)
        #expect(lineup.filter(\.didNotPlay).isEmpty)
        // The stat line is college football's only record of who played.
        #expect(lineup.filter(\.recordedStat).count == 32)
    }

    @Test func nbaRosterCarriesStartersAndCoachsDecisions() throws {
        let dto = try JSONDecoder().decode(CompetitorRosterDTO.self, from: fixture("nba-game-roster-final"))
        let lineup = ESPNMapper.lineup(from: dto, league: .nba)
        #expect(lineup.count == 13)
        #expect(lineup.filter(\.isStarter).count == 5)
        let dnp = lineup.filter(\.didNotPlay)
        #expect(dnp.count == 3)
        #expect(dnp.allSatisfy { $0.note == "Coach's decision" })
        let williams = try #require(lineup.first { $0.shortName == "Williams" })
        #expect(williams.position?.abbreviation == "F")
    }

    @Test func nhlRosterFlagsScratchesAndNamesNoStarters() throws {
        let dto = try JSONDecoder().decode(CompetitorRosterDTO.self, from: fixture("nhl-game-roster-final"))
        let lineup = ESPNMapper.lineup(from: dto, league: .nhl)
        #expect(lineup.count == 23)
        #expect(lineup.filter(\.isStarter).isEmpty)
        let scratched = lineup.filter(\.isScratched)
        #expect(scratched.count == 3)
        #expect(scratched.allSatisfy { $0.note == "Scratched" })
        #expect(lineup.contains { $0.shortName == "Killorn" && $0.position?.abbreviation == "LW" })
    }

    @Test func nbaDepthChartFlattensToRankedSlotsInPositionOrder() throws {
        let dto = try JSONDecoder().decode(DepthChartsDTO.self, from: fixture("nba-depth-chart"))
        let slots = ESPNMapper.depthChart(from: dto)
        let firsts = slots.filter { $0.rank == 1 }
        #expect(firsts.map(\.position) == ["PG", "SG", "SF", "PF", "C"])
        #expect(firsts.map(\.athleteId) == ["4432166", "3157465", "4684742", "3908845", "4433621"])
        #expect(firsts.first?.positionName == "Point Guard")
    }

    @Test func nhlDepthChartNamesTheFirstLineAndStartingGoalie() throws {
        let dto = try JSONDecoder().decode(DepthChartsDTO.self, from: fixture("nhl-depth-chart"))
        let slots = ESPNMapper.depthChart(from: dto)
        let firsts = slots.filter { $0.rank == 1 }
        #expect(Set(firsts.map(\.position)) == ["LW", "C", "RW", "LD", "RD", "G"])
        #expect(firsts.first { $0.position == "G" }?.athleteId == "4874737")
    }

    @Test func summaryInjuriesDecodePerTeam() throws {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("nfl-summary-pregame-injuries"))
        let summary = ESPNMapper.gameSummary(from: dto, league: .nfl)
        #expect(summary.injuries.count == 2)
        let falcons = try #require(summary.injuries.first { $0.teamId == "1" })
        #expect(falcons.injuries.count == 5)
        let smith = try #require(falcons.injuries.first)
        #expect(smith.name == "Za'Darius Smith")
        #expect(smith.status == "Questionable")
        #expect(smith.detail == "Neck")
        #expect(smith.position == "DE")
        #expect(smith.returnDate == "2026-10-18")
        #expect(smith.returnDateText()?.contains("18") == true)
        #expect(smith.id == "3043168")
        // "Undisclosed" is ESPN saying nothing; the row says nothing too.
        let bears = try #require(summary.injuries.first { $0.teamId == "3" })
        #expect(bears.injuries.first?.detail == nil)
        #expect(bears.injuries.first?.status == "Injured Reserve")
    }

    @Test func nbaBoxScoreCarriesLineupFlags() throws {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("nba-summary"))
        let summary = ESPNMapper.gameSummary(from: dto, league: .nba)
        let players = summary.boxScore.flatMap { $0.categories.flatMap(\.players) }
        #expect(players.filter { $0.isStarter == true }.count == 10)
        let benched = players.filter(\.didNotPlay)
        #expect(benched.count == 7)
        #expect(benched.allSatisfy { $0.didNotPlayReason == "Coach's decision" })
        #expect(players.first?.position == "F")
    }

    @Test func nhlSummaryCarriesWhoIsOnTheIce() throws {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("nhl-summary"))
        let summary = ESPNMapper.gameSummary(from: dto, league: .nhl)
        #expect(summary.onIce.count == 2)
        #expect(summary.onIce["25"]?.isEmpty == false)
        // Football's box score has no flags and says so with nil, not false.
        let football = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("summary-final-live"))
        let footballPlayers = ESPNMapper.gameSummary(from: football).boxScore.flatMap { $0.categories.flatMap(\.players) }
        #expect(footballPlayers.allSatisfy { $0.isStarter == nil && !$0.didNotPlay })
        #expect(ESPNMapper.gameSummary(from: football).injuries.isEmpty)
    }

    @Test func positionTableResolvesRefsPerSport() {
        #expect(ESPNPositions.position(id: "8", league: .nfl)?.abbreviation == "QB")
        #expect(ESPNPositions.position(id: "8", league: .collegeFootball)?.abbreviation == "QB")
        #expect(ESPNPositions.position(id: "8", league: .nba)?.abbreviation == "FC")
        #expect(ESPNPositions.position(id: "13", league: .nhl)?.abbreviation == "LD")
        #expect(ESPNPositions.position(id: "9999", league: .nfl) == nil)
        let ref = CoreRefDTO.id(in: "http://sports.core.api.espn.com/v2/sports/football/leagues/nfl/positions/30?lang=en",
                                after: "/positions/")
        #expect(ref == "30")
        #expect(CoreRefDTO.id(in: "https://example.com/teams/7", after: "/positions/") == nil)
    }
}

// MARK: - Assembly

@Suite struct GameRosterAssemblyTests {
    private let qb = ESPNPositions.Position(abbreviation: "QB", name: "Quarterback")
    private let lb = ESPNPositions.Position(abbreviation: "LB", name: "Linebacker")

    @Test func footballLineupJoinsTheTeamRosterForNamesAndPositions() {
        let roster = TeamRoster(coach: RosterCoach(id: "9", name: "Sean Payton"), groups: [
            RosterGroup(name: "Offense", players: [
                rosterPlayer("10", "Bo Nix", "QB", jersey: "10"),
                rosterPlayer("77", "Quinn Meinerz", "G", jersey: "77"),
                rosterPlayer("4", "Jarrett Stidham", "QB", jersey: "4"),
            ]),
            RosterGroup(name: "Defense", players: [
                rosterPlayer("15", "Nik Bonitto", "OLB", jersey: "15"),
                rosterPlayer("52", "Alex Singleton", "ILB", jersey: "52"),
            ]),
            RosterGroup(name: "Practice squad", players: [rosterPlayer("99", "Nobody Here", "WR")]),
        ])
        let lineup = [
            entry("10", "Nix", jersey: "10", position: qb, starter: true, stat: true),
            entry("15", "Bonitto", jersey: "15", position: lb, starter: true, stat: true),
            entry("52", "Singleton", jersey: "52", position: lb, stat: true),
            entry("77", "Meinerz", jersey: "77"),                    // dressed, no stat line
            entry("4", "Stidham", jersey: "4", dnp: true),
            entry("5000", "Elevated", jersey: "61", position: lb),   // not on the team roster
        ]
        let side = GameRoster.Side.make(
            GameRoster.SideInput(team: team("7", "DEN", league: .nfl), roster: roster, lineup: lineup),
            phase: .played, league: .nfl)

        #expect(side.coach?.name == "Sean Payton")
        #expect(side.lineupKind == .declared)
        #expect(side.starters.map(\.name) == ["Bo Nix", "Nik Bonitto"])
        // The team roster's "OLB" beats the game-day roster's generic "LB".
        #expect(side.starters.last?.position == "OLB")
        #expect(side.starters.last?.unit == .defense)
        #expect(side.starters.first?.unit == .offense)
        // The NFL declares inactives, so everyone else dressed played — a
        // lineman with no stat line included.
        #expect(side.others.map(\.name) == ["Alex Singleton", "Elevated", "Quinn Meinerz"])
        #expect(side.others.first { $0.name == "Elevated" }?.position == "LB")
        #expect(side.inactive.map(\.name) == ["Jarrett Stidham"])
    }

    @Test func collegeWithoutInactivesCountsOnlyStatLinesAsPlayed() {
        let lineup = [
            entry("1", "Starter", position: qb, starter: true),
            entry("2", "Played", stat: true),
            entry("3", "Stood", position: lb),
        ]
        let played = GameRoster.Side.make(
            GameRoster.SideInput(team: team("61", "UGA", league: .collegeFootball), lineup: lineup),
            phase: .played, league: .collegeFootball)
        #expect(played.others.map(\.shortName) == ["Played"])
        // Before kickoff the whole dressed list is "planning to play".
        let upcoming = GameRoster.Side.make(
            GameRoster.SideInput(team: team("61", "UGA", league: .collegeFootball), lineup: lineup),
            phase: .upcoming, league: .collegeFootball)
        #expect(upcoming.others.map(\.shortName) == ["Played", "Stood"])
        #expect(upcoming.lineupKind == .projected)
        // A player no source names in full still gets his short name.
        #expect(upcoming.starters.first?.name == "Starter")
    }

    @Test func pregameBasketballProjectsFromTheDepthChart() {
        let roster = TeamRoster(coach: nil, groups: [RosterGroup(name: "Roster", players: [
            rosterPlayer("a", "Cade Cunningham", "G", jersey: "2"),
            rosterPlayer("b", "Jalen Duren", "C", jersey: "0"),
            rosterPlayer("c", "Bench Guy", "F", jersey: "30"),
            rosterPlayer("d", "Hurt Guy", "F", jersey: "31"),
        ])])
        let depth = [
            DepthSlot(position: "PG", positionName: "Point Guard", rank: 1, athleteId: "a"),
            DepthSlot(position: "PG", positionName: "Point Guard", rank: 2, athleteId: "c"),
            DepthSlot(position: "C", positionName: "Center", rank: 1, athleteId: "b"),
            DepthSlot(position: "SG", positionName: "Shooting Guard", rank: 1, athleteId: "a"),
        ]
        let injury = GameInjury(id: "d", name: "Hurt Guy", jersey: "31", position: "F", headshotURL: nil,
                                status: "Out", detail: "Illness", returnDate: nil)
        let side = GameRoster.Side.make(
            GameRoster.SideInput(team: team("8", "DET", league: .nba), roster: roster,
                                 depthChart: depth, injuries: [injury]),
            phase: .upcoming, league: .nba)
        #expect(side.lineupKind == .projected)
        // The chart's slot names the position, and a player ranked first
        // at two spots stands in one.
        #expect(side.starters.map(\.position) == ["PG", "C"])
        #expect(side.others.map(\.name) == ["Bench Guy"])
        #expect(side.injuries.count == 1)
    }

    @Test func liveHockeyPutsTheSkatersOnTheIceOnTop() {
        let roster = TeamRoster(coach: nil, groups: [RosterGroup(name: "Centers", players: [
            rosterPlayer("1", "First Liner", "C", jersey: "9"),
            rosterPlayer("2", "Fourth Liner", "C", jersey: "28"),
            rosterPlayer("3", "Scratch", "C", jersey: "17"),
        ])])
        let lineup = [entry("1", "Liner"), entry("2", "Liner"), entry("3", "Scratch", scratched: true, note: "Scratched")]
        let side = GameRoster.Side.make(
            GameRoster.SideInput(team: team("30", "MIN", league: .nhl), roster: roster,
                                 lineup: lineup, onIce: ["2"]),
            phase: .live, league: .nhl)
        #expect(side.lineupKind == .onIce)
        #expect(side.starters.map(\.name) == ["Fourth Liner"])
        #expect(side.others.map(\.name) == ["First Liner"])
        #expect(side.inactive.map(\.name) == ["Scratch"])
        #expect(side.inactive.first?.note == "Scratched")
    }

    @Test func finalBasketballFallsBackToTheBoxScoreFlags() {
        let players = [
            BoxScore.Player(id: "a", athleteId: "a", name: "Starter", jersey: "1", headshotURL: nil,
                            stats: ["30"], isStarter: true, position: "G"),
            BoxScore.Player(id: "b", athleteId: "b", name: "Bench", jersey: "2", headshotURL: nil,
                            stats: ["10"], isStarter: false),
            BoxScore.Player(id: "c", athleteId: "c", name: "Sat", jersey: "3", headshotURL: nil,
                            stats: ["0"], isStarter: false, didNotPlay: true, didNotPlayReason: "Coach's decision"),
        ]
        let box = BoxScore(teamId: "17", categories: [
            BoxScore.Category(id: "players", label: "Players", columns: ["MIN"],
                              columnDescriptions: [], players: players, totals: []),
        ])
        let side = GameRoster.Side.make(
            GameRoster.SideInput(team: team("17", "BKN", league: .nba), boxScore: box),
            phase: .played, league: .nba)
        #expect(side.lineupKind == .declared)
        #expect(side.starters.map(\.name) == ["Starter"])
        #expect(side.others.map(\.name) == ["Bench"])
        #expect(side.inactive.first?.note == "Coach's decision")
        #expect(side.starters.first?.shortName == "Starter")
    }

    @Test func emptySourcesMakeAnEmptySide() {
        let side = GameRoster.Side.make(GameRoster.SideInput(team: team("1", "X", league: .nfl)),
                                        phase: .upcoming, league: .nfl)
        #expect(side.isEmpty)
        #expect(side.lineupKind == .none)
        #expect(GameRoster.Side.shortName("Travis Kelce Jr.") == "Kelce")
        #expect(GameRoster.Side.shortName("Cher") == "Cher")
    }
}

// MARK: - Formation

@Suite struct FormationTests {
    @Test func footballOffenseLinesUpAcrossTheBall() {
        let starters = [
            person("1", "Flanker One", "WR"), person("2", "Wideout Two", "WR"), person("3", "Slot Three", "WR"),
            person("4", "Tight End", "TE"),
            person("5", "Left Tackle", "LT"), person("6", "Left Guard", "LG"), person("7", "Center", "C"),
            person("8", "Right Guard", "RG"), person("9", "Right Tackle", "RT"),
            person("10", "Quarterback", "QB"), person("11", "Running Back", "RB"),
            person("12", "Edge Rusher", "DE"),   // the other platoon
        ]
        let offense = Formation.make(starters: starters, league: .nfl, unit: .offense)
        #expect(offense.rows.count == 4)
        // The line at the ball; the receivers and the tight end a row off
        // it, split to the edges with the field open between them.
        #expect(offense.rows[0] == .line(starters.filter { ["LT", "LG", "C", "RG", "RT"].contains($0.position) }))
        #expect(offense.rows[1] == .wings(left: [starters[2], starters[0]], right: [starters[3], starters[1]]))
        #expect(offense.rows[1].players.map(\.position) == ["WR", "WR", "TE", "WR"])
        #expect(offense.rows[2].players.map(\.position) == ["QB"])
        #expect(offense.rows[3].players.map(\.position) == ["RB"])
        #expect(offense.unplaced.isEmpty)
    }

    @Test func footballDefenseStacksFrontBackersAndSafeties() {
        let starters = [
            person("1", "A", "DE"), person("2", "B", "DT"), person("3", "C", "DT"), person("4", "D", "DE"),
            person("5", "E", "OLB"), person("6", "F", "MLB"), person("7", "G", "OLB"),
            person("8", "H", "CB"), person("9", "I", "CB"),
            person("10", "J", "FS"), person("11", "K", "SS"),
            person("12", "L", "ATH"),   // no unit the table knows
        ]
        let defense = Formation.make(starters: starters, league: .nfl, unit: .defense)
        #expect(defense.rows.count == 4)
        #expect(defense.rows[0].players.map(\.position) == ["DE", "DT", "DT", "DE"])
        #expect(defense.rows[1].players.map(\.position) == ["OLB", "MLB", "OLB"])
        // Corners are wings: one at each edge, nobody between them.
        #expect(defense.rows[2] == .wings(left: [starters[7]], right: [starters[8]]))
        #expect(defense.rows[3].players.map(\.position) == ["FS", "SS"])
        #expect(defense.unplaced.map(\.name) == ["L"])
    }

    @Test func genericLinemenAlternateOutFromTheCenter() {
        let line = [person("1", "A", "OT"), person("2", "B", "G"), person("3", "C", "C"),
                    person("4", "D", "G"), person("5", "E", "OT"), person("6", "Q", "QB")]
        let offense = Formation.make(starters: line, league: .collegeFootball, unit: .offense)
        #expect(offense.rows[0].players.map(\.name) == ["A", "B", "C", "D", "E"])
    }

    @Test func basketballAndHockeyArrangeOneUnit() {
        let five = [person("1", "A", "SG", league: .nba), person("2", "B", "C", league: .nba),
                    person("3", "C", "PG", league: .nba), person("4", "D", "PF", league: .nba),
                    person("5", "E", "SF", league: .nba)]
        let court = Formation.make(starters: five, league: .nba)
        #expect(court.rows.map { $0.players.map(\.position) } == [["PG", "SG"], ["SF", "C", "PF"]])

        let six = [person("1", "A", "G", league: .nhl), person("2", "B", "RD", league: .nhl),
                   person("3", "C", "LW", league: .nhl), person("4", "D", "C", league: .nhl),
                   person("5", "E", "RW", league: .nhl), person("6", "F", "LD", league: .nhl)]
        let rink = Formation.make(starters: six, league: .nhl)
        #expect(rink.rows.map { $0.players.map(\.position) } == [["LW", "C", "RW"], ["LD", "RD"], ["G"]])
        // Generic guards and forwards still land in their rows.
        let coarse = [person("1", "A", "G", league: .nba), person("2", "B", "F", league: .nba),
                      person("3", "C", "F", league: .nba), person("4", "D", "C", league: .nba),
                      person("5", "E", "G", league: .nba)]
        let rows = Formation.make(starters: coarse, league: .nba).rows
        #expect(rows[0].players.count == 2)
        #expect(rows[1].players.map(\.position) == ["F", "C", "F"])
    }

    @Test func unitClassificationIsFootballOnly() {
        #expect(Formation.unit(for: "OT", league: .nfl) == .offense)
        #expect(Formation.unit(for: "NB", league: .collegeFootball) == .defense)
        #expect(Formation.unit(for: "PK", league: .nfl) == .specialTeams)
        #expect(Formation.unit(for: "ATH", league: .nfl) == nil)
        #expect(Formation.unit(for: "C", league: .nba) == nil)
        #expect(Formation.unit(for: nil, league: .nfl) == nil)
    }
}
