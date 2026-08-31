import Foundation
import Testing
@testable import StatSide

// The game page's Standings card gate: hidden only in the true preseason
// (every table 0-0 — the place numbers are last season's carried-over
// order), shown for any matchup the tables know once the season is
// underway — including a pre-game page where neither side has played yet.

private func team(_ id: String, _ location: String) -> Team {
    Team(id: id, location: location, name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 8)
}

private let georgia = team("61", "Georgia")
private let tennessee = team("2633", "Tennessee")
private let ohioState = team("194", "Ohio State")

private func standing(_ team: Team, overall: String?) -> ConferenceStanding {
    ConferenceStanding(team: team, conferenceRecord: "0-0",
                       overallRecord: overall, streak: nil)
}

@MainActor
@Suite struct MatchupStandingsGateTests {
    @Test func preseasonHidesTheCard() {
        let standings = [ConferenceStandings(id: 8, name: "SEC", entries: [
            standing(georgia, overall: "0-0"),
            standing(tennessee, overall: "0-0"),
        ])]
        #expect(!MatchupStandings.hasContent(away: georgia, home: tennessee,
                                             standings: standings))
    }

    @Test func unplayedMatchupShowsOnceTheSeasonIsUnderway() {
        // Neither participant has played, but another team's record proves
        // the tables are live — the pre-game page shows both sides.
        let standings = [
            ConferenceStandings(id: 8, name: "SEC", entries: [
                standing(georgia, overall: "0-0"),
                standing(tennessee, overall: "0-0"),
            ]),
            ConferenceStandings(id: 5, name: "Big Ten", entries: [
                standing(ohioState, overall: "1-0"),
            ]),
        ]
        #expect(MatchupStandings.hasContent(away: georgia, home: tennessee,
                                            standings: standings))
    }

    @Test func unknownTeamsStayHiddenEvenInSeason() {
        // An FCS-only matchup no table knows renders nothing — the
        // underway season alone doesn't earn the card.
        let standings = [ConferenceStandings(id: 5, name: "Big Ten", entries: [
            standing(ohioState, overall: "1-0"),
        ])]
        #expect(!MatchupStandings.hasContent(away: georgia, home: tennessee,
                                             standings: standings))
    }

    @Test func missingRecordsReadAsPreseason() {
        let standings = [ConferenceStandings(id: 8, name: "SEC", entries: [
            standing(georgia, overall: nil),
            standing(tennessee, overall: nil),
        ])]
        #expect(!MatchupStandings.hasContent(away: georgia, home: tennessee,
                                             standings: standings))
    }
}
