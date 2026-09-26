import Foundation
import os
import Testing
@testable import StatSide

/// A league whose slate can change between fetches — what a poll looks
/// like from the store's side.
private final class ChangingStub: ScoresProviding, Sendable {
    nonisolated let league: League
    private let pool: OSAllocatedUnfairLock<[Game]>

    init(league: League, games: [Game]) {
        self.league = league
        self.pool = OSAllocatedUnfairLock(initialState: games)
    }

    func replace(with games: [Game]) { pool.withLock { $0 = games } }

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        throw ESPNError.invalidURL
    }

    func scoreboard(days: ClosedRange<Date>,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 1, weeks: [],
                   games: pool.withLock { $0 })
    }

    func rankings(year: Int?) async throws -> [Poll] { [] }
    func conferences(in division: Conference.Division) async throws -> [ConferenceTeams] { [] }
    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings] { [] }
    func conferenceGames(conferenceId: Int, year: Int?) async throws -> [Game] { [] }
    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        TeamSchedule(team: nil, record: nil, standing: nil, year: year, games: [])
    }
    func gameSummary(eventId: String) async throws -> GameSummary { throw ESPNError.invalidURL }
}

private func nflTeam(_ id: String) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil,
         conferenceId: 4, league: .nfl)
}

private func nflGame(_ id: String, live: Bool = false) -> Game {
    let noon = Calendar.current.date(byAdding: .hour, value: 12,
                                     to: Calendar.current.startOfDay(for: .now)) ?? .now
    return Game(id: id, date: noon, name: nil, shortName: nil, weekNumber: 1,
                status: live ? .live(displayClock: "5:00", period: 2, detail: nil,
                                     phase: .playing, possessionTeamId: nil)
                             : .pre(detail: nil),
                home: Competitor(team: nflTeam("h\(id)"), score: live ? 7 : nil, record: nil,
                                 rank: nil, isHome: true, winner: nil),
                away: Competitor(team: nflTeam("a\(id)"), score: live ? 3 : nil, record: nil,
                                 rank: nil, isHome: false, winner: nil),
                broadcast: nil)
}

@MainActor
private func makeScoreboards(nfl: ChangingStub) async -> LeagueScoreboards {
    let stores: [League: ScoreboardStore] = Dictionary(
        uniqueKeysWithValues: League.allCases.map { league in
            let client: any ScoresProviding = league == .nfl
                ? nfl : ChangingStub(league: league, games: [])
            return (league, ScoreboardStore(league: league, client: client))
        })
    let scoreboards = LeagueScoreboards(stores: stores)
    await scoreboards.loadInitial()
    return scoreboards
}

/// The sections memo (2026-09-24) is only safe if every input the build
/// reads moves its key. Each case here changes exactly one of them and
/// expects a different answer back.
@MainActor
@Suite struct SectionsMemoTests {

    @Test func anUnchangedAskAnswersTheSameSections() async {
        let stub = ChangingStub(league: .nfl, games: [nflGame("1")])
        let scoreboards = await makeScoreboards(nfl: stub)
        let first = scoreboards.sections(followingIds: [])
        let second = scoreboards.sections(followingIds: [])
        #expect(first == second)
        // The league's own section; its conferences carry the game too.
        #expect(first.first?.games.map(\.id) == ["1"])
    }

    @Test func aRefetchWithNewGamesIsNotServedFromTheMemo() async {
        let stub = ChangingStub(league: .nfl, games: [nflGame("1")])
        let scoreboards = await makeScoreboards(nfl: stub)
        _ = scoreboards.sections(followingIds: [])

        stub.replace(with: [nflGame("1"), nflGame("2")])
        await scoreboards.refresh()

        let ids = scoreboards.sections(followingIds: []).flatMap(\.games).map(\.id)
        #expect(Set(ids) == ["1", "2"])
    }

    @Test func aGameGoingLiveReachesTheLiveFilter() async {
        let stub = ChangingStub(league: .nfl, games: [nflGame("1")])
        let scoreboards = await makeScoreboards(nfl: stub)
        #expect(scoreboards.sections(followingIds: [], liveOnly: true).isEmpty)

        stub.replace(with: [nflGame("1", live: true)])
        await scoreboards.refresh()

        #expect(scoreboards.sections(followingIds: [], liveOnly: true)
            .first?.games.map(\.id) == ["1"])
    }

    @Test func aFollowChangesTheAnswer() async {
        let stub = ChangingStub(league: .nfl, games: [nflGame("1")])
        let scoreboards = await makeScoreboards(nfl: stub)
        let before = scoreboards.sections(followingIds: [])
        #expect(!before.contains { $0.id == GameSection.followingId })

        let after = scoreboards.sections(followingIds: [nflTeam("h1").followKey])
        #expect(after.first?.id == GameSection.followingId)
    }

    @Test func theLiveFilterChangesTheAnswer() async {
        let stub = ChangingStub(league: .nfl, games: [nflGame("1")])
        let scoreboards = await makeScoreboards(nfl: stub)
        #expect(!scoreboards.sections(followingIds: []).isEmpty)
        #expect(scoreboards.sections(followingIds: [], liveOnly: true).isEmpty)
    }
}
