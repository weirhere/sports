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

    /// The payload as ESPN ships it, through the app's own standings
    /// mapper: the ACC, Big 12, Big Ten and Sun Belt of 2026-10-26, split
    /// stats trimmed. ESPN sends `wins` and the "7-0" record and **no**
    /// `losses` stat for any FBS team, which is how the record sort's first
    /// build came out empty on device. The record sort retired on
    /// 2026-10-28, and the mapper fact it found stays pinned here.
    @Test func espnShipsNoLossesStatForFBS() throws {
        let url = try #require(Bundle(for: LeagueTeamStatsFixtureToken.self)
            .url(forResource: "cfb-standings-fbs-week9", withExtension: "json"))
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: Data(contentsOf: url))
        let standings = ESPNMapper.conferenceStandings(
            from: dto, league: .collegeFootball,
            now: try #require(ISO8601DateFormatter().date(from: "2026-10-26T12:00:00Z")))
        let entries = standings.flatMap(\.entries)
        #expect(!entries.isEmpty)
        #expect(entries.allSatisfy { $0.losses == nil })
        #expect(entries.first { $0.team.location == "Miami" }?.overallRecord == "7-0")
    }

    private func ratingFile(_ json: String) throws -> StatSideRatingFile {
        try JSONDecoder().decode(StatSideRatingFile.self, from: Data(json.utf8))
    }

    @Test func aPublishedSeasonDecodesBestFirst() throws {
        let file = try ratingFile("""
        {"updated":"2026-10-28","seasons":{"2026":{"label":"Week 9","throughWeek":9,"teams":[
          {"id":"194","location":"Ohio State","abbreviation":"OSU","conferenceId":5,"rank":2,"score":97.2,
           "wins":6,"losses":1,"resumeRank":6,"performanceRank":4},
          {"id":"2390","location":"Miami","logo":"https://a.espncdn.com/i/teamlogos/ncaa/500/2390.png",
           "rank":1,"score":98.2,"wins":7,"losses":0,"resumeRank":1,"performanceRank":5}]}}}
        """)
        let season = try #require(file.season(2026))
        #expect(season.label == "Week 9")
        #expect(season.rows.map(\.team.location) == ["Miami", "Ohio State"])
        #expect(season.rows[0].record == "7-0")
        #expect(season.rows[0].scoreDisplay == "98.2")
        #expect(season.rows[0].team.logoURL?.absoluteString.hasSuffix("2390.png") == true)
        #expect(season.rows[1].team.conferenceId == 5)
        #expect(season.rows[1].team.league == .collegeFootball)
        #expect(season.rows[1].resumeRank == 6)
        #expect(season.rows[1].performanceRank == 4)
    }

    @Test func anEntryMissingItsPlaceOrRecordIsDroppedNotGuessed() throws {
        let file = try ratingFile("""
        {"seasons":{"2026":{"label":"Week 9","teams":[
          {"id":"1","location":"No rank","wins":5,"losses":2},
          {"id":"2","location":"No record","rank":2},
          {"location":"No id","rank":3,"wins":5,"losses":2},
          {"id":"4","location":"Whole","rank":4,"wins":5,"losses":2}]}}}
        """)
        #expect(file.season(2026)?.rows.map(\.team.location) == ["Whole"])
    }

    @Test func aSeasonTheFileDoesntCarryHasNoRating() throws {
        let file = try ratingFile(#"{"seasons":{"2026":{"label":"Week 3","teams":[]}}}"#)
        #expect(file.season(2026) == nil)
        #expect(file.season(2019) == nil)
        #expect(StatSideRatingDestination(season: file.season(2019), league: .collegeFootball, year: 2019) == nil)
    }

    @Test func theTableSaysHowFarTheListRuns() throws {
        let file = try ratingFile("""
        {"seasons":{"2025":{"label":"Final","teams":[{"id":"84","location":"Indiana","rank":1,"wins":16,"losses":0}]}}}
        """)
        let destination = try #require(StatSideRatingDestination(season: file.season(2025),
                                                                 league: .collegeFootball, year: 2025))
        #expect(destination.seasonLabel == "\(League.collegeFootball.seasonLabel(2025)) · Final")
    }

    /// The copy bundled with the build decodes, and each season in it is a
    /// whole list: every place from 1 down, no gaps.
    @Test func theBundledListIsWhole() throws {
        let store = StatSideRatingStore(bundle: .main)
        let file = try #require(store.file)
        #expect(file.updated != nil)
        for year in (file.seasons ?? [:]).keys.compactMap(Int.init) {
            let season = try #require(store.season(year))
            #expect(season.rows.count > 100)
            #expect(season.rows.map(\.rank) == Array(1...season.rows.count))
        }
    }
}
