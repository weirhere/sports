import Foundation
import Testing
@testable import StatSide

/// The Tables hub's whole-league row (Andy, 2026-09-05: "the whole NFL as
/// well, not just the different conferences"). It is assembled from the
/// conference tables the hub already fetched, not from a second request.
@Suite struct LeagueTableTests {
    private func standing(_ id: String, _ location: String,
                          conf: String, overall: String,
                          pct: Double?) -> ConferenceStanding {
        ConferenceStanding(
            team: Team(id: id, location: location, name: nil, abbreviation: nil,
                       displayName: location, shortDisplayName: nil, logoURL: nil,
                       conferenceId: nil, league: .nfl),
            conferenceRecord: conf, overallRecord: overall, streak: nil,
            winPercent: pct)
    }

    private func table(_ id: Int, _ name: String,
                       _ entries: [ConferenceStanding]) -> ConferenceStandings {
        ConferenceStandings(id: id, name: name, entries: entries, league: .nfl)
    }

    private var conferences: [ConferenceStandings] {
        [table(8, "AFC", [standing("2", "Buffalo", conf: "2-0", overall: "3-0", pct: 1.0),
                          standing("34", "Houston", conf: "0-2", overall: "0-3", pct: 0.0)]),
         table(7, "NFC", [standing("14", "Los Angeles", conf: "1-0", overall: "3-0", pct: 1.0),
                          standing("21", "Philadelphia", conf: "0-1", overall: "1-2", pct: 0.333)])]
    }

    @Test func theLeagueTableRanksEveryConferenceByWinPercentage() throws {
        let league = try #require(conferences.leagueTable(in: .nfl))

        #expect(league.id == 9)
        #expect(league.name == "NFL")
        #expect(league.entries.map(\.team.location)
                == ["Buffalo", "Los Angeles", "Philadelphia", "Houston"])
    }

    /// Ties keep the conference tables' own order rather than inventing a
    /// winner between two leagues' worth of teams.
    @Test func tiesKeepTheirSourceOrder() throws {
        let league = try #require(conferences.leagueTable(in: .nfl))
        let tied = league.entries.prefix(2).map(\.team.location)

        #expect(tied == ["Buffalo", "Los Angeles"])
    }

    /// A table calling itself the NFL with one conference missing would be
    /// a lie the row can't qualify, so it isn't built.
    @Test func aMissingConferenceYieldsNoLeagueTable() {
        let afcOnly = [conferences[0]]

        #expect(afcOnly.leagueTable(in: .nfl) == nil)
        #expect([ConferenceStandings]().leagueTable(in: .nfl) == nil)
    }

    /// College football answers "who's good" with its poll; group 80 is a
    /// division, not a table.
    @Test func collegeFootballHasNoLeagueTable() {
        #expect(Conference.leagueWideId(in: .collegeFootball) == nil)
        #expect(Conference.leagueWideId(in: .nfl) == 9)
    }

    /// The league leads its own accordion, above the conferences it holds.
    @Test func theLeagueSortsAboveItsConferences() {
        #expect(Conference.tier(for: 9, in: .nfl) == .league)
        #expect(Conference.tier(for: 9, in: .nfl) < Conference.tier(for: 8, in: .nfl))
        #expect(Conference.name(for: 9, in: .nfl) == "NFL")
        // 9 is the Pac-12 in the other league's id space.
        #expect(Conference.name(for: 9, in: .collegeFootball) == "Pac-12")
    }

    /// The league's shield is filed under `leagues/`, not beside the
    /// conference marks.
    @Test func theLeagueWearsItsOwnMark() {
        #expect(Conference.logoURL(for: .nfl(9))?.absoluteString
                == "https://a.espncdn.com/i/teamlogos/leagues/500/nfl.png")
        #expect(Conference.logoURL(for: .nfl(8))?.absoluteString
                == "https://a.espncdn.com/i/teamlogos/nfl/500/afc.png")
    }

    /// A game reaches Following through every group its teams sit inside.
    /// ESPN's NFL scoreboard hands us the *division*, so without the walk
    /// up a followed AFC — or NFL — matched nothing at all.
    @Test func theGroupChainWalksDivisionToConferenceToLeague() {
        #expect(Conference.chain(for: .nfl(3)) == [.nfl(3), .nfl(7), .nfl(9)])
        #expect(Conference.chain(for: .nfl(7)) == [.nfl(7), .nfl(9)])
        #expect(Conference.chain(for: .nfl(9)) == [.nfl(9)])
        // College football nests no divisions *under* a conference, but
        // since 2026-09-09 a conference sits inside one — FBS or FCS —
        // which is what lets a follow there claim its games.
        #expect(Conference.chain(for: .cfb(8)) == [.cfb(8), Conference.divisionRoot(.fbs)])
    }
}
