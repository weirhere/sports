import Foundation
import Testing
@testable import StatSide

// The game page's Standings tab: which tables a matchup shows at each
// scope. Away's table first, a shared table once, the conference's own
// table over one of its divisions, and the league table only when every
// conference came back.

private func team(_ id: String, _ location: String, league: League = .nfl) -> Team {
    Team(id: id, location: location, name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil,
         league: league)
}

private func row(_ id: String, _ location: String, winPercent: Double = 0.5,
                 league: League = .nfl) -> ConferenceStanding {
    ConferenceStanding(team: team(id, location, league: league), conferenceRecord: nil,
                       overallRecord: nil, streak: nil, winPercent: winPercent)
}

private func table(_ id: Int, _ name: String, _ entries: [ConferenceStanding],
                   league: League = .nfl, parentId: Int? = nil) -> ConferenceStandings {
    ConferenceStandings(id: id, name: name, entries: entries, league: league,
                        parentId: parentId)
}

private let tampa = row("27", "Tampa Bay", winPercent: 0.17)
private let carolina = row("29", "Carolina", winPercent: 0.6)
private let kansasCity = row("12", "Kansas City", winPercent: 0.8)
private let buffalo = row("2", "Buffalo", winPercent: 0.7)

private let nfc = table(7, "National Football Conference", [carolina, tampa])
private let afc = table(8, "American Football Conference", [kansasCity, buffalo])
private let nfcSouth = table(11, "NFC South", [carolina, tampa], parentId: 7)
private let afcWest = table(6, "AFC West", [kansasCity], parentId: 8)
private let afcEast = table(4, "AFC East", [buffalo], parentId: 8)

@MainActor @Suite struct GameStandingsTablesTests {
    @Test func divisionalGameShowsOneTableAtConferenceScope() {
        let shown = GameStandingsModel.tables(at: .conference, conferences: [afc, nfc],
                                              divisions: [], league: .nfl,
                                              awayId: "27", homeId: "29")
        #expect(shown.map(\.id) == [7])
    }

    @Test func crossConferenceGameShowsAwaysTableFirst() {
        let shown = GameStandingsModel.tables(at: .conference, conferences: [nfc, afc],
                                              divisions: [], league: .nfl,
                                              awayId: "12", homeId: "27")
        #expect(shown.map(\.id) == [8, 7])
    }

    @Test func divisionScopeReadsTheDivisionalTables() {
        let divisions = [afcEast, afcWest, nfcSouth]
        let shared = GameStandingsModel.tables(at: .division, conferences: [],
                                               divisions: divisions, league: .nfl,
                                               awayId: "27", homeId: "29")
        #expect(shared.map(\.id) == [11])
        let split = GameStandingsModel.tables(at: .division, conferences: [],
                                              divisions: divisions, league: .nfl,
                                              awayId: "2", homeId: "12")
        #expect(split.map(\.id) == [4, 6])
    }

    @Test func leagueScopeIsOneTableRankedByWinPercentage() {
        let shown = GameStandingsModel.tables(at: .league, conferences: [afc, nfc],
                                              divisions: [], league: .nfl,
                                              awayId: "27", homeId: "29")
        #expect(shown.count == 1)
        #expect(shown.first?.entries.map(\.team.id) == ["12", "2", "29", "27"])
    }

    @Test func leagueScopeNeedsEveryConference() {
        let shown = GameStandingsModel.tables(at: .league, conferences: [nfc],
                                              divisions: [], league: .nfl,
                                              awayId: "27", homeId: "29")
        #expect(shown.isEmpty)
    }

    @Test func conferenceScopePrefersTheConferenceOverItsDivision() {
        // A response carrying both must not let Conference scope show the
        // four-team division because it happened to come first.
        let shown = GameStandingsModel.tables(at: .conference, conferences: [nfcSouth, nfc],
                                              divisions: [], league: .nfl,
                                              awayId: "27", homeId: "29")
        #expect(shown.map(\.id) == [7])
    }

    @Test func collegeFootballFallsBackToADivisionWhenThatsAllThereIs() {
        // A divisional-era conference (the 2019 AAC) lists its teams only
        // in its East and West, and those are the tables to show.
        let east = table(1511, "American - East",
                         [row("2116", "UCF", league: .collegeFootball)],
                         league: .collegeFootball, parentId: 151)
        let west = table(1512, "American - West",
                         [row("2655", "Tulane", league: .collegeFootball)],
                         league: .collegeFootball, parentId: 151)
        let shown = GameStandingsModel.tables(at: nil, conferences: [east, west],
                                              divisions: [], league: .collegeFootball,
                                              awayId: "2655", homeId: "2116")
        #expect(shown.map(\.name) == ["American - West", "American - East"])
    }

    @Test func aTeamNoTableKnowsIsSkippedNotInvented() {
        // An FCS visitor the FBS tables don't list: the home side's table
        // still shows, and nothing stands in for the missing one.
        let sec = table(8, "SEC", [row("61", "Georgia", league: .collegeFootball)],
                        league: .collegeFootball)
        let shown = GameStandingsModel.tables(at: nil, conferences: [sec], divisions: [],
                                              league: .collegeFootball,
                                              awayId: "2241", homeId: "61")
        #expect(shown.map(\.name) == ["SEC"])
    }

    @Test func anotherLeaguesTablesAreIgnored() {
        // Group id 8 is the AFC and the SEC; a table from the wrong league
        // must not answer for this one.
        let sec = table(8, "SEC", [row("27", "Tampa Bay", league: .collegeFootball)],
                        league: .collegeFootball)
        let shown = GameStandingsModel.tables(at: .conference, conferences: [sec, nfc],
                                              divisions: [], league: .nfl,
                                              awayId: "27", homeId: "29")
        #expect(shown.map(\.id) == [7])
        #expect(shown.first?.league == .nfl)
    }

    @Test func scopesFollowTheLeaguesHierarchy() {
        #expect(GameStandingsModel.scopes(in: .collegeFootball).isEmpty)
        for league in [League.nfl, .nba, .nhl] {
            #expect(GameStandingsModel.scopes(in: league) == [.league, .conference, .division])
        }
    }
}
