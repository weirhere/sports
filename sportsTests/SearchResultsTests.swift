import Foundation
import Testing
@testable import StatSide

private func team(_ id: String, location: String, name: String? = nil,
                  abbreviation: String? = nil, displayName: String? = nil,
                  shortDisplayName: String? = nil, conference: Int? = 8) -> Team {
    Team(id: id, location: location, name: name, abbreviation: abbreviation,
         displayName: displayName, shortDisplayName: shortDisplayName,
         logoURL: nil, conferenceId: conference)
}

private func game(_ id: String, home: Team, away: Team,
                  name: String? = nil, shortName: String? = nil,
                  date: Date? = Date(timeIntervalSince1970: 0)) -> Game {
    Game(id: id, date: date, name: name, shortName: shortName, weekNumber: 1,
         status: .pre(detail: nil),
         home: Competitor(team: home, score: nil, record: nil, rank: nil, isHome: true, winner: nil),
         away: Competitor(team: away, score: nil, record: nil, rank: nil, isHome: false, winner: nil),
         broadcast: nil)
}

private let georgia = team("61", location: "Georgia", name: "Bulldogs",
                           abbreviation: "UGA", displayName: "Georgia Bulldogs")
private let georgiaTech = team("59", location: "Georgia Tech", name: "Yellow Jackets",
                               abbreviation: "GT", displayName: "Georgia Tech Yellow Jackets",
                               conference: 1)
private let sanJoseState = team("23", location: "San José State", name: "Spartans",
                                abbreviation: "SJSU", displayName: "San José State Spartans",
                                conference: 17)
private let tennessee = team("2633", location: "Tennessee", name: "Volunteers",
                             abbreviation: "TENN", displayName: "Tennessee Volunteers")

private let sec = ConferenceTeams(id: 8, name: "SEC", teams: [georgia, tennessee])
private let acc = ConferenceTeams(id: 1, name: "ACC", teams: [georgiaTech])
private let mountainWest = ConferenceTeams(id: 17, name: "Mountain West", teams: [sanJoseState])
private let other = ConferenceTeams(id: nil, name: "Other", teams: [])
private let allConferences = [sec, acc, mountainWest, other]

// FCS teams that collide with FBS names on purpose: "Georgia State" is a
// real ambiguity a Georgia fan will hit, and Montana State is Big Sky.
private let georgiaSouthern = team("290", location: "Georgia Southern",
                                   name: "Eagles", abbreviation: "GASO",
                                   displayName: "Georgia Southern Eagles", conference: 20)
private let bigSky = ConferenceTeams(id: 20, name: "Big Sky", teams: [georgiaSouthern])

@Suite struct SearchResultsTests {

    @Test func emptyAndWhitespaceQueriesReturnNothing() {
        for query in ["", "   ", "\n"] {
            let results = SearchResults.compute(query: query, conferences: allConferences,
                                                games: [], followingIds: [])
            #expect(results.isEmpty)
        }
    }

    @Test func matchesAcrossAllTeamFields() {
        for query in ["Georgia", "bulldogs", "uga", "Georgia Bull", "georgia b"] {
            let results = SearchResults.compute(query: query, conferences: allConferences,
                                                games: [], followingIds: [])
            #expect(results.teams.contains(georgia), "query \(query) missed Georgia")
        }
    }

    @Test func diacriticFoldingMatchesBothDirections() {
        let plain = SearchResults.compute(query: "jose", conferences: allConferences,
                                          games: [], followingIds: [])
        #expect(plain.teams == [sanJoseState])
        let accented = SearchResults.compute(query: "José", conferences: allConferences,
                                             games: [], followingIds: [])
        #expect(accented.teams == [sanJoseState])
    }

    @Test func followedTeamOutranksBetterAlphabeticalMatch() {
        let unfollowed = SearchResults.compute(query: "georgia", conferences: allConferences,
                                               games: [], followingIds: [])
        #expect(unfollowed.teams == [georgia, georgiaTech])
        let followed = SearchResults.compute(query: "georgia", conferences: allConferences,
                                             games: [], followingIds: [georgiaTech.followKey])
        #expect(followed.teams == [georgiaTech, georgia])
    }

    /// E8: the directory doubled to ~250 teams when FCS joined it, but the
    /// common query didn't change. An FCS team that matches exactly as well
    /// as an FBS one sits below it — alphabetical order would otherwise put
    /// "Georgia Southern" above "Georgia Tech" for a Georgia fan.
    @Test func anFCSTeamRanksBelowAnEquallyGoodFBSMatch() {
        let results = SearchResults.teams(matching: "georgia",
                                          in: [bigSky] + allConferences,
                                          followingIds: [])
        let ids = results.map(\.id)
        #expect(ids.firstIndex(of: "61")! < ids.firstIndex(of: "290")!)
        #expect(ids.firstIndex(of: "59")! < ids.firstIndex(of: "290")!)
    }

    /// ...but a followed FCS team still leads, like any followed team.
    @Test func aFollowedFCSTeamStillOutranksTheFBSField() {
        let results = SearchResults.teams(matching: "georgia",
                                          in: [bigSky] + allConferences,
                                          followingIds: ["cfb:290"])
        #expect(results.first?.id == "290")
    }

    @Test func exactAbbreviationBeatsPrefixBeatsSubstring() {
        // "gt": exact abbreviation on Georgia Tech; substring-only elsewhere.
        let substringHit = team("99", location: "Egtville", conference: 8)
        let conferences = [ConferenceTeams(id: 8, name: "SEC", teams: [substringHit]), acc]
        let results = SearchResults.compute(query: "gt", conferences: conferences,
                                            games: [], followingIds: [])
        #expect(results.teams == [georgiaTech, substringHit])

        // Word-prefix ("ten" starts Tennessee) beats mid-word substring.
        let midword = team("98", location: "Intensity State", conference: 8)
        let prefixConferences = [ConferenceTeams(id: 8, name: "SEC", teams: [midword, tennessee])]
        let prefixResults = SearchResults.compute(query: "ten", conferences: prefixConferences,
                                                  games: [], followingIds: [])
        #expect(prefixResults.teams == [tennessee, midword])
    }

    @Test func equalTiersBreakAlphabetically() {
        let results = SearchResults.compute(query: "georgia", conferences: allConferences,
                                            games: [], followingIds: [])
        #expect(results.teams == [georgia, georgiaTech])
    }

    @Test func conferenceMatchesPrefixFirstAndSkipsNilId() {
        // "e" is a substring of both SEC and Mountain West, a prefix of
        // neither — alphabetical order. The nil-id "Other" backstop never
        // appears even though "Other" contains "e".
        let results = SearchResults.compute(query: "e", conferences: allConferences,
                                            games: [], followingIds: [])
        #expect(results.conferences.map(\.name) == ["Mountain West", "SEC"])

        // "s" is a prefix of SEC but only a substring of Mountain West.
        let s = SearchResults.compute(query: "s", conferences: allConferences,
                                      games: [], followingIds: [])
        #expect(s.conferences.first?.name == "SEC")
    }

    @Test func gamesMatchViaEitherTeamOrName() {
        let g1 = game("1", home: georgia, away: tennessee)
        let g2 = game("2", home: georgiaTech, away: sanJoseState)
        let g3 = game("3", home: tennessee, away: sanJoseState,
                      name: "Spartans at Volunteers", shortName: "SJSU @ TENN")

        let byHome = SearchResults.compute(query: "bulldogs", conferences: [],
                                           games: [g1, g2, g3], followingIds: [])
        #expect(byHome.games == [g1])

        let byAway = SearchResults.compute(query: "tennessee", conferences: [],
                                           games: [g1, g2, g3], followingIds: [])
        #expect(Set(byAway.games.map(\.id)) == ["1", "3"])

        let byName = SearchResults.compute(query: "volunteers", conferences: [],
                                           games: [g3], followingIds: [])
        #expect(byName.games == [g3])
    }

    @Test func gamesSortChronologicallyWithUndatedLast() {
        let late = game("b", home: georgia, away: tennessee,
                        date: Date(timeIntervalSince1970: 200))
        let early = game("c", home: georgia, away: tennessee,
                         date: Date(timeIntervalSince1970: 100))
        let undated = game("a", home: georgia, away: tennessee, date: nil)
        let results = SearchResults.compute(query: "georgia", conferences: [],
                                            games: [late, undated, early], followingIds: [])
        #expect(results.games.map(\.id) == ["c", "b", "a"])
    }

    @Test func sectionsStayInTheirLanes() {
        let g = game("1", home: georgia, away: tennessee)
        let results = SearchResults.compute(query: "mountain", conferences: allConferences,
                                            games: [g], followingIds: [])
        #expect(results.teams.isEmpty)
        #expect(results.conferences.map(\.name) == ["Mountain West"])
        #expect(results.games.isEmpty)
    }

    @Test func duplicateTeamAcrossConferencesAppearsOnce() {
        let duplicated = [sec, ConferenceTeams(id: 99, name: "Duplicate", teams: [georgia])]
        let results = SearchResults.compute(query: "georgia", conferences: duplicated,
                                            games: [], followingIds: [])
        #expect(results.teams == [georgia])
    }

    @Test func teamOnlySliceMatchesAndRanksWithoutFollowBoost() {
        let slice = SearchResults.teams(matching: "georgia", in: allConferences)
        #expect(slice == [georgia, georgiaTech])
        let boosted = SearchResults.teams(matching: "georgia", in: allConferences,
                                          followingIds: [georgiaTech.followKey])
        #expect(boosted == [georgiaTech, georgia])
    }
}
