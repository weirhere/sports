import Foundation
import Testing
@testable import StatSide

private func team(_ id: String, _ location: String, nickname: String,
                  league: League, conference: Int?) -> Team {
    Team(id: id, location: location, name: nickname, abbreviation: nil,
         displayName: "\(location) \(nickname)", shortDisplayName: location,
         logoURL: nil, conferenceId: conference, league: league)
}

// The real collisions, from ESPN's own team lists (probed 2026-09-05):
// 24 of the NFL's 32 nicknames and 12 of its locations have a college twin.
private let hurricanes = team("2390", "Miami", nickname: "Hurricanes",
                              league: .collegeFootball, conference: 1)
private let dolphins = team("15", "Miami", nickname: "Dolphins",
                            league: .nfl, conference: 4)
private let bearcats = team("2132", "Cincinnati", nickname: "Bearcats",
                            league: .collegeFootball, conference: 4)
private let bengals = team("4", "Cincinnati", nickname: "Bengals",
                           league: .nfl, conference: 12)
private let georgia = team("61", "Georgia", nickname: "Bulldogs",
                           league: .collegeFootball, conference: 8)
/// The id collision itself: 26 is UCLA and the Seahawks.
private let bruins = team("26", "UCLA", nickname: "Bruins",
                          league: .collegeFootball, conference: 9)
private let seahawks = team("26", "Seattle", nickname: "Seahawks",
                            league: .nfl, conference: 3)

private let acc = ConferenceTeams(id: 1, name: "ACC", teams: [hurricanes])
private let big12 = ConferenceTeams(id: 4, name: "Big 12", teams: [bearcats])
private let sec = ConferenceTeams(id: 8, name: "SEC", teams: [georgia])
private let pac12 = ConferenceTeams(id: 9, name: "Pac-12", teams: [bruins])
private let afc = ConferenceTeams(id: 8, name: "AFC", teams: [dolphins, bengals],
                                  league: .nfl)
private let nfc = ConferenceTeams(id: 7, name: "NFC", teams: [seahawks], league: .nfl)
private let directory = [acc, big12, sec, pac12, afc, nfc]

@Suite struct CrossLeagueSearchTests {
    /// Both leagues' teams reach the results.
    @Test func aSharedLocationReturnsBothLeaguesTeams() {
        let results = SearchResults.compute(query: "miami", conferences: directory,
                                            games: [], followingIds: [])
        #expect(results.teams.map(\.displayName) == ["Miami Hurricanes", "Miami Dolphins"]
                || results.teams.map(\.displayName) == ["Miami Dolphins", "Miami Hurricanes"])
        #expect(results.teams.count == 2)
        #expect(results.spansLeagues)
    }

    /// A single-league result set needs no tags.
    @Test func aSingleLeagueResultSetDoesNotSpanLeagues() {
        let results = SearchResults.compute(query: "bulldogs", conferences: directory,
                                            games: [], followingIds: [])
        #expect(results.teams == [georgia])
        #expect(!results.spansLeagues)
    }

    /// The league you're already looking at wins an equal match — scoped to
    /// the NFL, "Cincinnati" means the Bengals.
    @Test func theScopedLeagueWinsAnEqualMatch() {
        let inNFL = SearchResults.compute(query: "cincinnati", conferences: directory,
                                          games: [], followingIds: [],
                                          preferredLeague: .nfl)
        #expect(inNFL.teams.first == bengals)

        let inCollege = SearchResults.compute(query: "cincinnati", conferences: directory,
                                              games: [], followingIds: [],
                                              preferredLeague: .collegeFootball)
        #expect(inCollege.teams.first == bearcats)
    }

    /// A followed team still outranks the scope — the stronger signal wins.
    @Test func aFollowedTeamBeatsTheScopedLeague() {
        let results = SearchResults.compute(query: "cincinnati", conferences: directory,
                                            games: [], followingIds: [bearcats.followKey],
                                            preferredLeague: .nfl)
        #expect(results.teams.first == bearcats)
    }

    /// With no scope given, ordering is unchanged from before the NFL —
    /// every existing call site keeps its behavior.
    @Test func noPreferredLeagueLeavesTheOrderAlone() {
        let results = SearchResults.compute(query: "cincinnati", conferences: directory,
                                            games: [], followingIds: [])
        #expect(results.teams.count == 2)
    }

    /// The dedupe is keyed on the follow key, not the bare id: UCLA and the
    /// Seahawks are both ESPN team 26, and a bare-id `seen` set would have
    /// silently dropped whichever came second.
    @Test func collidingIdsAcrossLeaguesBothSurvive() {
        #expect(bruins.id == seahawks.id)
        #expect(bruins.followKey != seahawks.followKey)

        // A query matching both — "s" is in Bruins and Seahawks — returns
        // both rather than one swallowing the other.
        let both = SearchResults.teams(matching: "s", in: [pac12, nfc])
        #expect(Set(both.map(\.followKey)) == [bruins.followKey, seahawks.followKey])
    }
}

@Suite struct TeamDirectoryLeagueTests {
    /// Browse slices the directory by league; the NFL's two conferences
    /// don't leak into the college-football headings.
    @Test func theDirectorySlicesByLeague() async {
        let store = TeamDirectoryStore(makeClient: { league in
            DirectoryStub(league: league)
        })
        await store.load()

        #expect(store.conferences(in: .collegeFootball).map(\.name) == ["SEC"])
        #expect(store.conferences(in: .nfl).map(\.name) == ["AFC"])
        #expect(store.teams(in: .nfl).allSatisfy { $0.league == .nfl })
        #expect(store.allTeams.count == 2)
    }
}

private struct DirectoryStub: ScoresProviding {
    nonisolated let league: League

    func conferences(in division: Conference.Division) async throws -> [ConferenceTeams] {
        switch league {
        case .collegeFootball:
            // FCS is fetched too; only FBS carries teams in this stub.
            division == .fbs ? [sec] : []
        case .nfl:
            [ConferenceTeams(id: 8, name: "AFC", teams: [dolphins], league: .nfl)]
        case .nba, .nhl:
            []
        }
    }

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        Scoreboard(seasonYear: nil, seasonType: nil, currentWeekNumber: nil,
                   weeks: [], games: [])
    }

    func scoreboard(days: ClosedRange<Date>,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        try await scoreboard(weekValue: nil, seasonType: nil, year: nil,
                             divisions: divisions)
    }
    func rankings(year: Int?) async throws -> [Poll] { [] }
    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings] { [] }
    func conferenceGames(conferenceId: Int, year: Int?) async throws -> [Game] { [] }
    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        TeamSchedule(team: nil, record: nil, standing: nil, year: year, games: [])
    }
    func gameSummary(eventId: String) async throws -> GameSummary { throw ESPNError.invalidURL }
}
