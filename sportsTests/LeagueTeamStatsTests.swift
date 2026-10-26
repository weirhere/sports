import Foundation
import Testing
@testable import StatSide

private final class LeagueTeamStatsFixtureToken {}

/// The first six teams of each league's `byteam` answer, captured live on
/// 2026-10-25 and trimmed of links: the NFL in Week 7, FBS in Week 8, the
/// NBA a week in, the NHL four weeks in.
private func stats(_ name: String, _ league: League) throws -> LeagueTeamStats {
    let url = try #require(
        Bundle(for: LeagueTeamStatsFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    let dto = try JSONDecoder().decode(ByTeamResponseDTO.self, from: Data(contentsOf: url))
    return LeagueTeamStatsMapper.stats(from: dto, league: league)
}

private func definition(_ id: String, _ league: League) throws -> TeamStatDefinition {
    try #require(league.teamStatDefinitions.first { $0.id == id }, "no \(id) in \(league)")
}

private func team(_ id: String, _ location: String) -> Team {
    Team(id: id, location: location, name: nil, abbreviation: nil, displayName: nil,
         shortDisplayName: nil, logoURL: nil, conferenceId: nil)
}

@Suite struct LeagueTeamStatsTests {

    // MARK: - Mapping

    @Test func everyTeamComesBackKeyedByWhoseNumberItIs() throws {
        let nfl = try stats("nfl-byteam", .nfl)
        #expect(nfl.lines.count == 6)
        let arizona = try #require(nfl.lines.first)
        #expect(arizona.team.location == "Arizona")
        #expect(arizona.values[TeamStatKey(.team, "passing", "totalPointsPerGame")] == 21.0)
        #expect(arizona.values[TeamStatKey(.opponents, "passing", "totalPointsPerGame")] == 29.667)
        #expect(arizona.gamesPlayed == 6)
    }

    @Test func aRepeatedNameKeepsItsFirstValue() throws {
        // `rushing` names `rushingYards` twice; both slots carry the total,
        // but the per-game figure sits between them and must not win.
        let arizona = try #require(try stats("nfl-byteam", .nfl).lines.first)
        #expect(arizona.values[TeamStatKey(.team, "rushing", "rushingYards")] == 578)
    }

    @Test func theNBAsSplitlessDifferentialBlockIsTheTeamsOwn() throws {
        let lakers = try #require(try stats("nba-byteam", .nba).lines.first)
        #expect(lakers.team.location == "Los Angeles")
        #expect(lakers.values[TeamStatKey(.team, "differential", "avgPointsDifferential")] == 15.0)
    }

    @Test func aTwoWordNicknameLeavesTheCity() throws {
        let portland = try #require(try stats("nba-byteam", .nba).lines.dropFirst().first)
        #expect(portland.team.location == "Portland")
    }

    @Test func aProTeamKnowsItsDivisionFromTheRegistry() throws {
        let buffalo = try #require(try stats("nfl-byteam", .nfl).lines.first { $0.team.location == "Buffalo" })
        #expect(buffalo.team.conferenceId == Conference.division(forTeamId: buffalo.team.id, in: .nfl))
        #expect(buffalo.team.conferenceId != nil)
    }

    @Test func theNHLsNullValuesDecode() throws {
        // Boston took no shootout — ESPN sends `null`, not 0.
        let boston = try #require(try stats("nhl-byteam", .nhl).lines.first)
        #expect(boston.values[TeamStatKey(.team, "offensive", "shootoutAttempts")] == nil)
        #expect(boston.values[TeamStatKey(.team, "defensive", "savePct")] == 0.925)
    }

    // MARK: - Ranking

    @Test func lowerIsBetterRanksAscending() throws {
        let nfl = try stats("nfl-byteam", .nfl)
        let ranking = nfl.ranking(for: try definition("pointsAllowed", .nfl))
        #expect(ranking.rows.map(\.team.location)
                == ["Chicago", "Baltimore", "Carolina", "Atlanta", "Buffalo", "Arizona"])
        #expect(ranking.rows.first?.display == "20.4")
    }

    @Test func theNFLsTotalYardsAreNetOfSacks() throws {
        // 211.0 net passing + 96.3 rushing — not the gross 318.8.
        let nfl = try stats("nfl-byteam", .nfl)
        let arizona = try #require(nfl.ranking(for: try definition("yards", .nfl)).rows
            .first { $0.team.location == "Arizona" })
        #expect(arizona.display == "307.3")
    }

    @Test func collegeFootballsTotalYardsArePlainYardsPerGame() throws {
        let cfb = try stats("cfb-byteam", .collegeFootball)
        let ranking = cfb.ranking(for: try definition("yards", .collegeFootball))
        #expect(ranking.rows.first?.team.location == "Arizona")
        #expect(ranking.rows.first?.display == "459.4")
    }

    @Test func aTotalBecomesPerGame() throws {
        let nhl = try stats("nhl-byteam", .nhl)
        let shots = nhl.ranking(for: try definition("shots", .nhl))
        // Detroit: 328 shots in 11 games.
        #expect(shots.rows.first?.team.location == "Detroit")
        #expect(shots.rows.first?.display == "29.8")
        #expect(shots.rows.last?.team.location == "Chicago")
    }

    @Test func tiedTeamsShareARankAndTheNextSkips() throws {
        let nhl = try stats("nhl-byteam", .nhl)
        let save = nhl.ranking(for: try definition("savePct", .nhl))
        #expect(save.rows.map(\.rank) == [1, 2, 3, 4, 4, 6])
        #expect(save.rows[3].team.location == "Calgary")
        #expect(save.rows[4].team.location == "Edmonton")
        #expect(save.rows.first?.display == ".925")
    }

    @Test func aNarrowedScopeRanksAmongItself() throws {
        let nfl = try stats("nfl-byteam", .nfl)
        let ids = Set(nfl.lines.filter { ["Buffalo", "Arizona"].contains($0.team.location) }.map(\.team.id))
        let ranking = nfl.ranking(for: try definition("pointsAllowed", .nfl), among: ids)
        #expect(ranking.rows.map(\.team.location) == ["Buffalo", "Arizona"])
        #expect(ranking.rows.map(\.rank) == [1, 2])
    }

    @Test func aKeyALeagueDoesntSendHidesItsCard() throws {
        // College football ships no takeaways — the NFL's card isn't its.
        let cfb = try stats("cfb-byteam", .collegeFootball)
        #expect(!cfb.rankings().contains { $0.definition.id == "takeaways" })
        #expect(cfb.rankings().contains { $0.definition.id == "interceptions" })
    }

    @Test func everyRegistryKeyIsInItsLeaguesPayload() throws {
        for (name, league) in [("nfl-byteam", League.nfl), ("cfb-byteam", .collegeFootball),
                               ("nba-byteam", .nba), ("nhl-byteam", .nhl)] {
            let ranked = Set(try stats(name, league).rankings().map(\.definition.id))
            let missing = league.teamStatDefinitions.map(\.id).filter { !ranked.contains($0) }
            #expect(missing.isEmpty, "\(league): \(missing)")
        }
    }

    @Test func noGamesIsNotARanking() {
        let line = TeamStatLine(team: team("1", "Boston"),
                                values: [TeamStatKey(.team, "general", "games"): 0])
        #expect(!LeagueTeamStats(league: .nhl, lines: [line]).hasPlayed)
    }

    @Test func formatsReadTheWayEachSportWritesThem() {
        #expect(TeamStatDefinition.Format.percent.string(66.8) == "66.8%")
        #expect(TeamStatDefinition.Format.signed(0).string(2) == "+2")
        #expect(TeamStatDefinition.Format.signed(1).string(-3.3) == "-3.3")
        #expect(TeamStatDefinition.Format.signed(0).string(0) == "0")
        #expect(TeamStatDefinition.Format.fraction.string(0.875) == ".875")
        #expect(TeamStatDefinition.Format.integer.string(12) == "12")
    }

    // MARK: - Scope

    @Test func aProConferencePageTakesItsTeamsFromTheRegistry() throws {
        let nfl = try stats("nfl-byteam", .nfl)
        let teams = nfl.lines.map(\.team)
        let afc = try #require(LeagueTeamStats.teamIds(on: ConferenceID(.nfl, 8), standings: [],
                                                       candidates: teams))
        #expect(Set(teams.filter { afc.contains($0.id) }.map(\.location)) == ["Baltimore", "Buffalo"])
        let afcEast = try #require(LeagueTeamStats.teamIds(on: ConferenceID(.nfl, 4), standings: [],
                                                           candidates: teams))
        #expect(teams.filter { afcEast.contains($0.id) }.map(\.location) == ["Buffalo"])
    }

    @Test func aLeaguePageRanksEveryone() throws {
        let wide = try #require(Conference.leagueWideId(in: .nfl))
        #expect(LeagueTeamStats.teamIds(on: ConferenceID(.nfl, wide), standings: [], candidates: []) == nil)
        #expect(LeagueTeamStats.teamIds(on: Conference.divisionRoot(.fbs), standings: [], candidates: []) == nil)
    }

    @Test func aCollegeConferenceTakesItsTeamsFromItsStandings() {
        let sec = ConferenceStandings(id: 8, name: "SEC", entries: [
            ConferenceStanding(team: team("2", "Auburn"), conferenceRecord: nil, overallRecord: nil, streak: nil),
        ])
        let acc = ConferenceStandings(id: 1, name: "ACC", entries: [
            ConferenceStanding(team: team("2390", "Miami"), conferenceRecord: nil, overallRecord: nil, streak: nil),
        ])
        #expect(LeagueTeamStats.teamIds(on: ConferenceID(.collegeFootball, 8), standings: [sec, acc],
                                        candidates: []) == ["2"])
    }

    // MARK: - StatSide rating

    private func standing(_ id: String, _ location: String, _ wins: Int, _ losses: Int,
                          _ pf: Int, _ pa: Int) -> ConferenceStanding {
        ConferenceStanding(team: team(id, location), conferenceRecord: nil, overallRecord: nil, streak: nil,
                           wins: wins, losses: losses, pointsFor: pf, pointsAgainst: pa)
    }

    @Test func theRatingMatchesThePerformancePoll() {
        // The Notion Performance Poll's top five on 2026-10-25, shuffled
        // across two conferences.
        let big12 = ConferenceStandings(id: 4, name: "Big 12", entries: [
            standing("254", "Utah", 7, 0, 262, 102),
        ])
        let mixed = ConferenceStandings(id: 5, name: "Big Ten", entries: [
            standing("84", "Indiana", 7, 1, 269, 96),
            standing("26", "UCLA", 7, 0, 241, 107),
            standing("256", "James Madison", 7, 1, 331, 146),
            standing("2390", "Miami", 7, 0, 343, 107),
        ])
        let rows = StatSideRating.ranking(from: [big12, mixed])
        #expect(rows.map(\.team.location) == ["Miami", "Utah", "UCLA", "James Madison", "Indiana"])
        #expect(rows.first?.record == "7-0")
        #expect(rows.first?.differentialDisplay == "+236")
        #expect(rows.allSatisfy { $0.isInTopTier })
    }

    /// The payload as ESPN ships it, through the app's own standings
    /// mapper: the ACC, Big 12, Big Ten and Sun Belt of 2026-10-26, split
    /// stats trimmed. ESPN sends `wins` and the "7-0" record and **no**
    /// `losses` stat for any FBS team — the hand-built tables above had one,
    /// which is how the first build's rating came out empty on device.
    @Test func theRatingReadsLossesFromTheRecordAsESPNShipsIt() throws {
        let url = try #require(Bundle(for: LeagueTeamStatsFixtureToken.self)
            .url(forResource: "cfb-standings-fbs-week9", withExtension: "json"))
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: Data(contentsOf: url))
        let standings = ESPNMapper.conferenceStandings(
            from: dto, league: .collegeFootball,
            now: try #require(ISO8601DateFormatter().date(from: "2026-10-26T12:00:00Z")))
        let entries = standings.flatMap(\.entries)
        #expect(!entries.isEmpty)
        #expect(entries.allSatisfy { $0.losses == nil })

        let rows = StatSideRating.ranking(from: standings)
        #expect(rows.prefix(5).map(\.team.location) == ["Miami", "Utah", "UCLA", "James Madison", "Indiana"])
        #expect(rows.first?.record == "7-0")
        #expect(rows.first?.differentialDisplay == "+236")
        #expect(rows[3].record == "7-1")
    }

    @Test func aRecordSplitsIntoWinsAndLosses() {
        #expect(StatSideRating.winsAndLosses("7-1")?.wins == 7)
        #expect(StatSideRating.winsAndLosses("7-1")?.losses == 1)
        #expect(StatSideRating.winsAndLosses("6-1-1")?.losses == 1)
        #expect(StatSideRating.winsAndLosses("7") == nil)
        #expect(StatSideRating.winsAndLosses("—") == nil)
    }

    @Test func fewerLossesBeatMoreWins() {
        let table = ConferenceStandings(id: 8, name: "SEC", entries: [
            standing("1", "Seven and one", 7, 1, 300, 100),
            standing("2", "Six and oh", 6, 0, 150, 140),
        ])
        #expect(StatSideRating.ranking(from: [table]).map(\.team.location) == ["Six and oh", "Seven and one"])
    }

    @Test func aTeamInTwoTablesCountsOnce() {
        let east = ConferenceStandings(id: 37, name: "Sun Belt", entries: [standing("1", "App State", 5, 2, 200, 150)])
        let west = ConferenceStandings(id: 37, name: "Sun Belt", entries: [standing("1", "App State", 5, 2, 200, 150)])
        #expect(StatSideRating.ranking(from: [east, west]).count == 1)
    }

    @Test func aSeasonNobodyHasPlayedHasNoRating() {
        let table = ConferenceStandings(id: 8, name: "SEC", entries: [standing("1", "Georgia", 0, 0, 0, 0)])
        #expect(StatSideRating.ranking(from: [table]).isEmpty)
    }
}
